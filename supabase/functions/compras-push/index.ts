// Envia notificações push (iPhone/Android com a app instalada no ecrã inicial).
// Autenticação própria: token de sessão da app de compras. As chaves de envio (VAPID) são geradas aqui
// na primeira utilização e ficam na tabela compras_push_cfg, só acessível com a chave de serviço.
// Eventos: "chave" (devolve a chave pública), "teste" (aviso ao próprio aparelho),
// "nova" (colaborador fez pedido -> chefes), "decisao" (chefe confirmou/rejeitou -> quem pediu).
import webpush from "npm:web-push@3.6.7";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (b: unknown, s = 200) => new Response(JSON.stringify(b), { status: s, headers: { ...CORS, "Content-Type": "application/json" } });
const URL_ = Deno.env.get("SUPABASE_URL")!;
const SRK = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const SUBJECT = "https://compras-focus.vercel.app";

async function rpc(fn: string, args: unknown) {
  const r = await fetch(`${URL_}/rest/v1/rpc/${fn}`, { method: "POST", headers: { apikey: SRK, Authorization: `Bearer ${SRK}`, "Content-Type": "application/json" }, body: JSON.stringify(args) });
  const t = await r.json().catch(() => null);
  if (!r.ok) throw new Error(t?.message || "rpc " + r.status);
  return t;
}

async function getKeys() {
  let cfg = await rpc("compras_push_cfg_get", {});
  if (!cfg) {
    const k = webpush.generateVAPIDKeys();
    await rpc("compras_push_cfg_set", { p_public: k.publicKey, p_private: k.privateKey });
    cfg = await rpc("compras_push_cfg_get", {}); // se duas chamadas correrem ao mesmo tempo, fica a primeira
  }
  return cfg as { vapid_public: string; vapid_private: string };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  try {
    const body = await req.json().catch(() => null);
    const token = body?.token, evento = body?.evento;
    if (!token || !["chave", "teste", "nova", "decisao"].includes(evento)) return json({ error: "pedido_invalido" }, 400);
    try { await rpc("compras_me", { p_token: token }); } catch (_e) { return json({ error: "sessao_invalida" }, 401); }
    const cfg = await getKeys();
    if (evento === "chave") return json({ chave: cfg.vapid_public });

    let t: any;
    try { t = await rpc("compras_push_targets", { p_token: token, p_evento: evento, p_order: body?.order_id ?? null }); }
    catch (e) { return json({ error: String((e as Error).message || "erro") }, 400); }
    const subs: any[] = t?.subs || [];
    if (!subs.length) return json({ enviadas: 0, sem_destinatarios: true });

    webpush.setVapidDetails(SUBJECT, cfg.vapid_public, cfg.vapid_private);
    const payload = JSON.stringify({ title: t.title, body: t.body, url: t.url, tag: t.tag });
    const mortos: string[] = []; let ok = 0;
    await Promise.all(subs.map(async (s) => {
      try {
        await webpush.sendNotification({ endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } }, payload, { TTL: 86400, urgency: "high" });
        ok++;
      } catch (e: any) {
        if (e?.statusCode === 404 || e?.statusCode === 410) mortos.push(s.endpoint);
        else console.log("push falhou", e?.statusCode, String(e?.body || e?.message || "").slice(0, 160));
      }
    }));
    if (mortos.length) await rpc("compras_push_prune", { p_endpoints: mortos }).catch(() => {});
    return json({ enviadas: ok, removidas: mortos.length });
  } catch (e) {
    console.log("erro", String((e as Error).message || e));
    return json({ error: "erro" }, 500);
  }
});
