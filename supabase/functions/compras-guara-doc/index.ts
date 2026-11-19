// Confere uma fatura no documento original do Guará: abre as páginas (imagens) da fatura e lê-as com o Gemini.
// Só lê (GET) no Guará e não grava nada no Guará. Entra com os segredos GUARA_EMAIL / GUARA_PASS; lê com GEMINI_API_KEY.
// Só aceita pedidos com x-zs-key = compras_zs_cfg.chave.
// { "guara_id": 21702 }  devolve as linhas como estão no papel (preço unitário, desconto, IEC, IVA e valor da linha).
// { "fila": true }       lê as faturas antigas de compras_guara_doc_fila (as mais recentes primeiro), uma a uma, durante
//   ~20 s (normalmente uma por chamada), e grava o que leu na fila. Quando a Gemini diz que o limite acabou, para e marca uma pausa
//   (compras_guara_doc_estado.pausa_ate); o pg_cron (compras__doc_fila_disparar) volta a chamar quando a pausa passar.
const BASE = "https://guara.pt";
const UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36";
const SB_URL = Deno.env.get("SUPABASE_URL")!;
const SRK = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const SB = { apikey: SRK, Authorization: `Bearer ${SRK}`, "Content-Type": "application/json" };
const GEM = "https://generativelanguage.googleapis.com";
const json = (b: unknown, s = 200) => new Response(JSON.stringify(b), { status: s, headers: { "Content-Type": "application/json" } });

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
      const r = await fetch(url, { headers: dentro ? this.cab(accept ? { Accept: accept } : {}) : { "User-Agent": UA }, redirect: "manual", signal: AbortSignal.timeout(40_000) });
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

const PROMPT = `Estas imagens são as páginas de um documento de compra (fatura, nota de crédito ou talão) de um fornecedor de um restaurante em Portugal.
Transcreve TODAS as linhas de artigos exatamente como estão impressas (não calcules nada que não esteja escrito).
Responde só com JSON neste formato:
{"fornecedor":"","nif_fornecedor":"","tipo_documento":"","numero":"","data":"AAAA-MM-DD","total_sem_iva":0,"total_iva":0,"total_com_iva":0,
 "desconto_global":0,"precos_com_iva":false,
 "linhas":[{"codigo":"","descricao":"","quantidade":0,"unidade":"","preco_unitario":0,"iec_unitario":0,"desconto_pct":0,
   "preco_unitario_total":0,"taxa_iva":0,"valor_total":0}]}
- tipo_documento: "fatura", "nota de credito", "talao" ou "outro".
- preco_unitario: a coluna do preço unitário (ex.: "Pr. Unit.", "Preço").
- desconto_pct: o desconto da linha em % (ex.: coluna "Desc."); 0 se não houver.
- iec_unitario: o imposto especial de consumo por unidade (ex.: coluna "V. Unit IEC"); 0 se não houver.
- preco_unitario_total: a coluna do preço unitário total (ex.: "Prec. Unit. Total"); se não existir, 0.
- valor_total: o valor da linha (ex.: "Valor Total", "Total", "Importância"), depois do desconto da linha.
- desconto_global: desconto no fim do documento (ex.: "Desconto comercial", "Desc. financeiro"), em euros; 0 se não houver.
- precos_com_iva: true se os preços e valores das linhas já incluem IVA (ex.: talões de supermercado).
- Números com ponto decimal. Ignora linhas de texto que não são artigos (ex.: referências de guias, transportes já incluídos noutra linha).`;

class LimiteIA extends Error { constructor(public ate: Date, public motivo: string) { super("limite_ia"); } }

// Pausa a dar quando a Gemini responde 429: quota diária → até ao reinício (meia-noite do Pacífico, ~08:05 UTC);
// por minuto → o tempo que a Gemini pede (mínimo 1 min)
function pausaDe(j: any): { ate: Date; motivo: string } {
  const det: any[] = j?.error?.details || [];
  const quota = det.flatMap((d) => d?.violations || []).map((v: any) => String(v?.quotaId || "")).join(",");
  const atraso = Number(String(det.find((d) => d?.retryDelay)?.retryDelay || "").replace(/s$/, "")) || 0;
  if (/PerDay/i.test(quota)) {
    const a = new Date(); a.setUTCHours(8, 5, 0, 0);
    if (a.getTime() <= Date.now()) a.setUTCDate(a.getUTCDate() + 1);
    return { ate: a, motivo: "limite_diario " + quota };
  }
  return { ate: new Date(Date.now() + Math.max(60, atraso + 5) * 1000), motivo: "limite " + (quota || j?.error?.status || "429") };
}

// As páginas do Guará são PNG de ~7 MB: vão para a API de ficheiros da Gemini (envio resumível), uma a uma, sem base64,
// para a função não ficar sem memória nem CPU. Os ficheiros apagam-se no fim (e sozinhos ao fim de 48 h).
async function carregarFicheiro(buf: Uint8Array, tipo: string) {
  const k = Deno.env.get("GEMINI_API_KEY")!;
  const ini = await fetch(`${GEM}/upload/v1beta/files`, { method: "POST", headers: {
    "x-goog-api-key": k, "X-Goog-Upload-Protocol": "resumable", "X-Goog-Upload-Command": "start",
    "X-Goog-Upload-Header-Content-Length": String(buf.length), "X-Goog-Upload-Header-Content-Type": tipo, "Content-Type": "application/json" },
    body: JSON.stringify({ file: { display_name: "pagina" } }), signal: AbortSignal.timeout(20_000) });
  if (ini.status === 429) { const p = pausaDe(await ini.json().catch(() => null)); throw new LimiteIA(p.ate, p.motivo); }
  const url = ini.headers.get("x-goog-upload-url");
  await ini.body?.cancel();
  if (!ini.ok || !url) throw new Error("gemini_ficheiro_" + ini.status);
  const r = await fetch(url, { method: "POST", headers: { "Content-Length": String(buf.length), "X-Goog-Upload-Offset": "0", "X-Goog-Upload-Command": "upload, finalize" }, body: buf, signal: AbortSignal.timeout(45_000) });
  const j = await r.json().catch(() => null);
  if (r.status === 429) { const p = pausaDe(j); throw new LimiteIA(p.ate, p.motivo); }
  if (!r.ok || !j?.file?.uri) throw new Error("gemini_ficheiro_" + r.status);
  return { uri: j.file.uri as string, name: j.file.name as string };
}
async function apagarFicheiro(name: string) {
  try { const r = await fetch(`${GEM}/v1beta/${name}`, { method: "DELETE", headers: { "x-goog-api-key": Deno.env.get("GEMINI_API_KEY")! }, signal: AbortSignal.timeout(5_000) }); await r.body?.cancel(); } catch (_e) { /* apaga-se sozinho em 48 h */ }
}

// A soma das linhas (sem IVA, ou com IVA quando os preços vêm com IVA) deve bater com o total do documento (±3%,
// descontando o desconto global); quando não bate, a leitura fica marcada e tenta-se outro modelo
const nume = (v: unknown) => { const n = Number(String(v ?? "").replace(",", ".")); return Number.isFinite(n) ? n : 0; };
function conferir(d: any) {
  const linhas: any[] = Array.isArray(d?.linhas) ? d.linhas : [];
  const soma = Math.round(linhas.reduce((a, l) => a + (nume(l?.valor_total) || nume(l?.quantidade) * nume(l?.preco_unitario) * (1 - nume(l?.desconto_pct) / 100)), 0) * 100) / 100;
  // a soma pode bater com o total sem IVA, com o total sem IVA antes do desconto global, ou com o total com IVA (talões, talho)
  const alvos = [nume(d?.total_sem_iva), nume(d?.total_sem_iva) + Math.max(0, nume(d?.desconto_global)), nume(d?.total_com_iva)].filter((x) => x);
  if (!alvos.length || !linhas.length) return { soma, alvo: 0, dif_pct: 0, bate: null as boolean | null };
  const difs = alvos.map((a) => (soma - a) / Math.abs(a) * 100);
  const i = difs.reduce((m, x, k) => Math.abs(x) < Math.abs(difs[m]) ? k : m, 0);
  return { soma, alvo: Math.round(alvos[i] * 100) / 100, dif_pct: Math.round(difs[i] * 10) / 10, bate: Math.abs(difs[i]) <= 3 };
}

// Lê um documento do Guará com a Gemini. Devolve { ok, modelo, paginas, documento } ou { ok:false, erro }.
// Lança LimiteIA quando todos os modelos estão sem quota.
// A função tem 150 s no máximo: tudo tem de acabar antes de "fim" (senão a fatura fica presa e nada se grava)
async function lerDocumento(s: Sessao, gid: number, maxPag: number, modeloPedido?: string, esgotados = new Set<string>(), fim = Date.now() + 135_000) {
  const t0 = Date.now(), ms = () => Date.now() - t0;
  const det = await s.get(`/invoices/${gid}/detail`);
  const html = await det.text();
  const docs = [...new Set([...html.matchAll(/\/documents\/(\d+)\/pages\/\d+/g)].map((m) => m[1]))];
  if (!docs.length) return { ok: false, erro: "sem_documento", status: det.status };
  const paginas: unknown[] = [];
  const partes: unknown[] = [];
  const ficheiros: string[] = [];
  try {
    for (const d of docs) {
      for (let p = 1; p <= Math.min(maxPag, 6); p++) {
        if (fim - Date.now() < 70_000) { paginas.push({ documento: d, pagina: p, parou: "sem_tempo", ms: ms() }); break; }
        const r = await s.get(`/documents/${d}/pages/${p}`, "image/*,application/pdf,*/*");
        const tipo = (r.headers.get("content-type") || "").split(";")[0];
        if (r.status !== 200 || !/^image\/|^application\/pdf/.test(tipo)) { paginas.push({ documento: d, pagina: p, status: r.status, tipo }); await r.body?.cancel(); break; }
        const buf = new Uint8Array(await r.arrayBuffer());
        const desc = ms();
        const f = await carregarFicheiro(buf, tipo);
        paginas.push({ documento: d, pagina: p, status: r.status, tipo, tamanho: buf.length, ms_guara: desc, ms_envio: ms() });
        ficheiros.push(f.name);
        partes.push({ file_data: { mime_type: tipo, file_uri: f.uri } });
      }
    }
    if (!partes.length) return { ok: false, erro: "sem_imagens", paginas };
    const modelos = [...new Set([modeloPedido || "gemini-flash-latest", "gemini-flash-lite-latest"])].filter((m) => !esgotados.has(m));
    let erro = "", limite: { ate: Date; motivo: string } | null = null;
    const erros: string[] = [];
    let fraco: any = null;
    for (let i = 0; i < modelos.length; i++) {
      const m = modelos[i];
      const resta = fim - Date.now();
      // o modelo principal deixa ~35 s para o seguinte; o último fica com o que sobra
      const prazo = Math.min(i < modelos.length - 1 ? resta - 35_000 : resta - 3_000, 110_000);
      if (prazo < 12_000) { erros.push(`${m}: sem_tempo`); continue; }
      let g: Response, j: any = null;
      try {
        // pensar pouco: é só transcrever, e assim responde mais depressa
        const pedir = (pensar: boolean) => fetch(`${GEM}/v1beta/models/${encodeURIComponent(m)}:generateContent`, {
          method: "POST", headers: { "Content-Type": "application/json", "x-goog-api-key": Deno.env.get("GEMINI_API_KEY")! },
          body: JSON.stringify({ contents: [{ role: "user", parts: [{ text: PROMPT }, ...partes] }],
            generationConfig: { temperature: 0, responseMimeType: "application/json", ...(pensar ? { thinkingConfig: { thinkingLevel: "low" } } : {}) } }),
          signal: AbortSignal.timeout(Math.max(5_000, Math.min(prazo, fim - Date.now() - 3_000))) });
        g = await pedir(true);
        j = await g.json().catch(() => null);
        if (g.status === 400 && /thinking/i.test(String(j?.error?.message || ""))) { g = await pedir(false); j = await g.json().catch(() => null); }
      } catch (e) { erro = `${m}: ${(e as Error).name === "TimeoutError" ? "tempo_esgotado" : (e as Error).message}`; erros.push(erro); continue; }
      if (g.status === 429) { esgotados.add(m); limite = pausaDe(j); erro = `${m}: 429`; erros.push(erro); continue; }
      if (!g.ok) { erro = `${m}: ${g.status} ${String(j?.error?.message || "").slice(0, 160)}`; erros.push(erro); continue; }
      const t = (j?.candidates?.[0]?.content?.parts || []).map((x: any) => x.text || "").join("");
      let documento: any;
      try { documento = JSON.parse(t); } catch (_e) { erro = `${m}: resposta_sem_json`; erros.push(erro); continue; }
      const conferencia = conferir(documento);
      const r = { ok: true, modelo: m, paginas, documento, uso: j?.usageMetadata, conferencia, erros };
      // o modelo "lite" só conta quando a soma das linhas bate com o total (nas faturas grandes salta linhas)
      if (conferencia.bate === true || (conferencia.bate === null && !m.includes("lite"))) return r;
      // a soma das linhas não bate com o total: tenta o modelo seguinte e fica com o melhor
      erros.push(`${m}: soma ${conferencia.soma} ≠ ${conferencia.alvo}`);
      if (!fraco || Math.abs(conferencia.dif_pct) < Math.abs(fraco.conferencia.dif_pct)) fraco = r;
    }
    if (fraco) return fraco;
    if (limite && modelos.every((m) => esgotados.has(m))) throw new LimiteIA(limite.ate, limite.motivo);
    // todos os modelos sobrecarregados (503) ou sem resposta a tempo: não é culpa da fatura; pausa 5 min sem contar tentativa
    if (erros.length && erros.every((e) => /: 503 |tempo_esgotado|sem_tempo/.test(e))) throw new LimiteIA(new Date(Date.now() + 300_000), "gemini_sobrecarregada");
    return { ok: false, erro, erros, paginas };
  } finally {
    for (const n of ficheiros) await apagarFicheiro(n);
  }
}

// Lê faturas da fila (por defeito só começa uma nova nos primeiros 20 s, ou seja, uma por chamada) e grava cada resultado
async function fila(b: any) {
  // só começa outra fatura se ainda houver tempo para a ler inteira (a função é cortada aos 150 s)
  const ini = Date.now(), lim = Math.min(Number(b?.max_seg) || 20, 30) * 1000;
  const s = new Sessao();
  await s.entrar();
  const esgotados = new Set<string>();
  const feitas: unknown[] = [];
  let pausa: string | null = null;
  while (Date.now() - ini < lim) {
    const prox = await rpc("compras__doc_fila_proximas", { p_n: 1 });
    if (!Array.isArray(prox) || !prox.length) break;
    const f = prox[0];
    const t0 = Date.now();
    try {
      const r: any = await lerDocumento(s, f.guara_id, 4, undefined, esgotados, ini + 138_000);
      // leitura duvidosa (soma não bate ou só o "lite" respondeu): volta à fila para tentar mais tarde (até 4 vezes);
      // se o modelo principal estava sobrecarregado (503), pausa 3 minutos
      const duvidosa = r.ok && r.conferencia?.bate !== true && (r.conferencia?.bate === false || String(r.modelo).includes("lite"));
      if (duvidosa && f.tentativas < 4) {
        await rpc("compras__doc_fila_gravar", { p_guara_id: f.guara_id, p_estado: "pendente", p_resultado: { documento: r.documento, paginas: r.paginas, conferencia: r.conferencia, erros: r.erros, provisoria: true }, p_erro: "leitura_duvidosa " + (r.erros || []).join(" | ").slice(0, 300), p_modelo: r.modelo });
        feitas.push({ guara_id: f.guara_id, ok: false, duvidosa: true, erros: r.erros, seg: Math.round((Date.now() - t0) / 1000) });
        if ((r.erros || []).some((e: string) => /: 503 /.test(e))) { await rpc("compras__doc_fila_pausa", { p_ate: new Date(Date.now() + 180_000).toISOString(), p_motivo: "modelo_sobrecarregado" }); pausa = "3min"; break; }
        continue;
      }
      if (r.ok) await rpc("compras__doc_fila_gravar", { p_guara_id: f.guara_id, p_estado: "lida", p_resultado: { documento: r.documento, paginas: r.paginas, uso: r.uso, conferencia: r.conferencia, erros: r.erros }, p_erro: null, p_modelo: r.modelo });
      else await rpc("compras__doc_fila_gravar", { p_guara_id: f.guara_id, p_estado: /sem_documento|sem_imagens/.test(r.erro) ? "sem_documento" : "pendente", p_resultado: r.paginas ? { paginas: r.paginas } : null, p_erro: r.erro, p_modelo: null });
      feitas.push({ guara_id: f.guara_id, ok: r.ok, modelo: r.modelo, bate: r.conferencia?.bate, erro: r.erro, seg: Math.round((Date.now() - t0) / 1000) });
    } catch (e) {
      if (e instanceof LimiteIA) {
        await rpc("compras__doc_fila_gravar", { p_guara_id: f.guara_id, p_estado: "pendente_limite", p_resultado: null, p_erro: e.motivo, p_modelo: null });
        await rpc("compras__doc_fila_pausa", { p_ate: e.ate.toISOString(), p_motivo: e.motivo });
        pausa = e.ate.toISOString();
        break;
      }
      const msg = String((e as Error).message || e);
      await rpc("compras__doc_fila_gravar", { p_guara_id: f.guara_id, p_estado: "pendente", p_resultado: null, p_erro: msg, p_modelo: null });
      feitas.push({ guara_id: f.guara_id, ok: false, erro: msg });
      if (msg.startsWith("guara_")) break;
    }
  }
  const info = { ok: true, em: new Date().toISOString(), seg: Math.round((Date.now() - ini) / 1000), feitas, pausa_ate: pausa };
  await rpc("compras__doc_fila_registo", { p_info: info });
  return info;
}

Deno.serve(async (req: Request) => {
  if (!(await chaveCerta(req.headers.get("x-zs-key")))) return json({ error: "sem_acesso" }, 401);
  const b = await req.json().catch(() => ({}));
  try {
    for (const k of ["GUARA_EMAIL", "GUARA_PASS", "GEMINI_API_KEY"]) if (!Deno.env.get(k)) throw new Error("falta_segredo_" + k);
    if (b?.fila === true) return json(await fila(b));
    const gid = Number(b?.guara_id);
    if (!Number.isInteger(gid) || gid <= 0) return json({ error: "guara_id_invalido" }, 400);
    const s = new Sessao();
    await s.entrar();
    const r = await lerDocumento(s, gid, Number(b?.max_paginas) || 3, b?.modelo ? String(b.modelo) : undefined);
    return json({ guara_id: gid, ...r });
  } catch (e) {
    if (e instanceof LimiteIA) return json({ ok: false, erro: "limite_ia", motivo: e.motivo, ate: e.ate.toISOString() }, 429);
    return json({ ok: false, erro: String((e as Error).message || e) }, 500);
  }
});
