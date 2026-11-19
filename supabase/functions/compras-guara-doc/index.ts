// Confere uma fatura no documento original do Guará: abre as páginas (imagens) da fatura e lê-as com o Gemini.
// Só lê (GET) no Guará e não grava nada no Guará. Entra com os segredos GUARA_EMAIL / GUARA_PASS; lê com GEMINI_API_KEY.
// Só aceita pedidos com x-zs-key = compras_zs_cfg.chave.
// { "guara_id": 21702 }  devolve as linhas como estão no papel (preço unitário, desconto, IEC, IVA e valor da linha).
// { "fila": true }       lê as faturas antigas de compras_guara_doc_fila (as mais recentes primeiro), uma a uma, durante
//   ~80 s, e grava o que leu na fila. Quando a Gemini diz que o limite acabou, para e marca uma pausa
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

// Imagens grandes (as páginas do Guará são PNG de ~7 MB) vão pela API de ficheiros da Gemini quando o pedido passaria dos 20 MB
async function carregarFicheiro(buf: Uint8Array, tipo: string) {
  const k = Deno.env.get("GEMINI_API_KEY")!;
  const fd = new FormData();
  fd.append("metadata", new Blob([JSON.stringify({ file: { display_name: "pagina" } })], { type: "application/json" }));
  fd.append("file", new Blob([buf], { type: tipo }));
  const r = await fetch(`${GEM}/upload/v1beta/files?uploadType=multipart`, { method: "POST", headers: { "x-goog-api-key": k }, body: fd });
  const j = await r.json().catch(() => null);
  if (r.status === 429) { const p = pausaDe(j); throw new LimiteIA(p.ate, p.motivo); }
  if (!r.ok || !j?.file?.uri) throw new Error("gemini_ficheiro_" + r.status);
  return { uri: j.file.uri as string, name: j.file.name as string };
}
async function apagarFicheiro(name: string) {
  try { await fetch(`${GEM}/v1beta/${name}`, { method: "DELETE", headers: { "x-goog-api-key": Deno.env.get("GEMINI_API_KEY")! } }); } catch (_e) { /* apaga-se sozinho em 48 h */ }
}

// Lê um documento do Guará com a Gemini. Devolve { ok, modelo, paginas, documento } ou { ok:false, erro }.
// Lança LimiteIA quando todos os modelos estão sem quota.
async function lerDocumento(s: Sessao, gid: number, maxPag: number, modeloPedido?: string, esgotados = new Set<string>()) {
  const det = await s.get(`/invoices/${gid}/detail`);
  const html = await det.text();
  const docs = [...new Set([...html.matchAll(/\/documents\/(\d+)\/pages\/\d+/g)].map((m) => m[1]))];
  if (!docs.length) return { ok: false, erro: "sem_documento", status: det.status };
  const imagens: { tipo: string; buf: Uint8Array }[] = [];
  const paginas: unknown[] = [];
  for (const d of docs) {
    for (let p = 1; p <= Math.min(maxPag, 6); p++) {
      const r = await s.get(`/documents/${d}/pages/${p}`, "image/*,application/pdf,*/*");
      const tipo = (r.headers.get("content-type") || "").split(";")[0];
      const buf = new Uint8Array(await r.arrayBuffer());
      paginas.push({ documento: d, pagina: p, status: r.status, tipo, tamanho: buf.length });
      if (r.status !== 200 || !/^image\/|^application\/pdf/.test(tipo)) break;
      imagens.push({ tipo, buf });
    }
  }
  if (!imagens.length) return { ok: false, erro: "sem_imagens", paginas };
  const total = imagens.reduce((a, x) => a + x.buf.length, 0);
  const ficheiros: string[] = [];
  try {
    let partes: unknown[];
    if (total <= 13_000_000) partes = imagens.map((im) => ({ inline_data: { mime_type: im.tipo, data: base64(im.buf) } }));
    else {
      partes = [];
      for (const im of imagens) { const f = await carregarFicheiro(im.buf, im.tipo); ficheiros.push(f.name); partes.push({ file_data: { mime_type: im.tipo, file_uri: f.uri } }); }
    }
    const modelos = [...new Set([modeloPedido || "gemini-flash-latest", "gemini-flash-lite-latest"])].filter((m) => !esgotados.has(m));
    let erro = "", limite: { ate: Date; motivo: string } | null = null;
    for (const m of modelos) {
      let g: Response;
      try {
        g = await fetch(`${GEM}/v1beta/models/${encodeURIComponent(m)}:generateContent`, {
          method: "POST", headers: { "Content-Type": "application/json", "x-goog-api-key": Deno.env.get("GEMINI_API_KEY")! },
          body: JSON.stringify({ contents: [{ role: "user", parts: [{ text: PROMPT }, ...partes] }], generationConfig: { temperature: 0, responseMimeType: "application/json" } }),
          signal: AbortSignal.timeout(100_000) });
      } catch (e) { erro = `${m}: ${(e as Error).name === "TimeoutError" ? "tempo_esgotado" : (e as Error).message}`; continue; }
      const j = await g.json().catch(() => null);
      if (g.status === 429) { esgotados.add(m); limite = pausaDe(j); erro = `${m}: 429`; continue; }
      if (!g.ok) { erro = `${m}: ${g.status} ${String(j?.error?.message || "").slice(0, 120)}`; continue; }
      const t = (j?.candidates?.[0]?.content?.parts || []).map((x: any) => x.text || "").join("");
      try { return { ok: true, modelo: m, paginas, documento: JSON.parse(t), uso: j?.usageMetadata }; }
      catch (_e) { erro = `${m}: resposta_sem_json`; }
    }
    if (limite && modelos.every((m) => esgotados.has(m))) throw new LimiteIA(limite.ate, limite.motivo);
    return { ok: false, erro, paginas };
  } finally {
    for (const n of ficheiros) await apagarFicheiro(n);
  }
}

// Lê faturas da fila durante ~80 s (não começa uma nova depois disso) e grava cada resultado
async function fila(b: any) {
  const ini = Date.now(), lim = Math.min(Number(b?.max_seg) || 80, 200) * 1000;
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
      const r: any = await lerDocumento(s, f.guara_id, 4, undefined, esgotados);
      if (r.ok) await rpc("compras__doc_fila_gravar", { p_guara_id: f.guara_id, p_estado: "lida", p_resultado: { documento: r.documento, paginas: r.paginas, uso: r.uso }, p_erro: null, p_modelo: r.modelo });
      else await rpc("compras__doc_fila_gravar", { p_guara_id: f.guara_id, p_estado: /sem_documento|sem_imagens/.test(r.erro) ? "sem_documento" : "pendente", p_resultado: r.paginas ? { paginas: r.paginas } : null, p_erro: r.erro, p_modelo: null });
      feitas.push({ guara_id: f.guara_id, ok: r.ok, modelo: r.modelo, erro: r.erro, seg: Math.round((Date.now() - t0) / 1000) });
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
