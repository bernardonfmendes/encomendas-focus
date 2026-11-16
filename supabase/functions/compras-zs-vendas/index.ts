// Importa as vendas do ZSbms (zsbmsv2.zonesoft.org) para a app de compras, sem navegador nem PC ligado.
// Entra com o utilizador guardado nos segredos ZS_NIF / ZS_USER / ZS_PASS (nunca no repositório) e só lê:
// lista os documentos de venda de cada dia (FT, FA, FS e NC), abre cada um para ter as linhas, soma por dia e artigo
// (anulados fora, NC a subtrair) e grava com compras_zs_auto_import, que substitui os dias enviados.
// Os cabeçalhos de menu entram com quantidade 0 e as linhas de composição interna do ZSbms (tipo 3) ficam de fora.
// Só aceita pedidos com o cabeçalho x-zs-key igual à chave guardada em compras_zs_cfg (usada pela tarefa agendada).
// Corpo (opcional): { "dias": ["2026-11-15"], "ensaio": true }. Sem "dias" lê desde o último dia com vendas
// (no máximo 6 dias para trás) até hoje. Com "ensaio" devolve as linhas e não grava nada.
const AUTH = "https://auth.zonesoft.org";
const APP = "https://client.zonesoft.org";
const ORIGIN = "https://zsbmsv2.zonesoft.org";
const UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36";
const TIPOS = ["FT", "FA", "FS", "NC"];
const SB_URL = Deno.env.get("SUPABASE_URL")!;
const SRK = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const SB = { apikey: SRK, Authorization: `Bearer ${SRK}`, "Content-Type": "application/json" };
const json = (b: unknown, s = 200) => new Response(JSON.stringify(b), { status: s, headers: { "Content-Type": "application/json" } });
const espera = (ms: number) => new Promise((r) => setTimeout(r, ms));

async function chaveCerta(k: string | null) {
  if (!k) return false;
  const r = await fetch(`${SB_URL}/rest/v1/compras_zs_cfg?select=chave`, { headers: SB });
  const t = await r.json().catch(() => null);
  return Array.isArray(t) && t[0]?.chave === k;
}
async function rpc(fn: string, args: unknown) {
  const r = await fetch(`${SB_URL}/rest/v1/rpc/${fn}`, { method: "POST", headers: SB, body: JSON.stringify(args) });
  const t = await r.json().catch(() => null);
  if (!r.ok) throw new Error(t?.message || "rpc_" + r.status);
  return t;
}
async function ultimoDia(): Promise<string | null> {
  const r = await fetch(`${SB_URL}/rest/v1/compras_sales?select=dia&order=dia.desc&limit=1`, { headers: SB });
  const t = await r.json().catch(() => null);
  return Array.isArray(t) && t[0]?.dia ? String(t[0].dia) : null;
}

const hojeLisboa = () => new Intl.DateTimeFormat("en-CA", { timeZone: "Europe/Lisbon" }).format(new Date());
function maisDias(d: string, n: number) {
  const x = new Date(d + "T12:00:00Z");
  x.setUTCDate(x.getUTCDate() + n);
  return x.toISOString().slice(0, 10);
}

// Faz os pedidos como a página do ZSbms: sessão por cookie e a chave da sessão dentro de Metadata
class Sessao {
  cookies = new Map<string, string>();
  tkKey = ""; tk = "";
  aEntrar: Promise<void> | null = null;

  async pedir(url: string, container?: unknown, meta?: { filter?: unknown; pagination?: unknown }, semCorpo = false) {
    const headers: Record<string, string> = { "X-Requested-With": "XMLHttpRequest", Accept: "application/json, text/plain, */*", Origin: ORIGIN, Referer: ORIGIN + "/", "User-Agent": UA };
    if (this.cookies.size) headers.Cookie = [...this.cookies].map(([k, v]) => `${k}=${v}`).join("; ");
    let body: string | undefined;
    if (!semCorpo) {
      headers["Content-Type"] = "application/json; charset=utf-8";
      const m: Record<string, unknown> = { _key: "", filter: meta?.filter ?? {}, pagination: meta?.pagination ?? {} };
      if (this.tkKey) m[this.tkKey] = this.tk;
      body = JSON.stringify({ Container: Array.isArray(container) ? container : [container ?? null], Metadata: m });
    }
    const r = await fetch(url, { method: "POST", headers, body, redirect: "manual" });
    for (const c of r.headers.getSetCookie()) {
      const p = c.split(";")[0], i = p.indexOf("=");
      if (i > 0) this.cookies.set(p.slice(0, i).trim(), p.slice(i + 1).trim());
    }
    const txt = await r.text();
    let data: any = null;
    try { data = JSON.parse(txt); } catch (_e) { /* resposta sem JSON */ }
    return { status: r.status, data };
  }

  entrar(): Promise<void> {
    if (!this.aEntrar) this.aEntrar = this.entrarJa().finally(() => { this.aEntrar = null; });
    return this.aEntrar;
  }
  private async entrarJa() {
    this.cookies.clear(); this.tkKey = ""; this.tk = "";
    let r = await this.pedir(AUTH + "/token", undefined, undefined, true);
    const t = r.data?.Container?.[0];
    if (!t?.tk_key) throw new Error("zsbms_token_" + r.status);
    this.tkKey = t.tk_key; this.tk = t.tk;
    r = await this.pedir(AUTH + "/login", { nif: Deno.env.get("ZS_NIF"), username: Deno.env.get("ZS_USER"), passwd: Deno.env.get("ZS_PASS") });
    if (r.status !== 200 || !r.data?.Container?.[0]) throw new Error("zsbms_login_" + r.status);
  }

  // Leitura com novas tentativas (falha de rede, erro do servidor ou sessão caída)
  async ler(path: string, meta?: { filter?: unknown; pagination?: unknown }) {
    for (let t = 0; ; t++) {
      let r;
      try { r = await this.pedir(APP + path, undefined, meta); }
      catch (e) { if (t >= 3) throw e; await espera(600 * (t + 1)); continue; }
      if ((r.status === 417 || r.status === 401) && t < 2) { await this.entrar(); continue; }
      if (r.status >= 500 && t < 3) { await espera(600 * (t + 1)); continue; }
      return r;
    }
  }
}

async function listar(s: Sessao, dia: string, doc: string) {
  const docs = new Map<string, any>();
  let total = -1, inicio = 0;
  for (let volta = 0; volta < 20; volta++) {
    const r = await s.ler("/Documentos/", {
      filter: { bind: { data: dia, doc }, conditions: " (Documentos.data = :data:) AND (Documentos.doc = :doc:)", sorting: "" },
      pagination: { currentPage: inicio, recordsPerPage: inicio + 500, numberOfPages: 0, totalRecords: 0 },
    });
    if (r.status === 204) break;
    if (r.status !== 200 || !Array.isArray(r.data?.Container)) throw new Error(`zsbms_lista_${doc}_${dia}_${r.status}`);
    total = Number(r.data?.Metadata?.pagination?.totalRecords ?? r.data.Container.length);
    const antes = docs.size;
    for (const d of r.data.Container) docs.set(`${d.loja}|${d.doc}|${d.serie}|${d.numero}`, d);
    if (docs.size >= total || docs.size === antes) break;
    inicio = docs.size;
  }
  if (docs.size < total) throw new Error(`zsbms_lista_incompleta_${doc}_${dia}`);
  return [...docs.values()];
}

async function emParalelo<T>(itens: T[], n: number, f: (x: T) => Promise<void>) {
  let i = 0;
  await Promise.all(Array.from({ length: Math.min(n, itens.length) }, async () => {
    while (i < itens.length) await f(itens[i++]);
  }));
}

Deno.serve(async (req: Request) => {
  if (!(await chaveCerta(req.headers.get("x-zs-key")))) return json({ error: "sem_acesso" }, 401);
  const b = await req.json().catch(() => ({}));
  const ensaio = b?.ensaio === true;
  try {
    for (const k of ["ZS_NIF", "ZS_USER", "ZS_PASS"]) if (!Deno.env.get(k)) throw new Error("falta_segredo_" + k);
    const hoje = hojeLisboa();
    let dias: string[];
    if (Array.isArray(b?.dias) && b.dias.length) {
      dias = [...new Set(b.dias.map(String))].filter((d) => /^\d{4}-\d{2}-\d{2}$/.test(d as string)).sort().slice(0, 10) as string[];
      if (!dias.length) throw new Error("dias_invalidos");
    } else {
      const ult = await ultimoDia();
      let de = maisDias(hoje, -6);
      if (ult && ult > de) de = ult;
      if (de > hoje) de = hoje;
      dias = [];
      for (let d = de; d <= hoje; d = maisDias(d, 1)) dias.push(d);
    }

    const s = new Sessao();
    await s.entrar();
    const soma = new Map<string, { dia: string; codigo: number; descricao: string; qtd: number; total: number }>();
    const porTipo: Record<string, number> = {};
    let documentos = 0, anulados = 0;
    const brutas: unknown[] = [];  // só no ensaio: linhas tal como vêm, para os códigos pedidos
    const formas: Record<string, { n: number; exemplos: string[] }> = {};  // só no ensaio: que tipos de linha apareceram
    for (const dia of dias) {
      for (const doc of TIPOS) {
        const lista = await listar(s, dia, doc);
        const validos = lista.filter((d) => !Number(d.anulado));
        anulados += lista.length - validos.length;
        documentos += validos.length;
        if (validos.length) porTipo[doc] = (porTipo[doc] || 0) + validos.length;
        const sinal = doc === "NC" ? -1 : 1;
        await emParalelo(validos, 5, async (d) => {
          const r = await s.ler("/Documentos/getInstance/" + JSON.stringify({ loja: d.loja, doc: d.doc, serie: d.serie, numero: d.numero }));
          const inst = r.data?.Container?.[0];
          if (r.status !== 200 || !inst || Number(inst.numero) !== Number(d.numero) || !Array.isArray(inst.linhas)) throw new Error(`zsbms_doc_${d.doc}_${d.serie}_${d.numero}_${r.status}`);
          for (const l of inst.linhas) {
            const codigo = Number(l.codigo);
            if (l.codigo == null || !Number.isInteger(codigo)) continue;
            if (ensaio && Array.isArray(b?.codigos) && b.codigos.includes(codigo) && brutas.length < 12) brutas.push(l);
            const tipo = Number(l.tipo) || 0, composto = String(l.composto ?? "0");
            if (ensaio) {
              const f = (formas[`tipo ${tipo} composto ${composto}`] ||= { n: 0, exemplos: [] });
              f.n++;
              if (f.exemplos.length < 4 && !f.exemplos.includes(String(l.descricao))) f.exemplos.push(String(l.descricao));
            }
            if (tipo === 3) continue;  // composição interna do ZSbms (ficha técnica do artigo vendido): não é uma venda
            const k = dia + "|" + codigo;
            const a = soma.get(k) || { dia, codigo, descricao: "", qtd: 0, total: 0 };
            // cabeçalho de menu (composto 2): fica o valor, mas a quantidade vem nas linhas dos componentes
            a.qtd += composto === "2" ? 0 : sinal * (Number(l.qtd) || 0);
            a.total += sinal * (Number(l.total) || 0);
            if (l.descricao) a.descricao = String(l.descricao);
            soma.set(k, a);
          }
        });
      }
    }
    const linhas = [...soma.values()].map((a) => ({ ...a, qtd: Math.round(a.qtd * 1e4) / 1e4, total: Math.round(a.total * 1e4) / 1e4 }));
    const info = { ok: true, dias, documentos, anulados, por_tipo: porTipo, artigos: linhas.length };
    if (ensaio) return json({ ...info, ensaio: true, linhas, brutas, formas });
    const gravado = await rpc("compras_zs_auto_import", { p_rows: linhas, p_info: info });
    return json({ ...info, gravado });
  } catch (e) {
    const info = { ok: false, erro: String((e as Error).message || e) };
    if (!ensaio) { try { await rpc("compras_zs_auto_import", { p_rows: null, p_info: info }); } catch (_e) { /* fica só na resposta */ } }
    return json(info, 500);
  }
});
