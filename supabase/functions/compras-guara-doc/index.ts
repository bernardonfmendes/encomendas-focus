// Confere uma fatura no documento original do Guará: abre as páginas (imagens) da fatura e lê-as com o Gemini.
// Só lê (GET) no Guará e não grava nada. Entra com os segredos GUARA_EMAIL / GUARA_PASS; lê com GEMINI_API_KEY.
// Só aceita pedidos com x-zs-key = compras_zs_cfg.chave. Corpo: { "guara_id": 21702 } (id da fatura no Guará).
// Devolve as linhas como estão no papel: preço unitário, IEC, preço unitário total, IVA e valor da linha.
const BASE = "https://guara.pt";
const UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36";
const SB_URL = Deno.env.get("SUPABASE_URL")!;
const SRK = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const SB = { apikey: SRK, Authorization: `Bearer ${SRK}` };
const json = (b: unknown, s = 200) => new Response(JSON.stringify(b), { status: s, headers: { "Content-Type": "application/json" } });

async function chaveCerta(k: string | null) {
  if (!k) return false;
  const r = await fetch(`${SB_URL}/rest/v1/compras_zs_cfg?select=chave`, { headers: SB });
  const t = await r.json().catch(() => null);
  return Array.isArray(t) && t[0]?.chave === k;
}

class Sessao {
  cookies = new Map<string, string>();
  guardar(r: Response) {
    for (const c of r.headers.getSetCookie()) {
      const p = c.split(";")[0], i = p.indexOf("=");
      if (i > 0) this.cookies.set(p.slice(0, i).trim(), p.slice(i + 1).trim());
    }
  }
  cab(extra: Record<string, string> = {}) {
    const h: Record<string, string> = { "User-Agent": UA, Accept: "text/html,application/xhtml+xml", "Accept-Language": "pt-PT,pt;q=0.9", ...extra };
    if (this.cookies.size) h.Cookie = [...this.cookies].map(([k, v]) => `${k}=${v}`).join("; ");
    return h;
  }
  async entrar() {
    const pg = await fetch(BASE + "/users/log_in", { headers: this.cab(), redirect: "manual" });
    this.guardar(pg);
    const html = await pg.text();
    const csrf = html.match(/name="_csrf_token"[^>]*value="([^"]+)"/)?.[1];
    if (!csrf) throw new Error("guara_sem_csrf");
    const body = new URLSearchParams({ _csrf_token: csrf, "user[email]": Deno.env.get("GUARA_EMAIL") || "", "user[password]": Deno.env.get("GUARA_PASS") || "", "user[remember_me]": "true" });
    const r = await fetch(BASE + "/users/log_in", { method: "POST", headers: this.cab({ "Content-Type": "application/x-www-form-urlencoded", Origin: BASE, Referer: BASE + "/users/log_in" }), body, redirect: "manual" });
    this.guardar(r);
    const loc = r.headers.get("location") || "";
    await r.body?.cancel();
    if (r.status !== 302 || loc.includes("log_in")) throw new Error("guara_login_" + r.status);
  }
  // GET a seguir redirecionamentos; os cookies só vão para o próprio Guará
  async get(path: string, accept?: string) {
    let url = BASE + path;
    for (let i = 0; i < 6; i++) {
      const dentro = new URL(url).origin === BASE;
      const r = await fetch(url, { headers: dentro ? this.cab(accept ? { Accept: accept } : {}) : { "User-Agent": UA }, redirect: "manual" });
      if (dentro) this.guardar(r);
      const loc = r.headers.get("location");
      if (r.status >= 300 && r.status < 400 && loc) {
        url = new URL(loc, url).toString(); await r.body?.cancel();
        if (url.includes("/users/log_in")) throw new Error("guara_sessao_caiu");
        continue;
      }
      return r;
    }
    throw new Error("demasiados_redirecionamentos");
  }
}

function base64(buf: Uint8Array) {
  let bin = "";
  for (let j = 0; j < buf.length; j += 0x8000) bin += String.fromCharCode(...buf.subarray(j, j + 0x8000));
  return btoa(bin);
}

const PROMPT = `Estas imagens são as páginas de uma fatura portuguesa de um fornecedor de um restaurante.
Transcreve TODAS as linhas de artigos exatamente como estão impressas (não calcules nada que não esteja escrito).
Responde só com JSON neste formato:
{"numero":"","data":"AAAA-MM-DD","total_sem_iva":0,"total_iva":0,"total_com_iva":0,
 "linhas":[{"codigo":"","descricao":"","quantidade":0,"unidade":"","preco_unitario":0,"iec_unitario":0,"desconto_pct":0,
   "preco_unitario_total":0,"taxa_iva":0,"valor_total":0}]}
- preco_unitario: a coluna do preço unitário (ex.: "Pr. Unit.").
- iec_unitario: o imposto especial de consumo por unidade (ex.: coluna "V. Unit IEC"); 0 se não houver.
- preco_unitario_total: a coluna do preço unitário total (ex.: "Prec. Unit. Total"); se não existir, preço unitário + IEC.
- valor_total: o valor da linha (ex.: "Valor Total").
- Números com ponto decimal. Ignora linhas de texto que não são artigos (ex.: referências de guias).`;

Deno.serve(async (req: Request) => {
  if (!(await chaveCerta(req.headers.get("x-zs-key")))) return json({ error: "sem_acesso" }, 401);
  const b = await req.json().catch(() => ({}));
  try {
    for (const k of ["GUARA_EMAIL", "GUARA_PASS", "GEMINI_API_KEY"]) if (!Deno.env.get(k)) throw new Error("falta_segredo_" + k);
    const gid = Number(b?.guara_id);
    if (!Number.isInteger(gid) || gid <= 0) return json({ error: "guara_id_invalido" }, 400);
    const s = new Sessao();
    await s.entrar();
    const det = await s.get(`/invoices/${gid}/detail`);
    const html = await det.text();
    const docs = [...new Set([...html.matchAll(/\/documents\/(\d+)\/pages\/\d+/g)].map((m) => m[1]))];
    if (!docs.length) return json({ ok: false, erro: "sem_documento", status: det.status });
    const imagens: { mime_type: string; data: string }[] = [];
    const paginas: unknown[] = [];
    for (const d of docs) {
      for (let p = 1; p <= Math.min(Number(b?.max_paginas) || 3, 6); p++) {
        const r = await s.get(`/documents/${d}/pages/${p}`, "image/*,application/pdf,*/*");
        const tipo = (r.headers.get("content-type") || "").split(";")[0];
        const buf = new Uint8Array(await r.arrayBuffer());
        paginas.push({ documento: d, pagina: p, status: r.status, tipo, tamanho: buf.length });
        if (r.status !== 200 || !/^image\/|^application\/pdf/.test(tipo)) break;
        imagens.push({ mime_type: tipo, data: base64(buf) });
      }
    }
    if (!imagens.length) return json({ ok: false, erro: "sem_imagens", paginas });
    const modelos = [String(b?.modelo || "gemini-flash-latest"), "gemini-flash-lite-latest"];
    const parts: unknown[] = [{ text: PROMPT }, ...imagens.map((im) => ({ inline_data: im }))];
    let erro = "";
    for (const m of modelos) {
      const g = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(m)}:generateContent`, {
        method: "POST", headers: { "Content-Type": "application/json", "x-goog-api-key": Deno.env.get("GEMINI_API_KEY")! },
        body: JSON.stringify({ contents: [{ role: "user", parts }], generationConfig: { temperature: 0, responseMimeType: "application/json" } }) });
      const j = await g.json().catch(() => null);
      if (!g.ok) { erro = `${m}: ${g.status}`; continue; }
      const t = (j?.candidates?.[0]?.content?.parts || []).map((x: any) => x.text || "").join("");
      try { return json({ ok: true, guara_id: gid, modelo: m, paginas, documento: JSON.parse(t) }); }
      catch (_e) { erro = `${m}: resposta_sem_json`; }
    }
    return json({ ok: false, erro, paginas });
  } catch (e) {
    return json({ ok: false, erro: String((e as Error).message || e) }, 500);
  }
});
