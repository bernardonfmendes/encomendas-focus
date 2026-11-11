// Lê faturas (fotos ou PDF) com o Gemini. Autenticação própria: token de sessão da app de compras (só chefes).
// modo "fila": responde logo com o id do rascunho e lê em segundo plano.
const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (b: unknown, s = 200) => new Response(JSON.stringify(b), { status: s, headers: { ...CORS, "Content-Type": "application/json" } });
const CATS = ["Peixe e marisco", "Carne", "Legumes e fruta", "Mercearia", "Bebidas", "Limpeza e higiene", "Descartáveis", "Outros"];
const MIMES = ["image/jpeg", "image/png", "image/webp", "application/pdf"];
const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));
const BUDGET_MS = 120000;
const CALL_MS = 45000;
const URL_ = Deno.env.get("SUPABASE_URL")!;
const KEY = Deno.env.get("SUPABASE_ANON_KEY") || Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

async function rpc(fn: string, args: unknown) {
  const r = await fetch(`${URL_}/rest/v1/rpc/${fn}`, { method: "POST", headers: { apikey: KEY, Authorization: `Bearer ${KEY}`, "Content-Type": "application/json" }, body: JSON.stringify(args) });
  const t = await r.json().catch(() => null);
  if (!r.ok) throw new Error(t?.message || "rpc " + r.status);
  return t;
}

function buildPrompt(n: number, catalog: string) {
  return `Os ficheiros são uma fatura (ou guia de remessa) de um fornecedor de um restaurante em Portugal, em foto ou PDF.${n > 1 ? " São várias páginas do mesmo documento." : ""}
Extrai os dados e responde apenas com um objeto JSON neste formato:
{"fornecedor":{"nome":"","nif":""},"numero":"","data":"AAAA-MM-DD","total_com_iva":0,"linhas":[{"descricao":"","codigo":"","quantidade":0,"unidade_fatura":"","preco_unitario":0,"total_linha":0,"unidades_por_embalagem":1,"unidade_base":"un","produto_id":null,"nome_sugerido":"","categoria":""}]}
Regras:
- Inclui todas as linhas de artigos. Ignora subtotais, resumos de IVA e totais.
- fornecedor é quem emite a fatura, não o cliente.
- preco_unitario: preço por unidade faturada, SEM IVA e já com descontos aplicados. Se só houver o total da linha, preco_unitario = total_linha / quantidade.
- unidades_por_embalagem: quantas unidades base tem cada unidade faturada. Exemplos: "Papel mãos CX 20" faturado à caixa → 20 e unidade_base "un"; salmão faturado ao KG → 1 e "kg"; "Arroz saco 20kg" faturado ao saco → 20 e "kg"; garrafa de 1,5 L → 1.5 e "L". Se não for claro, 1.
- unidade_base: apenas "un", "kg" ou "L".
- nome_sugerido: nome curto e genérico em português, sem marca, código ou tamanho (ex.: "Papel de mãos interfolhado", "Salmão fresco", "Arroz para sushi").
- categoria: uma de ${CATS.map((c) => '"' + c + '"').join(", ")}.
- produto_id: o id de um produto do catálogo abaixo se a linha for claramente o mesmo produto (mesmo com nome diferente); caso contrário null.
- Números com ponto decimal. Campo ilegível: null.
Catálogo (id | nome | unidade base | nomes usados pelos fornecedores):
${catalog || "(vazio)"}`;
}

// devolve {data, modelo} ou lança Error com código: ocupado | limite | ia_erro | ilegivel
async function extract(token: string, images: any[], gkey: string, models: string[]) {
  const t0 = Date.now();
  const cat = await rpc("compras_catalog", { p_token: token });
  const catalog = (cat?.products || []).map((p: any) => `${p.id} | ${p.nome} | ${p.unidade} | ${(p.offers || []).map((o: any) => o.alias).filter(Boolean).join(" ; ")}`).join("\n").slice(0, 30000);
  const parts: unknown[] = [{ text: buildPrompt(images.length, catalog) }];
  for (const im of images) parts.push({ inline_data: { mime_type: im.type, data: im.data } });
  const payload = JSON.stringify({ contents: [{ role: "user", parts }], generationConfig: { temperature: 0, responseMimeType: "application/json" } });
  let gj: any = null, lastStatus = 0, usedModel = "";
  outer: for (let round = 0; round < 2; round++) {
    for (const m of models) {
      const left = BUDGET_MS - (Date.now() - t0);
      if (left < 8000) break outer;
      const ctl = new AbortController();
      const timer = setTimeout(() => ctl.abort(), Math.min(CALL_MS, left - 3000));
      const ts = Date.now();
      try {
        const g = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(m)}:generateContent`, {
          method: "POST", headers: { "Content-Type": "application/json", "x-goog-api-key": gkey }, body: payload, signal: ctl.signal });
        const j = await g.json().catch(() => null);
        clearTimeout(timer);
        if (g.ok) { gj = j; usedModel = m; console.log(`gemini ${m} ok em ${Date.now() - ts} ms`); break outer; }
        lastStatus = g.status;
        console.log(`gemini ${m}: ${g.status} em ${Date.now() - ts} ms ${String(j?.error?.message || "").slice(0, 200)}`);
      } catch (_e) {
        clearTimeout(timer); lastStatus = 504;
        console.log(`gemini ${m}: sem resposta em ${Date.now() - ts} ms`);
      }
    }
    if (round === 0) await sleep(1500);
  }
  if (!gj) throw new Error(lastStatus === 429 ? "limite" : (lastStatus === 503 || lastStatus === 504) ? "ocupado" : "ia_erro");
  const text = (gj?.candidates?.[0]?.content?.parts || []).map((p: any) => p.text || "").join("");
  let data: any = null;
  try { data = JSON.parse(text); } catch { const mm = text.match(/\{[\s\S]*\}/); if (mm) { try { data = JSON.parse(mm[0]); } catch { data = null; } } }
  if (!data || !Array.isArray(data.linhas)) { console.log("ilegivel:", text.slice(0, 200)); throw new Error("ilegivel"); }
  console.log(`ok (${usedModel}): ${data.linhas.length} linhas, ${Date.now() - t0} ms`);
  return { data, modelo: usedModel };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "metodo" }, 405);
  const gkey = Deno.env.get("GEMINI_API_KEY");
  const models = [...new Set([Deno.env.get("GEMINI_MODEL") || "gemini-flash-lite-latest", Deno.env.get("GEMINI_MODEL_FALLBACK") || "gemini-flash-latest"])];
  try {
    const body = await req.json().catch(() => null);
    if (body?.check === true) {
      const out: Record<string, unknown> = { chave: !!gkey };
      if (gkey) for (const m of models) { const r = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(m)}`, { headers: { "x-goog-api-key": gkey } }); out[m] = r.ok; }
      return json(out);
    }
    const token = body?.token;
    const images = body?.images;
    if (!token || !Array.isArray(images) || images.length < 1 || images.length > 6) return json({ error: "pedido_invalido" }, 400);
    for (const im of images) if (!im?.data || typeof im.data !== "string" || !MIMES.includes(im.type)) return json({ error: "pedido_invalido" }, 400);
    let me;
    try { me = await rpc("compras_me", { p_token: token }); } catch (_e) { return json({ error: "sessao_invalida" }, 401); }
    if (me?.role !== "chefe") return json({ error: "sem_permissao" }, 403);
    if (!gkey) return json({ error: "sem_chave" }, 500);

    if (body?.mode === "fila") {
      const draftId = await rpc("compras_draft_new", { p_token: token, p_miniatura: typeof body.miniatura === "string" ? body.miniatura : "", p_paginas: images.length });
      const work = (async () => {
        try {
          const { data, modelo } = await extract(token, images, gkey, models);
          await rpc("compras_draft_finish", { p_token: token, p_id: draftId, p_status: "pronta", p_resultado: { ...data, _modelo: modelo }, p_erro: null });
        } catch (e) {
          const code = String((e as Error)?.message || "erro");
          console.log("fila erro:", code);
          await rpc("compras_draft_finish", { p_token: token, p_id: draftId, p_status: "erro", p_resultado: null, p_erro: ["ocupado", "limite", "ia_erro", "ilegivel"].includes(code) ? code : "erro" }).catch(() => {});
        }
      })();
      const er = (globalThis as any).EdgeRuntime;
      if (er?.waitUntil) er.waitUntil(work); else await work;
      return json({ ok: true, draft_id: draftId });
    }

    try {
      const { data, modelo } = await extract(token, images, gkey, models);
      return json({ ok: true, fatura: data, modelo });
    } catch (e) {
      const code = String((e as Error)?.message || "erro");
      return json({ error: code }, code === "ilegivel" ? 422 : 502);
    }
  } catch (e) {
    console.log("erro:", String(e).slice(0, 300));
    return json({ error: "erro", detalhe: String(e).slice(0, 200) }, 500);
  }
});
