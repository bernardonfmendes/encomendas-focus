// Faturas e receitas do Guará (guara.pt) para a app de compras, sem navegador nem PC ligado. Só lê (GET) no Guará.
// Entra com os segredos GUARA_EMAIL / GUARA_PASS (nunca no repositório). Só aceita pedidos com x-zs-key = compras_zs_cfg.chave.
//
// { "modo": "faturas" }  lê as primeiras páginas da lista de faturas e, para cada fatura nova com as linhas já extraídas
//   pelo Guará ("Linhas: Concluído"), lê as linhas (página "Embalagens") e entrega a compras_guara_receber:
//   se todos os artigos já são conhecidos no fornecedor, fica importada; senão fica pendente para a correspondência.
//   Se o total sem IVA da fatura for menor do que a soma das linhas (desconto no fim da fatura), o desconto é
//   repartido pelos preços das linhas (fica o preço bruto em price_bruto).
// { "modo": "receitas" } lê as primeiras páginas da lista de receitas (as mexidas há menos tempo), abre cada uma e grava
//   as novas e as que mudaram (nome, rendimento, PVP ou ingredientes) com compras__import_recipes (nunca apaga receitas).
// { "modo": "releitura", "pag_de", "pag_ate", "desde" } lê faturas antigas para compras_guara_releitura (ver a função).
// "ensaio": true devolve o que leu e não grava nada. "ver" / "padrao" servem só para diagnóstico.
const BASE = "https://guara.pt";
const UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36";
const DESDE = "2026-11-01"; // faturas emitidas antes disto ficam de fora (o stock começa a 12/11)
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
async function rest(path: string) {
  const r = await fetch(`${SB_URL}/rest/v1/${path}`, { headers: SB });
  const t = await r.json().catch(() => null);
  if (!r.ok) throw new Error(t?.message || "rest_" + r.status);
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
  // GET a seguir redirecionamentos dentro do Guará, com novas tentativas em falhas de rede ou do servidor
  async get(path: string): Promise<{ status: number; url: string; html: string }> {
    for (let t = 0; ; t++) {
      try {
        let url = BASE + path;
        for (let i = 0; i < 6; i++) {
          const r = await fetch(url, { headers: this.cab(), redirect: "manual" });
          this.guardar(r);
          const loc = r.headers.get("location");
          if (r.status >= 300 && r.status < 400 && loc) { url = new URL(loc, url).toString(); await r.body?.cancel(); continue; }
          if (r.status >= 500 && t < 3) { await r.body?.cancel(); throw new Error("servidor_" + r.status); }
          const html = await r.text();
          if (url.includes("/users/log_in")) throw new Error("guara_sessao_caiu");
          return { status: r.status, url, html };
        }
        throw new Error("demasiados_redirecionamentos");
      } catch (e) {
        if (t >= 3 || String((e as Error).message).startsWith("guara_")) throw e;
        await espera(800 * (t + 1));
      }
    }
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
}

// ---------- leitura do HTML ----------
function limpar(h: string) {
  return h.replace(/<script[\s\S]*?<\/script>/gi, "").replace(/<svg[\s\S]*?<\/svg>/gi, "<svg/>").replace(/<style[\s\S]*?<\/style>/gi, "")
    .replace(/\s(class|style|data-phx-session|data-phx-static|aria-[a-z-]+|role|tabindex)="[^"]*"/gi, "").replace(/\s+/g, " ");
}
function ent(s: string) {
  return s.replace(/&#x([0-9a-f]+);/gi, (_, h) => String.fromCodePoint(parseInt(h, 16))).replace(/&#(\d+);/g, (_, d) => String.fromCodePoint(Number(d)))
    .replace(/&quot;/g, '"').replace(/&apos;/g, "'").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&nbsp;/g, " ").replace(/&amp;/g, "&");
}
const texto = (h: string) => ent(h.replace(/<[^>]*>/g, " ")).replace(/\s+/g, " ").trim();
// Números como o Guará os mostra: "1.395,92", "8,03", "150", "0.5"
function num(s: string | undefined | null): number | null {
  if (s == null) return null;
  let t = String(s).replace(/[€\s]/g, "").replace(/[^\d,.\-]/g, "");
  if (!t) return null;
  if (t.includes(",")) t = t.replace(/\./g, "").replace(",", ".");
  else if (/^-?\d{1,3}(\.\d{3})+$/.test(t)) t = t.replace(/\./g, "");
  const n = Number(t);
  return Number.isFinite(n) ? n : null;
}
const r4 = (n: number) => Math.round(n * 1e4) / 1e4;
// vasilhame / caução / depósito (o mesmo critério de compras__save_invoice)
const vasilhame = (d: string) => /(vasilhame|cau[cç][aã]o|dep[oó]sito)/i.test(d) || /(^|[^\p{L}\p{N}])(vas|grade)([^\p{L}\p{N}]|$)/iu.test(d);

async function emParalelo<T>(itens: T[], n: number, f: (x: T) => Promise<void>) {
  let i = 0;
  await Promise.all(Array.from({ length: Math.min(n, itens.length) }, async () => {
    while (i < itens.length) await f(itens[i++]);
  }));
}

// ---------- faturas ----------
type LinhaLista = { guara_id: number; estado: string; fornecedor: string; tipo: string; numero: string; total: number | null; sem_iva: number | null; data: string; linhas: string; correspondencia: string };

function lerListaFaturas(raw: string): LinhaLista[] {
  const h = limpar(raw);
  const out: LinhaLista[] = [];
  for (const parte of h.split('<tr id="row-').slice(1)) {
    const id = Number(parte.match(/^(\d+)"/)?.[1]);
    const cel = [...parte.matchAll(/<td data-cell="([a-z]+)">([\s\S]*?)<\/td>/g)].map((m) => ({ k: m[1], v: m[2] }));
    const meta = cel.filter((c) => c.k === "meta").map((c) => texto(c.v));
    const aside = texto(cel.find((c) => c.k === "aside")?.v || "");
    if (!id || meta.length < 8) continue;
    out.push({
      guara_id: id, estado: meta[0], fornecedor: meta[1], tipo: meta[2], numero: meta[3], total: num(meta[4]), sem_iva: num(meta[5]), data: meta[6],
      linhas: aside.match(/Linhas:\s*(.*?)\s*Correspond/)?.[1] || "", correspondencia: aside.match(/Correspondência:\s*(.*)$/)?.[1] || "",
    });
  }
  return out;
}

function lerLinhasFatura(raw: string) {
  const h = limpar(raw);
  const extrair = texto(h.match(/Extrair:([^<]*)</)?.[1] || "");
  const ini = h.indexOf("<th>Descrição</th>");
  const corpo = ini >= 0 ? h.slice(ini, h.indexOf("</tbody>", ini)) : "";
  const linhas: ({ desc: string; qty: number | null; price: number | null } & Record<string, unknown>)[] = [];
  for (const tr of corpo.split("<tr>").slice(1)) {
    const td = [...tr.matchAll(/<td>([\s\S]*?)<\/td>/g)].map((m) => m[1]);
    if (td.length < 4) continue;
    const desc = ent(td[1].match(/name="item\[description\]"[^>]*value="([^"]*)"/)?.[1] || texto(td[1]));
    const q = texto(td[2]);
    const qty = num(q.match(/^-?[\d.,]+/)?.[0]);
    const unidade = q.replace(/^-?[\d.,]+\s*/, "").trim();
    // "Preço da embalagem": preço de tabela e, quando há desconto na linha, "pago X" (o que se pagou de facto)
    const tabela = num(texto(td[3].split("<p>")[0]));
    const pago = num(texto(td[3]).match(/pago\s*([\d.,]+)/)?.[1]);
    const emb = td[5] ? [...td[5].matchAll(/<p>([\s\S]*?)<\/p>/g)].map((m) => texto(m[1])) : [];
    const l: Record<string, unknown> = { desc: desc.trim(), qty, unidade_fatura: unidade, price: pago ?? tabela, codigo: "", guara_estado: texto(td[4] || ""), guara_embalagem: emb[0] || "", guara_regra: emb[1] || "" };
    if (pago != null && tabela != null && pago !== tabela) l.price_tabela = tabela;
    linhas.push(l as { desc: string; qty: number | null; price: number | null } & Record<string, unknown>);
  }
  return { extrair, linhas };
}

// Lê as linhas de uma fatura e acerta os preços: "pago" quando o Guará o mostra; desconto no fim da fatura (ex.: Sumol
// Compal) repartido pelos produtos (o vasilhame e os depósitos não levam desconto), exceto quando a soma das linhas bate
// com o total com IVA (linhas já com IVA: talho, Continente).
async function montarFatura(s: Sessao, x: LinhaLista) {
  const r = await s.get(`/invoices/${x.guara_id}/detail`);
  const { extrair, linhas } = lerLinhasFatura(r.html);
  if (!linhas.length) return { sem_linhas: true, extrair };
  const valor = (l: { qty: number | null; price: number | null }) => (l.qty ?? 0) * (l.price ?? 0);
  const somaCont = linhas.filter((l) => vasilhame(l.desc)).reduce((a, l) => a + valor(l), 0);
  const somaProd = linhas.filter((l) => !vasilhame(l.desc)).reduce((a, l) => a + valor(l), 0);
  const soma = somaProd + somaCont;
  let desconto = 0;
  const comIva = x.total != null && x.total > 0 && Math.abs(soma - x.total) <= x.total * 0.003;
  if (x.sem_iva != null && x.sem_iva > 0 && somaProd > 0 && !comIva) {
    const f = (x.sem_iva - somaCont) / somaProd;
    if (f >= 0.4 && f <= 0.98) desconto = r4(1 - f);
  }
  const linhasFinais = linhas.map((l) => desconto && l.price != null && !vasilhame(l.desc) ? { ...l, price_bruto: l.price, price: r4(l.price * (1 - desconto)), desconto_pct: r4(desconto * 100) } : l);
  return { fat: {
    guara_id: x.guara_id, fornecedor_nome: x.fornecedor, numero: x.numero, data: x.data, total: x.total, total_sem_iva: x.sem_iva,
    tipo: x.tipo, soma_linhas: r4(soma), desconto_pct: desconto ? r4(desconto * 100) : 0, linhas: linhasFinais,
  } };
}

async function lerPaginas(s: Sessao, de: number, ate: number) {
  const lista: LinhaLista[] = [];
  await emParalelo(Array.from({ length: ate - de + 1 }, (_, i) => de + i), 3, async (p) => {
    lista.push(...lerListaFaturas((await s.get(p === 1 ? "/invoices" : `/invoices?page=${p}`)).html));
  });
  return [...new Map(lista.map((x) => [x.guara_id, x])).values()];
}

async function faturas(s: Sessao, b: any) {
  const ensaio = b?.ensaio === true;
  const maxPag = Math.min(Number(b?.paginas) || 10, 40);
  const unicas = await lerPaginas(s, 1, maxPag);
  const candidatas = unicas.filter((x) => x.linhas === "Concluído" && x.data >= DESDE);
  const vistas = new Set<number>();
  if (candidatas.length) {
    const t = await rest(`compras_guara_faturas?select=guara_id&guara_id=in.(${candidatas.map((x) => x.guara_id).join(",")})`);
    for (const x of t || []) vistas.add(Number(x.guara_id));
  }
  const novas = candidatas.filter((x) => !vistas.has(x.guara_id) || (ensaio && b?.rever === true));
  const resultados: unknown[] = [];
  const lidas: unknown[] = [];
  await emParalelo(novas, 3, async (x) => {
    const m = await montarFatura(s, x);
    if (!m.fat) { resultados.push({ guara_id: x.guara_id, fornecedor: x.fornecedor, numero: x.numero, estado: "sem_linhas", extrair: m.extrair }); return; }
    if (ensaio) { lidas.push(m.fat); return; }
    const res = await rpc("compras_guara_receber", { p_fat: m.fat });
    resultados.push({ guara_id: x.guara_id, fornecedor: x.fornecedor, numero: x.numero, ...res });
  });
  const info = {
    ok: true, paginas: maxPag, na_lista: unicas.length, com_linhas: candidatas.length, novas: novas.length,
    por_tipo: unicas.reduce((a: Record<string, number>, x) => { a[x.tipo] = (a[x.tipo] || 0) + 1; return a; }, {}),
    a_extrair: unicas.filter((x) => x.data >= DESDE && x.linhas !== "Concluído" && x.linhas !== "Inativa").map((x) => ({ guara_id: x.guara_id, fornecedor: x.fornecedor, linhas: x.linhas })),
    resultados,
  };
  if (ensaio) return { ...info, ensaio: true, lidas, lista: b?.lista ? unicas : undefined };
  await rpc("compras_guara_registo", { p_modo: "faturas", p_info: info });
  return info;
}

// { "modo": "releitura", "pag_de": 11, "pag_ate": 30, "desde": "2026-08-31" }: lê as faturas dessas páginas da lista
// (com linhas e emitidas desde "desde") e guarda-as em compras_guara_releitura, sem mexer nas faturas da app.
async function releitura(s: Sessao, b: any) {
  const de = Math.max(1, Number(b?.pag_de) || 1);
  const ate = Math.max(de, Math.min(Number(b?.pag_ate) || de + 19, de + 39));
  const desde = /^\d{4}-\d{2}-\d{2}$/.test(String(b?.desde || "")) ? String(b.desde) : DESDE;
  const unicas = await lerPaginas(s, de, ate);
  const cand = unicas.filter((x) => x.linhas === "Concluído" && x.data >= desde);
  let guardadas = 0;
  const sem: unknown[] = [];
  await emParalelo(cand, 3, async (x) => {
    const m = await montarFatura(s, x);
    if (!m.fat) { sem.push({ guara_id: x.guara_id, fornecedor: x.fornecedor, numero: x.numero }); return; }
    await rpc("compras_guara_releitura_guardar", { p_fat: m.fat });
    guardadas++;
  });
  const datas = unicas.map((x) => x.data).filter((d) => /^\d{4}-\d{2}-\d{2}$/.test(d)).sort();
  return { ok: true, paginas: [de, ate], na_lista: unicas.length, com_linhas: cand.length, guardadas, sem_linhas: sem,
    data_mais_antiga: datas[0] ?? null, data_mais_recente: datas[datas.length - 1] ?? null };
}

// ---------- receitas ----------
function lerListaReceitas(raw: string) {
  const out: { id: string; nome: string; custo: number | null }[] = [];
  const partes = limpar(raw).split('<li id="recipe-').slice(1);
  for (const p of partes) {
    const id = p.match(/^(\d+)"/)?.[1];
    if (!id) continue;
    const nome = ent(p.match(/<span title="([^"]*)"/)?.[1] || "").trim();
    const custo = num(p.match(new RegExp(`id="cost-preview-price-${id}"[^>]*>([^<]*)<`))?.[1]);
    out.push({ id, nome, custo });
  }
  return out;
}

const UN: Record<string, [string, number]> = { g: ["kg", 1000], kg: ["kg", 1], ml: ["L", 1000], cl: ["L", 100], dl: ["L", 10], l: ["L", 1], u: ["un", 1], un: ["un", 1], cm: ["un", 1] };
function converter(q: number | null, u: string): [number | null, string] {
  const c = UN[(u || "").toLowerCase()] || ["un", 1];
  return [q == null ? null : Math.round(q / c[1] * 1e6) / 1e6, c[0]];
}

function lerReceita(raw: string, id: string) {
  const h = limpar(raw);
  const val = (nome: string) => { const m = h.match(new RegExp(`name="recipe\\[${nome}\\]"[^>]*value="([^"]*)"`)); return m ? ent(m[1]) : null; };
  const sel = (nome: string) => { const m = h.match(new RegExp(`name="recipe\\[${nome}\\]">([\\s\\S]*?)</select>`)); return m?.[1].match(/<option selected value="([^"]*)"/)?.[1] ?? null; };
  const nome = val("name");
  if (!nome) throw new Error("receita_sem_nome_" + id);
  const final = /name="recipe\[final\]" value="true" checked/.test(h);
  const [rend, rendUn] = converter(num(val("quantity")), sel("measure") || "u");
  const alerg = [...h.matchAll(/id="recipe-form-allergen-icons-[a-z_]+"> <svg\/> <\/span> <\/span> <span>([^<]+)<\/span>/g)].map((m) => ent(m[1]).trim());
  const custo = num(h.match(/id="recipe-panel-total"> <span data-costs-version="\d+"> ([^<]*)</)?.[1]);
  const ini = h.indexOf("<h3>Ingredientes</h3>");
  const zona = ini >= 0 ? h.slice(ini) : "";
  const marcas = [...zona.matchAll(/phx-click="panel_open_ingredient" phx-value-type="(supply|recipe)" phx-value-ref_id="(\d+)"> ([\s\S]*?) <\/button>/g)];
  const ingredientes = marcas.map((m, i) => {
    const bloco = zona.slice(m.index!, i + 1 < marcas.length ? marcas[i + 1].index : undefined);
    const qm = bloco.match(/name="ingredients\[\d+\]\[quantity\]" value="([^"]*)"[^>]*> <\/div> <span> ([^<]*?) <\/span>/);
    const [qty, unidade] = converter(num(qm?.[1]), (qm?.[2] || "").trim());
    const c = num(bloco.match(/data-costs-version="\d+"> ([^<]*)</)?.[1]);
    const it: Record<string, unknown> = { nome: ent(m[3]).replace(/\s*\[[^\]]*\]\s*$/, "").trim(), qty, unidade };
    if (m[1] === "recipe") it.sub_receita_id = m[2];
    if (c != null) it.custo = c;
    return it;
  });
  const iva = num(sel("vat_rate"));
  return {
    guara_id: id, nome, categoria: val("category") || "", rendimento: rend, rendimento_unidade: rendUn,
    preco_venda: final ? num(val("pvp")) : null,
    extra: { final, iva: final ? iva : null, food_cost_pct: final ? num(val("food_cost_pct")) : null, custo_guara: custo, alergenios: alerg },
    ingredientes,
  };
}

// Assinatura do que conta para o stock (nome, rendimento, PVP e ingredientes), para só regravar receitas que mudaram
const n6 = (v: unknown) => (v == null || v === "" ? null : Math.round(Number(v) * 1e6) / 1e6);
const nm = (v: unknown) => String(v ?? "").replace(/\s+/g, " ").trim();
function assinatura(r: any, itens: any[]) {
  return JSON.stringify([nm(r.nome), nm(r.categoria), n6(r.rendimento), r.rendimento_unidade, n6(r.preco_venda),
    itens.map((i) => [nm(i.nome ?? i.ingrediente), n6(i.qty), i.unidade, String(i.sub_receita_id ?? i.sub_recipe_guara_id ?? "") || null])]);
}

// A lista do Guará vem ordenada pelas receitas mexidas há menos tempo, mas a ordem não é estável entre páginas;
// por isso lê-se só o princípio (novas e alteradas aparecem aí) e compara-se receita a receita.
async function receitas(s: Sessao, b: any) {
  const ensaio = b?.ensaio === true;
  const max = Math.min(Number(b?.max) || 80, 150);
  let alvo: { id: string; motivo: string }[] = [];
  let resumo: Record<string, unknown> = {};
  if (Array.isArray(b?.ids) && b.ids.length) {
    alvo = b.ids.map((x: unknown) => ({ id: String(x), motivo: "pedida" }));
  } else {
    const pags = Math.min(Number(b?.paginas) || 6, 70);
    const lista: { id: string; nome: string; custo: number | null }[] = [];
    await emParalelo(Array.from({ length: pags }, (_, i) => i + 1), 4, async (p) => {
      lista.push(...lerListaReceitas((await s.get(p === 1 ? "/recipes" : `/recipes?page=${p}`)).html));
    });
    const ids = [...new Set(lista.map((x) => x.id))];
    const conhecidas = new Set<string>();
    if (ids.length) for (const x of await rest(`compras_recipes?select=guara_id&guara_id=in.(${ids.join(",")})`)) conhecidas.add(String(x.guara_id));
    alvo = ids.map((id) => ({ id, motivo: conhecidas.has(id) ? "ver" : "nova" }));
    alvo.sort((a, c) => (a.motivo === "nova" ? 0 : 1) - (c.motivo === "nova" ? 0 : 1));
    resumo = { paginas: pags, vistas: ids.length };
  }
  const fazer = alvo.slice(0, max);
  const lidas: any[] = [];
  const erros: string[] = [];
  await emParalelo(fazer, 4, async (x) => {
    try { lidas.push({ ...lerReceita((await s.get(`/recipes/${x.id}/edit`)).html, x.id), motivo: x.motivo }); }
    catch (e) { erros.push(`${x.id}: ${(e as Error).message}`); }
  });
  // só fica o que é novo ou mudou
  const ver = lidas.filter((x) => x.motivo === "ver");
  if (ver.length) {
    const db = await rest(`compras_recipes?select=guara_id,nome,categoria,rendimento,rendimento_unidade,preco_venda,compras_recipe_items(ordem,ingrediente,qty,unidade,sub_recipe_guara_id)&guara_id=in.(${ver.map((x) => x.guara_id).join(",")})`);
    const sig = new Map<string, string>(db.map((r: any) => [String(r.guara_id), assinatura(r, [...(r.compras_recipe_items || [])].sort((a: any, c: any) => a.ordem - c.ordem))]));
    for (const x of ver) x.motivo = sig.get(x.guara_id) === assinatura(x, x.ingredientes) ? "igual" : "mudou";
  }
  const gravar = lidas.filter((x) => x.motivo !== "igual");
  const info: Record<string, unknown> = { ok: true, ...resumo, lidas: lidas.length, faltam: Math.max(0, alvo.length - fazer.length), erros,
    novas: gravar.filter((x) => x.motivo === "nova").map((x) => `${x.guara_id} ${x.nome}`),
    mudaram: gravar.filter((x) => x.motivo === "mudou").map((x) => `${x.guara_id} ${x.nome}`) };
  if (ensaio) return { ...info, ensaio: true, receitas: b?.detalhe ? gravar : undefined };
  if (gravar.length) info.gravado = await rpc("compras__import_recipes", { p_receitas: gravar.map(({ motivo: _m, ...r }) => r), p_completo: false });
  await rpc("compras_guara_registo", { p_modo: "receitas", p_info: info });
  return info;
}

Deno.serve(async (req: Request) => {
  if (!(await chaveCerta(req.headers.get("x-zs-key")))) return json({ error: "sem_acesso" }, 401);
  const b = await req.json().catch(() => ({}));
  const modo = String(b?.modo || "");
  try {
    for (const k of ["GUARA_EMAIL", "GUARA_PASS"]) if (!Deno.env.get(k)) throw new Error("falta_segredo_" + k);
    const s = new Sessao();
    await s.entrar();
    if (modo === "faturas") return json(await faturas(s, b));
    if (modo === "receitas") return json(await receitas(s, b));
    if (modo === "releitura") return json(await releitura(s, b));
    if (modo === "ver" || modo === "padrao") {
      const path = String(b.path || "/");
      if (!/^\/[A-Za-z0-9_\-\/?=&%.]*$/.test(path) || /log_out|delete|remove|apagar/i.test(path)) return json({ error: "caminho_nao_permitido" }, 400);
      const p = await s.get(path);
      if (modo === "padrao") {
        const m = [...p.html.matchAll(new RegExp(String(b.re), "g"))].map((x) => x.slice(1).join(" | "));
        return json({ status: p.status, url: p.url, len: p.html.length, n: m.length, m: m.slice(0, b.max || 50), fim: m.slice(-5) });
      }
      let h = limpar(p.html);
      const ini = b.desde ? Math.max(0, h.indexOf(String(b.desde))) : Math.max(0, h.indexOf("<main"));
      h = h.slice(ini + (b.salto || 0), ini + (b.salto || 0) + (b.max || 12000));
      return json({ status: p.status, url: p.url, len: p.html.length, html: h });
    }
    return json({ error: "modo_desconhecido" }, 400);
  } catch (e) {
    const info = { ok: false, erro: String((e as Error).message || e) };
    if ((modo === "faturas" || modo === "receitas") && b?.ensaio !== true) { try { await rpc("compras_guara_registo", { p_modo: modo, p_info: info }); } catch (_e) { /* fica só na resposta */ } }
    return json(info, 500);
  }
});
