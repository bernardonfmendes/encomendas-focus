-- Notificações push + motivo de rejeição (só objetos compras_*).
-- Colar tudo no Supabase > SQL Editor e carregar em "Run". Pode ser executado mais de uma vez.
-- As tabelas compras_push e compras_push_cfg e as colunas novas já estão criadas.

begin;

-- 1) Aparelhos com avisos ativados (a app chama estas duas com o token de sessão)
CREATE OR REPLACE FUNCTION public.compras_push_save(p_token text, p_sub jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare u public.compras_users; ep text; k1 text; k2 text;
begin
  u := public.compras__user(p_token);
  ep := p_sub->>'endpoint'; k1 := p_sub->'keys'->>'p256dh'; k2 := p_sub->'keys'->>'auth';
  if coalesce(ep,'') = '' or coalesce(k1,'') = '' or coalesce(k2,'') = '' then raise exception 'subscricao_invalida'; end if;
  insert into public.compras_push (user_id, endpoint, p256dh, auth) values (u.id, ep, k1, k2)
  on conflict (endpoint) do update set user_id = excluded.user_id, p256dh = excluded.p256dh, auth = excluded.auth;
end $function$;

CREATE OR REPLACE FUNCTION public.compras_push_delete(p_token text, p_endpoint text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare u public.compras_users;
begin
  u := public.compras__user(p_token);
  delete from public.compras_push where endpoint = p_endpoint and user_id = u.id;
end $function$;

-- 2) Funções só para a função do servidor (ficam fechadas à app no fim)
CREATE OR REPLACE FUNCTION public.compras_push_cfg_get()
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
  select to_jsonb(c) from public.compras_push_cfg c where id = 1
$function$;

CREATE OR REPLACE FUNCTION public.compras_push_cfg_set(p_public text, p_private text)
 RETURNS void
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
  insert into public.compras_push_cfg (id, vapid_public, vapid_private) values (1, p_public, p_private) on conflict (id) do nothing
$function$;

CREATE OR REPLACE FUNCTION public.compras_push_prune(p_endpoints text[])
 RETURNS void
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
  delete from public.compras_push where endpoint = any(p_endpoints)
$function$;

CREATE OR REPLACE FUNCTION public.compras_push_targets(p_token text, p_evento text, p_order uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare u public.compras_users; o public.compras_orders; subs jsonb; n int; v_sup text;
  vazio constant jsonb := jsonb_build_object('subs', '[]'::jsonb);
begin
  u := public.compras__user(p_token);
  if p_evento = 'teste' then
    select coalesce(jsonb_agg(jsonb_build_object('endpoint', p.endpoint, 'p256dh', p.p256dh, 'auth', p.auth)), '[]'::jsonb) into subs
      from public.compras_push p where p.user_id = u.id;
    return jsonb_build_object('subs', subs, 'title', 'Notificações ativadas', 'body', 'Vai receber avisos das encomendas neste aparelho.', 'url', '/#pedidos', 'tag', 'teste');
  elsif p_evento = 'nova' then
    if u.push_at is not null and u.push_at > now() - interval '30 seconds' then return vazio; end if;
    select count(*) into n from public.compras_orders where status = 'pendente';
    if n = 0 then return vazio; end if;
    update public.compras_users set push_at = now() where id = u.id;
    select coalesce(jsonb_agg(jsonb_build_object('endpoint', p.endpoint, 'p256dh', p.p256dh, 'auth', p.auth)), '[]'::jsonb) into subs
      from public.compras_push p join public.compras_users c on c.id = p.user_id
     where c.role = 'chefe' and c.ativo and c.id <> u.id;
    return jsonb_build_object('subs', subs, 'title', 'Nova encomenda por confirmar',
      'body', u.nome || ' fez um pedido · ' || n || ' por confirmar', 'url', '/#pedidos', 'tag', 'nova');
  elsif p_evento = 'decisao' then
    perform public.compras__chefe(p_token);
    select * into o from public.compras_orders where id = p_order;
    if not found or o.status not in ('aprovada','rejeitada') or o.approved_at is null or o.approved_at < now() - interval '15 minutes'
       or o.push_dec_at is not null or o.created_by is null or o.created_by = u.id then return vazio; end if;
    update public.compras_orders set push_dec_at = now() where id = o.id;
    select coalesce(s.nome, o.fornecedor_nome) into v_sup from public.compras_suppliers s where s.id = o.supplier_id;
    v_sup := coalesce(v_sup, o.fornecedor_nome, 'Fornecedor');
    select coalesce(jsonb_agg(jsonb_build_object('endpoint', p.endpoint, 'p256dh', p.p256dh, 'auth', p.auth)), '[]'::jsonb) into subs
      from public.compras_push p join public.compras_users c on c.id = p.user_id where c.id = o.created_by and c.ativo;
    if o.status = 'rejeitada' then
      return jsonb_build_object('subs', subs, 'title', 'Encomenda rejeitada · ' || v_sup, 'body', 'Motivo: ' || coalesce(nullif(o.motivo, ''), 'sem motivo indicado'), 'url', '/#pedidos', 'tag', 'dec-' || o.id);
    end if;
    return jsonb_build_object('subs', subs, 'title', 'Encomenda confirmada · ' || v_sup, 'body', 'O chefe confirmou o seu pedido.', 'url', '/#pedidos', 'tag', 'dec-' || o.id);
  end if;
  raise exception 'evento_invalido';
end $function$;

revoke execute on function public.compras_push_cfg_get(), public.compras_push_cfg_set(text, text), public.compras_push_prune(text[]), public.compras_push_targets(text, text, uuid) from public, anon, authenticated;
grant execute on function public.compras_push_cfg_get(), public.compras_push_cfg_set(text, text), public.compras_push_prune(text[]), public.compras_push_targets(text, text, uuid) to service_role;

-- 3) Rejeitar com motivo obrigatório (substitui a versão antiga)
drop function if exists public.compras_order_decide(text, uuid, text, jsonb, date);
CREATE OR REPLACE FUNCTION public.compras_order_decide(p_token text, p_id uuid, p_status text, p_items jsonb, p_entrega date, p_motivo text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare u public.compras_users;
begin
  u := public.compras__chefe(p_token);
  if p_status not in ('aprovada','rejeitada','enviada') then raise exception 'estado_invalido'; end if;
  if p_status = 'rejeitada' and length(trim(coalesce(p_motivo, ''))) < 3 then raise exception 'motivo_obrigatorio'; end if;
  update public.compras_orders set
    status = p_status,
    items = case when p_items is not null and jsonb_typeof(p_items) = 'array' then p_items else items end,
    entrega = case when p_status = 'enviada' then entrega else p_entrega end,
    approved_by = case when p_status in ('aprovada','rejeitada') then u.id else approved_by end,
    approved_at = case when p_status in ('aprovada','rejeitada') then now() else approved_at end,
    sent_at = case when p_status = 'enviada' then now() else sent_at end,
    motivo = case when p_status = 'rejeitada' then left(trim(p_motivo), 300) when p_status = 'aprovada' then '' else motivo end,
    push_dec_at = case when p_status in ('aprovada','rejeitada') then null else push_dec_at end
  where id = p_id;
end $function$;

-- 4) A lista de encomendas passa a trazer o motivo
CREATE OR REPLACE FUNCTION public.compras_orders(p_token text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare u public.compras_users;
begin
  u := public.compras__user(p_token);
  return jsonb_build_object(
    'pendentes', (select count(*) from public.compras_orders where status = 'pendente'),
    'orders', coalesce((select jsonb_agg(t.x order by t.ca desc) from (
       select o.created_at as ca, jsonb_build_object('id', o.id, 'supplier_id', o.supplier_id, 'fornecedor', coalesce(s.nome, o.fornecedor_nome),
         'telefone', case when u.role = 'chefe' then s.telefone else '' end,
         'minimo', s.minimo, 'via', s.via, 'items', o.items, 'nota', o.nota, 'status', o.status, 'entrega', o.entrega, 'motivo', o.motivo,
         'criado_por', cu.nome, 'meu', o.created_by = u.id, 'created_at', o.created_at,
         'aprovado_por', au.nome, 'approved_at', o.approved_at, 'sent_at', o.sent_at) as x
         from public.compras_orders o
         left join public.compras_suppliers s on s.id = o.supplier_id
         left join public.compras_users cu on cu.id = o.created_by
         left join public.compras_users au on au.id = o.approved_by
        where u.role = 'chefe' or o.created_by = u.id
        order by o.created_at desc limit 200) t), '[]'));
end $function$;

commit;

-- Verificação (deve devolver funcoes_push = 6 e decide_nova = 1). Correr à parte, se quiser:
-- select (select count(*) from pg_proc where proname like 'compras_push%') as funcoes_push,
--        (select count(*) from pg_proc where proname = 'compras_order_decide' and pronargs = 6) as decide_nova;
