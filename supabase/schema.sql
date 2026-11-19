-- Estrutura da app de compras (Supabase, projeto "financas"). Gerado a partir da base de dados em 11/11/2026.
-- Requer a extensão pgcrypto (schema "extensions").
-- Tabelas com RLS ativo e sem políticas: todo o acesso passa pelas funções SECURITY DEFINER abaixo,
-- que validam o token de sessão (compras__user / compras__chefe).

create sequence if not exists public.compras_price_history_id_seq;

create table public.compras_settings (
  id integer not null default 1,
  restaurante text not null default 'Focus Sushi'::text,
  constraint compras_settings_pkey PRIMARY KEY (id),
  constraint compras_settings_id_check CHECK ((id = 1))
);
alter table public.compras_settings enable row level security;

create table public.compras_users (
  id uuid not null default gen_random_uuid(),
  nome text not null,
  pin_hash text not null,
  role text not null,
  ativo boolean not null default true,
  failed integer not null default 0,
  locked_until timestamp with time zone,
  created_at timestamp with time zone not null default now(),
  setor text,
  push_at timestamp with time zone,
  constraint compras_users_pkey PRIMARY KEY (id),
  constraint compras_users_role_check CHECK ((role = ANY (ARRAY['chefe'::text, 'colaborador'::text]))),
  constraint compras_users_setor_check CHECK ((setor = ANY (ARRAY['cozinha'::text, 'sushi'::text, 'bar'::text, 'takeaway'::text])))
);
alter table public.compras_users enable row level security;

create table public.compras_sessions (
  token_hash text not null,
  user_id uuid not null,
  expires_at timestamp with time zone not null,
  constraint compras_sessions_pkey PRIMARY KEY (token_hash),
  constraint compras_sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES compras_users(id) ON DELETE CASCADE
);
alter table public.compras_sessions enable row level security;

create table public.compras_suppliers (
  id uuid not null default gen_random_uuid(),
  nome text not null,
  nif text not null default ''::text,
  telefone text not null default ''::text,
  dias text not null default ''::text,
  created_at timestamp with time zone not null default now(),
  minimo numeric,
  via text not null default 'numero'::text,
  constraint compras_suppliers_pkey PRIMARY KEY (id),
  constraint compras_suppliers_minimo_check CHECK (((minimo IS NULL) OR (minimo > (0)::numeric))),
  constraint compras_suppliers_via_check CHECK ((via = ANY (ARRAY['numero'::text, 'grupo'::text])))
);
alter table public.compras_suppliers enable row level security;

create table public.compras_products (
  id uuid not null default gen_random_uuid(),
  nome text not null,
  categoria text not null default 'Outros'::text,
  unidade text not null default 'un'::text,
  created_at timestamp with time zone not null default now(),
  setores text[] not null default '{}'::text[],
  constraint compras_products_pkey PRIMARY KEY (id),
  constraint compras_products_unidade_check CHECK ((unidade = ANY (ARRAY['un'::text, 'kg'::text, 'L'::text])))
);
alter table public.compras_products enable row level security;

create table public.compras_invoices (
  id uuid not null default gen_random_uuid(),
  supplier_id uuid,
  fornecedor_nome text,
  numero text,
  data date,
  total numeric,
  linhas jsonb not null default '[]'::jsonb,
  created_by uuid,
  created_at timestamp with time zone not null default now(),
  constraint compras_invoices_pkey PRIMARY KEY (id),
  constraint compras_invoices_created_by_fkey FOREIGN KEY (created_by) REFERENCES compras_users(id) ON DELETE SET NULL,
  constraint compras_invoices_supplier_id_fkey FOREIGN KEY (supplier_id) REFERENCES compras_suppliers(id) ON DELETE SET NULL
);
alter table public.compras_invoices enable row level security;

create table public.compras_offers (
  product_id uuid not null,
  supplier_id uuid not null,
  alias text not null default ''::text,
  codigo text not null default ''::text,
  pack_qty numeric not null default 1,
  pack_price numeric not null,
  unit_price numeric not null,
  prev_unit_price numeric,
  data date,
  invoice_id uuid,
  constraint compras_offers_pkey PRIMARY KEY (product_id, supplier_id),
  constraint compras_offers_invoice_id_fkey FOREIGN KEY (invoice_id) REFERENCES compras_invoices(id) ON DELETE SET NULL,
  constraint compras_offers_product_id_fkey FOREIGN KEY (product_id) REFERENCES compras_products(id) ON DELETE CASCADE,
  constraint compras_offers_supplier_id_fkey FOREIGN KEY (supplier_id) REFERENCES compras_suppliers(id) ON DELETE CASCADE
);
alter table public.compras_offers enable row level security;

create table public.compras_price_history (
  id bigint not null default nextval('compras_price_history_id_seq'::regclass),
  product_id uuid not null,
  supplier_id uuid not null,
  data date,
  unit_price numeric not null,
  invoice_id uuid,
  constraint compras_price_history_pkey PRIMARY KEY (id),
  constraint compras_price_history_invoice_id_fkey FOREIGN KEY (invoice_id) REFERENCES compras_invoices(id) ON DELETE CASCADE,
  constraint compras_price_history_product_id_fkey FOREIGN KEY (product_id) REFERENCES compras_products(id) ON DELETE CASCADE,
  constraint compras_price_history_supplier_id_fkey FOREIGN KEY (supplier_id) REFERENCES compras_suppliers(id) ON DELETE CASCADE
);
alter table public.compras_price_history enable row level security;

create table public.compras_orders (
  id uuid not null default gen_random_uuid(),
  supplier_id uuid,
  fornecedor_nome text not null default ''::text,
  items jsonb not null,
  nota text not null default ''::text,
  status text not null default 'pendente'::text,
  entrega date,
  created_by uuid,
  created_at timestamp with time zone not null default now(),
  approved_by uuid,
  approved_at timestamp with time zone,
  sent_at timestamp with time zone,
  motivo text not null default ''::text,
  push_dec_at timestamp with time zone,
  constraint compras_orders_pkey PRIMARY KEY (id),
  constraint compras_orders_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES compras_users(id) ON DELETE SET NULL,
  constraint compras_orders_created_by_fkey FOREIGN KEY (created_by) REFERENCES compras_users(id) ON DELETE SET NULL,
  constraint compras_orders_supplier_id_fkey FOREIGN KEY (supplier_id) REFERENCES compras_suppliers(id) ON DELETE SET NULL,
  constraint compras_orders_status_check CHECK ((status = ANY (ARRAY['pendente'::text, 'aprovada'::text, 'rejeitada'::text, 'enviada'::text])))
);
alter table public.compras_orders enable row level security;

create table public.compras_push (
  id uuid not null default gen_random_uuid(),
  user_id uuid not null,
  endpoint text not null,
  p256dh text not null,
  auth text not null,
  created_at timestamp with time zone not null default now(),
  constraint compras_push_pkey PRIMARY KEY (id),
  constraint compras_push_endpoint_key UNIQUE (endpoint),
  constraint compras_push_user_id_fkey FOREIGN KEY (user_id) REFERENCES compras_users(id) ON DELETE CASCADE
);
alter table public.compras_push enable row level security;

-- Chaves de envio das notificações (geradas pela função compras-push; só acessíveis com a chave de serviço)
create table public.compras_push_cfg (
  id integer not null default 1,
  vapid_public text not null,
  vapid_private text not null,
  created_at timestamp with time zone not null default now(),
  constraint compras_push_cfg_pkey PRIMARY KEY (id),
  constraint compras_push_cfg_id_check CHECK (id = 1)
);
alter table public.compras_push_cfg enable row level security;

create table public.compras_invoice_drafts (
  id uuid not null default gen_random_uuid(),
  status text not null default 'a_ler'::text,
  resultado jsonb,
  erro text,
  miniatura text,
  paginas integer not null default 1,
  created_by uuid,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint compras_invoice_drafts_pkey PRIMARY KEY (id),
  constraint compras_invoice_drafts_created_by_fkey FOREIGN KEY (created_by) REFERENCES compras_users(id) ON DELETE SET NULL,
  constraint compras_invoice_drafts_status_check CHECK ((status = ANY (ARRAY['a_ler'::text, 'pronta'::text, 'erro'::text])))
);
alter table public.compras_invoice_drafts enable row level security;

CREATE INDEX compras_orders_created_idx ON public.compras_orders USING btree (created_at DESC);
CREATE UNIQUE INDEX compras_users_nome_uq ON public.compras_users USING btree (lower(nome));

CREATE OR REPLACE FUNCTION public.compras__chefe(p_token text)
 RETURNS compras_users
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare u public.compras_users;
begin
  u := public.compras__user(p_token);
  if u.role <> 'chefe' then raise exception 'sem_permissao'; end if;
  return u;
end $function$
;
CREATE OR REPLACE FUNCTION public.compras__setores(p text[])
 RETURNS text[]
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  select coalesce(array(select distinct x from unnest(coalesce(p,'{}')) x where x in ('cozinha','sushi','bar','takeaway') order by x), '{}')
$function$
;
CREATE OR REPLACE FUNCTION public.compras__user(p_token text)
 RETURNS compras_users
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare u public.compras_users;
begin
  select usr.* into u from public.compras_sessions s join public.compras_users usr on usr.id = s.user_id
   where s.token_hash = encode(extensions.digest(coalesce(p_token,''), 'sha256'), 'hex') and s.expires_at > now() and usr.ativo;
  if not found then raise exception 'sessao_invalida'; end if;
  return u;
end $function$
;
CREATE OR REPLACE FUNCTION public.compras_cancel_order(p_token text, p_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare u public.compras_users;
begin
  u := public.compras__user(p_token);
  delete from public.compras_orders where id = p_id and (u.role = 'chefe' or (created_by = u.id and status = 'pendente'));
end $function$
;
CREATE OR REPLACE FUNCTION public.compras_catalog(p_token text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare u public.compras_users;
begin
  u := public.compras__user(p_token);
  return jsonb_build_object(
    'restaurante', (select restaurante from public.compras_settings where id = 1),
    'suppliers', coalesce((select jsonb_agg(jsonb_build_object('id', s.id, 'nome', s.nome, 'telefone', s.telefone, 'dias', s.dias, 'nif', s.nif, 'minimo', s.minimo, 'via', s.via) order by lower(s.nome)) from public.compras_suppliers s), '[]'),
    'products', coalesce((select jsonb_agg(jsonb_build_object(
        'id', p.id, 'nome', p.nome, 'categoria', p.categoria, 'unidade', p.unidade, 'setores', to_jsonb(p.setores),
        'offers', coalesce((select jsonb_agg(jsonb_build_object('supplier_id', o.supplier_id, 'alias', o.alias, 'codigo', o.codigo,
             'pack_qty', o.pack_qty, 'pack_price', o.pack_price, 'unit_price', o.unit_price, 'prev_unit_price', o.prev_unit_price, 'prev_data', o.prev_data, 'data', o.data)
             order by o.unit_price) from public.compras_offers o where o.product_id = p.id), '[]')
      ) order by lower(p.nome)) from public.compras_products p), '[]')
  );
end $function$
;
CREATE OR REPLACE FUNCTION public.compras_change_pin(p_token text, p_old text, p_new text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare u public.compras_users;
begin
  u := public.compras__user(p_token);
  if u.pin_hash <> extensions.crypt(coalesce(p_old,''), u.pin_hash) then raise exception 'pin_errado'; end if;
  if coalesce(p_new,'') !~ '^\d{6}$' then raise exception 'pin_formato'; end if;
  update public.compras_users set pin_hash = extensions.crypt(p_new, extensions.gen_salt('bf')) where id = u.id;
end $function$
;
CREATE OR REPLACE FUNCTION public.compras_delete_product(p_token text, p_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare u public.compras_users;
begin
  u := public.compras__chefe(p_token);
  delete from public.compras_products where id = p_id;
end $function$
;
CREATE OR REPLACE FUNCTION public.compras_draft_delete(p_token text, p_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare u public.compras_users;
begin
  u := public.compras__chefe(p_token);
  delete from public.compras_invoice_drafts where id = p_id;
end $function$
;
CREATE OR REPLACE FUNCTION public.compras_draft_finish(p_token text, p_id uuid, p_status text, p_resultado jsonb, p_erro text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare u public.compras_users;
begin
  u := public.compras__chefe(p_token);
  if p_status not in ('pronta','erro') then raise exception 'estado_invalido'; end if;
  update public.compras_invoice_drafts set status = p_status, resultado = p_resultado, erro = p_erro, updated_at = now() where id = p_id;
end $function$
;
CREATE OR REPLACE FUNCTION public.compras_draft_new(p_token text, p_miniatura text, p_paginas integer)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare u public.compras_users; rid uuid;
begin
  u := public.compras__chefe(p_token);
  insert into public.compras_invoice_drafts (miniatura, paginas, created_by)
  values (left(coalesce(p_miniatura,''), 60000), coalesce(p_paginas,1), u.id) returning id into rid;
  return rid;
end $function$
;
CREATE OR REPLACE FUNCTION public.compras_drafts_list(p_token text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare u public.compras_users;
begin
  u := public.compras__chefe(p_token);
  delete from public.compras_invoice_drafts where created_at < now() - interval '14 days';
  update public.compras_invoice_drafts set status = 'erro', erro = 'tempo', updated_at = now()
   where status = 'a_ler' and created_at < now() - interval '4 minutes';
  return coalesce((select jsonb_agg(jsonb_build_object('id', d.id, 'status', d.status, 'resultado', d.resultado, 'erro', d.erro,
      'miniatura', d.miniatura, 'paginas', d.paginas, 'created_at', d.created_at, 'criado_por', cu.nome) order by d.created_at desc)
    from public.compras_invoice_drafts d left join public.compras_users cu on cu.id = d.created_by), '[]');
end $function$
;
CREATE OR REPLACE FUNCTION public.compras_import_invoice(p_token text, p_inv jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare u public.compras_users; sid uuid; nome text; nk text; numk text;
begin
  u := public.compras__chefe(p_token);
  nome := trim(coalesce(p_inv->>'fornecedor_nome',''));
  nk := lower(regexp_replace(nome, '[^A-Za-z0-9]', '', 'g'));
  numk := lower(regexp_replace(coalesce(p_inv->>'numero',''), '\s', '', 'g'));
  if nk = '' or numk = '' then return jsonb_build_object('ignorada', 'sem_dados'); end if;
  select s.id into sid from public.compras_suppliers s
   where lower(regexp_replace(s.nome, '[^A-Za-z0-9]', '', 'g')) = nk
      or (length(nk) >= 4 and lower(regexp_replace(s.nome, '[^A-Za-z0-9]', '', 'g')) like nk || '%')
      or (length(lower(regexp_replace(s.nome, '[^A-Za-z0-9]', '', 'g'))) >= 4 and nk like lower(regexp_replace(s.nome, '[^A-Za-z0-9]', '', 'g')) || '%')
   order by s.created_at limit 1;
  if sid is not null and exists (select 1 from public.compras_invoices i where i.supplier_id = sid and lower(regexp_replace(coalesce(i.numero,''), '\s', '', 'g')) = numk) then
    return jsonb_build_object('ignorada', 'repetida');
  end if;
  if sid is null then
    insert into public.compras_suppliers (nome) values (nome) returning id into sid;
  end if;
  return public.compras_save_invoice(p_token, p_inv || jsonb_build_object('supplier_id', sid));
end $function$
;
CREATE OR REPLACE FUNCTION public.compras_invoices_list(p_token text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare u public.compras_users;
begin
  u := public.compras__chefe(p_token);
  return coalesce((select jsonb_agg(jsonb_build_object('id', i.id, 'fornecedor', coalesce(s.nome, i.fornecedor_nome), 'numero', i.numero,
     'data', i.data, 'total', i.total, 'linhas', jsonb_array_length(i.linhas)) order by i.created_at desc)
     from (select * from public.compras_invoices order by created_at desc limit 30) i left join public.compras_suppliers s on s.id = i.supplier_id), '[]');
end $function$
;
CREATE OR REPLACE FUNCTION public.compras_login(p_nome text, p_pin text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare u public.compras_users; t text; nf int;
begin
  select * into u from public.compras_users where lower(nome) = lower(trim(coalesce(p_nome,''))) and ativo;
  if not found then
    perform pg_sleep(0.4);
    return jsonb_build_object('error','login_invalido');
  end if;
  if u.locked_until is not null and u.locked_until > now() then
    return jsonb_build_object('error','bloqueado');
  end if;
  if u.pin_hash <> extensions.crypt(coalesce(p_pin,''), u.pin_hash) then
    nf := case when u.locked_until is not null and u.locked_until <= now() then 1 else u.failed + 1 end;
    update public.compras_users set failed = nf,
           locked_until = case when nf >= 5 then now() + interval '15 minutes' else null end
     where id = u.id;
    perform pg_sleep(0.4);
    return jsonb_build_object('error', case when nf >= 5 then 'bloqueado' else 'login_invalido' end);
  end if;
  update public.compras_users set failed = 0, locked_until = null where id = u.id;
  delete from public.compras_sessions where expires_at < now();
  t := encode(extensions.gen_random_bytes(32), 'hex');
  insert into public.compras_sessions values (encode(extensions.digest(t, 'sha256'), 'hex'), u.id, now() + interval '60 days');
  return jsonb_build_object('token', t, 'nome', u.nome, 'role', u.role);
end $function$
;
CREATE OR REPLACE FUNCTION public.compras_logout(p_token text)
 RETURNS void
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
  delete from public.compras_sessions where token_hash = encode(extensions.digest(coalesce(p_token,''), 'sha256'), 'hex');
$function$
;
CREATE OR REPLACE FUNCTION public.compras_me(p_token text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare u public.compras_users;
begin
  u := public.compras__user(p_token);
  return jsonb_build_object('id', u.id, 'nome', u.nome, 'role', u.role, 'setor', u.setor,
    'restaurante', (select restaurante from public.compras_settings where id = 1));
end $function$
;
CREATE OR REPLACE FUNCTION public.compras_merge_products(p_token text, p_from uuid, p_into uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare u public.compras_users; o public.compras_offers; cur public.compras_offers; fs text[];
begin
  u := public.compras__chefe(p_token);
  if p_from = p_into then return; end if;
  select setores into fs from public.compras_products where id = p_from;
  update public.compras_products set setores = case when cardinality(setores) = 0 or cardinality(coalesce(fs,'{}')) = 0 then '{}' else public.compras__setores(setores || fs) end where id = p_into;
  for o in select * from public.compras_offers where product_id = p_from loop
    select * into cur from public.compras_offers where product_id = p_into and supplier_id = o.supplier_id;
    if not found then
      insert into public.compras_offers (product_id, supplier_id, alias, codigo, pack_qty, pack_price, unit_price, prev_unit_price, data, invoice_id)
      values (p_into, o.supplier_id, o.alias, o.codigo, o.pack_qty, o.pack_price, o.unit_price, o.prev_unit_price, o.data, o.invoice_id);
    elsif coalesce(o.data, '1900-01-01'::date) > coalesce(cur.data, '1900-01-01'::date) then
      update public.compras_offers set alias = o.alias, codigo = o.codigo, pack_qty = o.pack_qty, pack_price = o.pack_price, unit_price = o.unit_price,
        prev_unit_price = cur.unit_price, data = o.data, invoice_id = o.invoice_id where product_id = p_into and supplier_id = o.supplier_id;
    end if;
  end loop;
  update public.compras_price_history set product_id = p_into where product_id = p_from;
  update public.compras_purchase_lines set product_id = p_into where product_id = p_from;
  update public.compras_recipe_items set product_id = p_into where product_id = p_from;
  update public.compras_recipe_aliases set product_id = p_into where product_id = p_from;
  update public.compras_zs_items set product_id = p_into where product_id = p_from;
  insert into public.compras_stock_count_lines (count_id, product_id, setor, qty, updated_by, updated_at)
    select count_id, p_into, setor, qty, updated_by, updated_at from public.compras_stock_count_lines where product_id = p_from
    on conflict (count_id, product_id, setor) do update set qty = public.compras_stock_count_lines.qty + excluded.qty;
  delete from public.compras_products where id = p_from;
end $function$
;
CREATE OR REPLACE FUNCTION public.compras_offer_delete(p_token text, p_product uuid, p_supplier uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare u public.compras_users;
begin
  u := public.compras__chefe(p_token);
  delete from public.compras_offers where product_id = p_product and supplier_id = p_supplier;
end $function$
;
CREATE OR REPLACE FUNCTION public.compras_offer_save(p_token text, p_product uuid, p_supplier uuid, p_alias text, p_codigo text, p_pack_qty numeric, p_pack_price numeric)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare u public.compras_users; prev public.compras_offers; q numeric; up numeric;
begin
  u := public.compras__chefe(p_token);
  q := case when coalesce(p_pack_qty, 0) > 0 then p_pack_qty else 1 end;
  if p_pack_price is null or p_pack_price < 0 then raise exception 'preco_invalido'; end if;
  up := p_pack_price / q;
  select * into prev from public.compras_offers where product_id = p_product and supplier_id = p_supplier;
  if not found then
    insert into public.compras_offers (product_id, supplier_id, alias, codigo, pack_qty, pack_price, unit_price, prev_unit_price, data)
    values (p_product, p_supplier, coalesce(trim(p_alias),''), coalesce(trim(p_codigo),''), q, p_pack_price, up, null, current_date);
    insert into public.compras_price_history (product_id, supplier_id, data, unit_price) values (p_product, p_supplier, current_date, up);
  else
    update public.compras_offers set alias = coalesce(trim(p_alias),''), codigo = coalesce(trim(p_codigo),''), pack_qty = q, pack_price = p_pack_price,
      unit_price = up,
      prev_unit_price = case when abs(prev.unit_price - up) > 0.00001 then prev.unit_price else prev.prev_unit_price end,
      data = case when abs(prev.unit_price - up) > 0.00001 then current_date else prev.data end
    where product_id = p_product and supplier_id = p_supplier;
    if abs(prev.unit_price - up) > 0.00001 then
      insert into public.compras_price_history (product_id, supplier_id, data, unit_price) values (p_product, p_supplier, current_date, up);
    end if;
  end if;
end $function$
;
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
end $function$
;
CREATE OR REPLACE FUNCTION public.compras_order_items(p_token text, p_id uuid, p_items jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare u public.compras_users;
begin
  u := public.compras__chefe(p_token);
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then raise exception 'carrinho_vazio'; end if;
  update public.compras_orders set items = p_items where id = p_id and status in ('pendente','aprovada');
end $function$
;
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
end $function$
;
CREATE OR REPLACE FUNCTION public.compras_product_create(p_token text, p_nome text, p_categoria text, p_unidade text, p_setores text[] DEFAULT NULL::text[])
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare u public.compras_users; rid uuid;
begin
  u := public.compras__chefe(p_token);
  if coalesce(trim(p_nome),'') = '' then raise exception 'nome_obrigatorio'; end if;
  select id into rid from public.compras_products where lower(nome) = lower(trim(p_nome)) limit 1;
  if rid is null then
    insert into public.compras_products (nome, categoria, unidade, setores)
    values (trim(p_nome), coalesce(nullif(p_categoria,''),'Outros'), case when p_unidade in ('un','kg','L') then p_unidade else 'un' end, public.compras__setores(p_setores))
    returning id into rid;
  end if;
  return rid;
end $function$
;
CREATE OR REPLACE FUNCTION public.compras_save_invoice(p_token text, p_inv jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare
  u public.compras_users; sid uuid; inv uuid := gen_random_uuid(); l jsonb; pid uuid; k text;
  up numeric; pq numeric; pp numeric; prev public.compras_offers; n int := 0; newmap jsonb := '{}'; d date; v_nif text;
  known_pid uuid; known_pq numeric; is_nc boolean; v_total numeric;
begin
  u := public.compras__chefe(p_token);
  d := coalesce(nullif(p_inv->>'data','')::date, current_date);
  v_nif := regexp_replace(coalesce(p_inv->>'nif',''), '\D', '', 'g');
  v_total := nullif(p_inv->>'total','')::numeric;
  -- nota de crédito: total negativo ou número começado por NC
  is_nc := coalesce(v_total, 0) < 0 or coalesce(p_inv->>'numero','') ~* '^\s*NC';
  sid := nullif(p_inv->>'supplier_id','')::uuid;
  if sid is null and v_nif <> '' then
    select s.id into sid from public.compras_suppliers s where s.nif = v_nif limit 1;
  end if;
  if sid is null then
    insert into public.compras_suppliers (nome, nif) values (coalesce(nullif(trim(p_inv->>'fornecedor_nome'),''), 'Fornecedor'), v_nif) returning id into sid;
  elsif v_nif <> '' then
    update public.compras_suppliers s set nif = v_nif where s.id = sid and s.nif = '';
  end if;
  insert into public.compras_invoices (id, supplier_id, fornecedor_nome, numero, data, total, linhas, created_by)
  values (inv, sid, (select s.nome from public.compras_suppliers s where s.id = sid), coalesce(p_inv->>'numero',''), d,
          v_total, coalesce(p_inv->'linhas','[]'::jsonb), u.id);
  for l in select * from jsonb_array_elements(coalesce(p_inv->'linhas','[]'::jsonb)) loop
    pp := nullif(l->>'price','')::numeric;
    pq := coalesce(nullif(l->>'pack_qty','')::numeric, 1);
    if pq <= 0 then pq := 1; end if;
    if pp is null or pp < 0 then continue; end if;
    -- vasilhame / caução não é produto (ex.: "Barril Damm 50L Vas")
    if coalesce(l->>'desc','') ~* '(vasilhame|cau[cç][aã]o)' or coalesce(l->>'desc','') ~* '(^|[^[:alnum:]])(vas|grade)([^[:alnum:]]|$)' then continue; end if;
    pid := nullif(l->>'product_id','')::uuid;
    -- artigo já conhecido neste fornecedor (pela descrição da fatura): usa sempre o mesmo produto e a mesma embalagem.
    -- Se o produto vier escolhido à mão (revisão na app), vale o que o chefe escolheu.
    known_pid := null; known_pq := null;
    if coalesce(l->>'desc','') <> '' then
      select o.product_id, o.pack_qty into known_pid, known_pq from public.compras_offers o
       where o.supplier_id = sid and lower(o.alias) = lower(l->>'desc') limit 1;
    end if;
    if pid is null and known_pid is not null then
      pid := known_pid;
      if known_pq > 0 then pq := known_pq; end if;
    end if;
    up := pp / pq;
    if pid is null then
      k := lower(trim(coalesce(l->>'novo_nome','')));
      if k = '' then continue; end if;
      if newmap ? k then pid := (newmap->>k)::uuid;
      else
        select p.id into pid from public.compras_products p where lower(p.nome) = k limit 1;
        if pid is null then
          insert into public.compras_products (nome, categoria, unidade)
          values (trim(l->>'novo_nome'), coalesce(nullif(l->>'categoria',''),'Outros'),
                  case when l->>'base_unit' in ('un','kg','L') then l->>'base_unit' else 'un' end)
          returning id into pid;
        end if;
        newmap := newmap || jsonb_build_object(k, pid);
      end if;
    end if;
    -- nota de crédito: tira stock e não conta como preço de compra
    if is_nc then
      if nullif(l->>'qty','') is not null then
        insert into public.compras_purchase_lines (invoice_id, product_id, data, qty) values (inv, pid, d, -abs((l->>'qty')::numeric * pq));
      end if;
      n := n + 1;
      continue;
    end if;
    insert into public.compras_price_history (product_id, supplier_id, data, unit_price, invoice_id) values (pid, sid, d, up, inv);
    if nullif(l->>'qty','') is not null then
      insert into public.compras_purchase_lines (invoice_id, product_id, data, qty) values (inv, pid, d, (l->>'qty')::numeric * pq);
    end if;
    select * into prev from public.compras_offers o where o.product_id = pid and o.supplier_id = sid;
    if not found then
      insert into public.compras_offers (product_id, supplier_id, alias, codigo, pack_qty, pack_price, unit_price, prev_unit_price, data, invoice_id)
      values (pid, sid, coalesce(l->>'desc',''), coalesce(l->>'codigo',''), pq, pp, up, null, d, inv);
    elsif prev.data is null or d >= prev.data then
      update public.compras_offers o set alias = coalesce(l->>'desc',''), codigo = coalesce(l->>'codigo',''), pack_qty = pq, pack_price = pp,
        unit_price = up, prev_unit_price = case when prev.invoice_id = inv then prev.prev_unit_price when lower(coalesce(prev.alias,'')) <> lower(coalesce(l->>'desc','')) then null when up > 0 and prev.unit_price > 0 and (up / prev.unit_price >= 2.5 or up / prev.unit_price <= 0.4) then null else prev.unit_price end, prev_data = case when prev.invoice_id = inv then prev.prev_data when lower(coalesce(prev.alias,'')) <> lower(coalesce(l->>'desc','')) then null else prev.data end, data = d, invoice_id = inv
       where o.product_id = pid and o.supplier_id = sid;
    end if;
    n := n + 1;
  end loop;
  return jsonb_build_object('invoice_id', inv, 'supplier_id', sid, 'linhas', n, 'nota_credito', is_nc);
end $function$
;
CREATE OR REPLACE FUNCTION public.compras_save_product(p_token text, p_id uuid, p_nome text, p_categoria text, p_unidade text, p_setores text[] DEFAULT NULL::text[])
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare u public.compras_users;
begin
  u := public.compras__chefe(p_token);
  if coalesce(trim(p_nome),'') = '' then raise exception 'nome_obrigatorio'; end if;
  update public.compras_products set nome = trim(p_nome), categoria = coalesce(nullif(p_categoria,''),'Outros'),
    unidade = case when p_unidade in ('un','kg','L') then p_unidade else unidade end,
    setores = case when p_setores is null then setores else public.compras__setores(p_setores) end
  where id = p_id;
end $function$
;
CREATE OR REPLACE FUNCTION public.compras_save_supplier(p_token text, p_id uuid, p_nome text, p_telefone text, p_dias text, p_nif text, p_minimo numeric DEFAULT NULL::numeric, p_via text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare u public.compras_users; rid uuid; v_via text := case when p_via in ('numero','grupo') then p_via end;
begin
  u := public.compras__chefe(p_token);
  if coalesce(trim(p_nome),'') = '' then raise exception 'nome_obrigatorio'; end if;
  if p_minimo is not null and p_minimo < 0 then raise exception 'preco_invalido'; end if;
  -- p_minimo / p_via: null = não mexer; p_minimo 0 = sem mínimo
  if p_id is null then
    insert into public.compras_suppliers (nome, telefone, dias, nif, minimo, via) values (trim(p_nome), coalesce(trim(p_telefone),''), coalesce(trim(p_dias),''), regexp_replace(coalesce(p_nif,''),'\D','','g'), nullif(p_minimo, 0), coalesce(v_via, 'numero')) returning id into rid;
  else
    update public.compras_suppliers set nome = trim(p_nome), telefone = coalesce(trim(p_telefone),''), dias = coalesce(trim(p_dias),''), nif = regexp_replace(coalesce(p_nif,''),'\D','','g'),
      minimo = case when p_minimo is null then minimo else nullif(p_minimo, 0) end,
      via = coalesce(v_via, via)
    where id = p_id returning id into rid;
  end if;
  return rid;
end $function$
;
CREATE OR REPLACE FUNCTION public.compras_set_settings(p_token text, p_restaurante text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare u public.compras_users;
begin
  u := public.compras__chefe(p_token);
  update public.compras_settings set restaurante = coalesce(nullif(trim(p_restaurante),''), restaurante) where id = 1;
end $function$
;
CREATE OR REPLACE FUNCTION public.compras_submit_order(p_token text, p_items jsonb, p_nota text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare u public.compras_users; r record; n int := 0; j int := 0; ex public.compras_orders; merged jsonb; it jsonb; idx int; found_i boolean;
begin
  u := public.compras__user(p_token);
  -- aprende: se um produto marcado com sítios for pedido para outro sítio, acrescenta esse sítio
  update public.compras_products p set setores = public.compras__setores(p.setores || array[i->>'setor'])
    from jsonb_array_elements(coalesce(p_items,'[]')) i
   where p.id = (i->>'product_id')::uuid and cardinality(p.setores) > 0
     and (i->>'setor') in ('cozinha','sushi','bar','takeaway') and not ((i->>'setor') = any(p.setores));
  for r in
    select o.supplier_id, sup.nome as sup_nome,
           jsonb_agg(jsonb_build_object('product_id', p.id, 'nome', p.nome, 'alias', o.alias, 'codigo', o.codigo,
             'qty', x.qty, 'pack_qty', o.pack_qty, 'pack_price', o.pack_price, 'base_unit', p.unidade, 'setor', x.setor) order by p.nome, x.setor) as items
      from (select (i->>'product_id')::uuid pid, (i->>'supplier_id')::uuid sid,
                   case when (i->>'setor') in ('cozinha','sushi','bar','takeaway') then i->>'setor' else u.setor end setor,
                   sum((i->>'qty')::numeric) qty
              from jsonb_array_elements(coalesce(p_items,'[]')) i where (i->>'qty')::numeric > 0 group by 1,2,3) x
      join public.compras_offers o on o.product_id = x.pid and o.supplier_id = x.sid
      join public.compras_products p on p.id = o.product_id
      join public.compras_suppliers sup on sup.id = o.supplier_id
     group by o.supplier_id, sup.nome
  loop
    select * into ex from public.compras_orders
     where supplier_id = r.supplier_id and status in ('pendente','aprovada')
       
     order by created_at desc limit 1;
    if found then
      merged := ex.items;
      for it in select * from jsonb_array_elements(r.items) loop
        found_i := false;
        for idx in 0 .. jsonb_array_length(merged) - 1 loop
          if merged->idx->>'product_id' = it->>'product_id' and coalesce(merged->idx->>'setor','') = coalesce(it->>'setor','') then
            merged := jsonb_set(merged, array[idx::text, 'qty'], to_jsonb((merged->idx->>'qty')::numeric + (it->>'qty')::numeric));
            found_i := true; exit;
          end if;
        end loop;
        if not found_i then merged := merged || jsonb_build_array(it); end if;
      end loop;
      update public.compras_orders set items = merged,
        nota = case when coalesce(p_nota,'') = '' then nota when nota = '' then left(p_nota, 500) else left(nota || ' / ' || p_nota, 500) end,
        status = case when u.role = 'chefe' then 'aprovada' else 'pendente' end,
        approved_by = case when u.role = 'chefe' then u.id else null end,
        approved_at = case when u.role = 'chefe' then now() else null end
      where id = ex.id;
      j := j + 1;
    else
      insert into public.compras_orders (supplier_id, fornecedor_nome, items, nota, status, created_by, approved_by, approved_at)
      values (r.supplier_id, r.sup_nome, r.items, left(coalesce(p_nota,''), 500),
              case when u.role = 'chefe' then 'aprovada' else 'pendente' end, u.id,
              case when u.role = 'chefe' then u.id end, case when u.role = 'chefe' then now() end);
      n := n + 1;
    end if;
  end loop;
  if n + j = 0 then raise exception 'carrinho_vazio'; end if;
  return jsonb_build_object('encomendas', n, 'juntadas', j, 'aprovadas', u.role = 'chefe');
end $function$
;
CREATE OR REPLACE FUNCTION public.compras_user_save(p_token text, p_id uuid, p_nome text, p_role text, p_ativo boolean, p_pin text, p_setor text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare u public.compras_users; rid uuid; v_setor text := case when p_setor in ('cozinha','sushi','bar','takeaway') then p_setor end;
begin
  u := public.compras__chefe(p_token);
  if coalesce(trim(p_nome),'') = '' then raise exception 'nome_obrigatorio'; end if;
  if p_role not in ('chefe','colaborador') then raise exception 'perfil_invalido'; end if;
  if p_pin is not null and p_pin !~ '^\d{6}$' then raise exception 'pin_formato'; end if;
  if p_id is null then
    if p_pin is null then raise exception 'pin_formato'; end if;
    insert into public.compras_users (nome, role, ativo, setor, pin_hash) values (trim(p_nome), p_role, coalesce(p_ativo, true), v_setor, extensions.crypt(p_pin, extensions.gen_salt('bf'))) returning id into rid;
  else
    if p_id = u.id and (p_role <> 'chefe' or p_ativo = false) then raise exception 'nao_pode_proprio'; end if;
    update public.compras_users x set nome = trim(p_nome), role = p_role, ativo = coalesce(p_ativo, x.ativo), setor = v_setor,
      pin_hash = case when p_pin is not null then extensions.crypt(p_pin, extensions.gen_salt('bf')) else x.pin_hash end,
      failed = case when p_pin is not null then 0 else x.failed end, locked_until = case when p_pin is not null then null else x.locked_until end
     where x.id = p_id returning x.id into rid;
    if coalesce(p_ativo, true) = false or p_pin is not null then delete from public.compras_sessions where user_id = p_id; end if;
  end if;
  return rid;
end $function$
;
CREATE OR REPLACE FUNCTION public.compras_users_list(p_token text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare u public.compras_users;
begin
  u := public.compras__chefe(p_token);
  return coalesce((select jsonb_agg(jsonb_build_object('id', x.id, 'nome', x.nome, 'role', x.role, 'ativo', x.ativo, 'setor', x.setor, 'eu', x.id = u.id) order by x.role, lower(x.nome)) from public.compras_users x), '[]');
end $function$
;

-- Funções internas não acessíveis por fora:
revoke execute on function public.compras__user(text), public.compras__chefe(text) from anon, authenticated, public;
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
end $function$
;
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
end $function$
;
CREATE OR REPLACE FUNCTION public.compras_push_cfg_get()
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
  select to_jsonb(c) from public.compras_push_cfg c where id = 1
$function$
;
CREATE OR REPLACE FUNCTION public.compras_push_cfg_set(p_public text, p_private text)
 RETURNS void
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
  insert into public.compras_push_cfg (id, vapid_public, vapid_private) values (1, p_public, p_private) on conflict (id) do nothing
$function$
;
CREATE OR REPLACE FUNCTION public.compras_push_prune(p_endpoints text[])
 RETURNS void
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
  delete from public.compras_push where endpoint = any(p_endpoints)
$function$
;
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
end $function$
;
revoke execute on function public.compras_push_cfg_get(), public.compras_push_cfg_set(text, text), public.compras_push_prune(text[]), public.compras_push_targets(text, text, uuid) from public, anon, authenticated;
grant execute on function public.compras_push_cfg_get(), public.compras_push_cfg_set(text, text), public.compras_push_prune(text[]), public.compras_push_targets(text, text, uuid) to service_role;

-- ============================================================
-- Receitas importadas do Guará (fichas técnicas)
-- ============================================================
create table if not exists public.compras_recipes (
  id uuid primary key default gen_random_uuid(),
  guara_id text unique not null,
  nome text not null,
  categoria text default '',
  rendimento numeric,
  rendimento_unidade text not null default '',
  preco_venda numeric,            -- PVP com IVA (só nas receitas "finais")
  extra jsonb default '{}',       -- final, iva, food_cost_pct, custo_guara, alergenios
  atualizado_em timestamptz default now()
);
create table if not exists public.compras_recipe_items (
  id uuid primary key default gen_random_uuid(),
  recipe_id uuid references public.compras_recipes(id) on delete cascade,
  ordem int default 0,
  ingrediente text not null,
  product_id uuid references public.compras_products(id) on delete set null,
  sub_recipe_guara_id text,       -- quando o ingrediente é outra receita
  qty numeric,
  unidade text not null default '',
  perda_pct numeric,
  extra jsonb default '{}'        -- custo_guara
);
create index if not exists compras_recipe_items_product_idx on public.compras_recipe_items(product_id);
-- Ligações confirmadas pelo dono: nome do ingrediente no Guará (normalizado) -> produto da app
create table if not exists public.compras_recipe_aliases (
  ingrediente text primary key,
  product_id uuid not null references public.compras_products(id) on delete cascade,
  created_at timestamptz default now()
);
alter table public.compras_recipe_aliases enable row level security;
alter table public.compras_recipes enable row level security;
alter table public.compras_recipe_items enable row level security;

CREATE OR REPLACE FUNCTION public.compras__norm(t text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  select trim(regexp_replace(translate(lower(regexp_replace(coalesce(t,''), '\s*\[[^\]]*\]\s*$', '')),
    'áàâãäéèêëíìîïóòôõöúùûüçñ', 'aaaaaeeeeiiiiooooouuuucn'), '[^a-z0-9]+', ' ', 'g'))
$function$
;

CREATE OR REPLACE FUNCTION public.compras_import_recipes(p_token text, p_receitas jsonb, p_completo boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare u public.compras_users; r jsonb; it jsonb; rid uuid; pid uuid; nr int := 0; ni int := 0; ns int := 0; ord int; k text; un text;
begin
  u := public.compras__chefe(p_token);
  for r in select * from jsonb_array_elements(coalesce(p_receitas,'[]')) loop
    if coalesce(r->>'guara_id','') = '' or coalesce(trim(r->>'nome'),'') = '' then continue; end if;
    un := case when r->>'rendimento_unidade' in ('un','kg','L') then r->>'rendimento_unidade' else 'un' end;
    insert into public.compras_recipes (guara_id, nome, categoria, rendimento, rendimento_unidade, preco_venda, extra, atualizado_em)
    values (r->>'guara_id', trim(r->>'nome'), coalesce(r->>'categoria',''), nullif(r->>'rendimento','')::numeric, un,
            nullif(r->>'preco_venda','')::numeric, coalesce(r->'extra','{}'::jsonb), now())
    on conflict (guara_id) do update set nome = excluded.nome, categoria = excluded.categoria, rendimento = excluded.rendimento,
      rendimento_unidade = excluded.rendimento_unidade, preco_venda = excluded.preco_venda, extra = excluded.extra, atualizado_em = now()
    returning id into rid;
    delete from public.compras_recipe_items where recipe_id = rid;
    ord := 0;
    for it in select * from jsonb_array_elements(coalesce(r->'ingredientes','[]')) loop
      ord := ord + 1; pid := null;
      if coalesce(it->>'sub_receita_id','') = '' then
        k := public.compras__norm(it->>'nome');
        select a.product_id into pid from public.compras_recipe_aliases a where a.ingrediente = k;
        if pid is null then
          select p.id into pid from public.compras_products p where public.compras__norm(p.nome) = k limit 1;
        end if;
        if pid is null then
          select o.product_id into pid from public.compras_offers o where public.compras__norm(o.alias) = k limit 1;
        end if;
        if pid is null then ns := ns + 1; end if;
      end if;
      insert into public.compras_recipe_items (recipe_id, ordem, ingrediente, qty, unidade, perda_pct, product_id, sub_recipe_guara_id, extra)
      values (rid, ord, coalesce(it->>'nome',''), nullif(it->>'qty','')::numeric,
              case when it->>'unidade' in ('un','kg','L') then it->>'unidade' else 'un' end,
              nullif(it->>'perda_pct','')::numeric, pid, nullif(it->>'sub_receita_id',''),
              coalesce(it->'extra','{}'::jsonb) || case when it ? 'custo' then jsonb_build_object('custo_guara', it->'custo') else '{}'::jsonb end);
      ni := ni + 1;
    end loop;
    nr := nr + 1;
  end loop;
  if p_completo then
    delete from public.compras_recipes where guara_id not in (select x->>'guara_id' from jsonb_array_elements(coalesce(p_receitas,'[]')) x);
  end if;
  return jsonb_build_object('receitas', nr, 'ingredientes', ni, 'sem_produto', ns);
end $function$
;

-- Preenche o total das faturas (só onde está vazio), por número + início do nome do fornecedor
CREATE OR REPLACE FUNCTION public.compras_set_invoice_totals(p_token text, p_list jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare u public.compras_users; x jsonb; n int := 0; c int;
begin
  u := public.compras__chefe(p_token);
  for x in select * from jsonb_array_elements(coalesce(p_list,'[]')) loop
    if nullif(x->>'total','') is null then continue; end if;
    update public.compras_invoices i set total = (x->>'total')::numeric
     from public.compras_suppliers s
    where s.id = i.supplier_id and i.total is null
      and lower(regexp_replace(coalesce(i.numero,''), '\s', '', 'g')) = lower(regexp_replace(coalesce(x->>'numero',''), '\s', '', 'g'))
      and (lower(regexp_replace(s.nome, '[^A-Za-z0-9]', '', 'g')) like lower(regexp_replace(coalesce(x->>'fornecedor',''), '[^A-Za-z0-9]', '', 'g')) || '%'
        or lower(regexp_replace(coalesce(x->>'fornecedor',''), '[^A-Za-z0-9]', '', 'g')) like lower(regexp_replace(s.nome, '[^A-Za-z0-9]', '', 'g')) || '%');
    get diagnostics c = row_count; n := n + c;
  end loop;
  return jsonb_build_object('atualizadas', n);
end $function$
;

-- ============================================================
-- Stock e vendas (ZSbms)
-- ============================================================
alter table public.compras_settings add column if not exists stock_inicio date not null default date '2026-11-12';

-- Entradas: linhas de fatura já ligadas ao produto, em unidades base (kg / L / un)
create table if not exists public.compras_purchase_lines (
  id bigserial primary key,
  invoice_id uuid references public.compras_invoices(id) on delete cascade,
  product_id uuid not null references public.compras_products(id) on delete cascade,
  data date not null,
  qty numeric not null
);
create index if not exists compras_purchase_lines_prod_idx on public.compras_purchase_lines(product_id, data);
alter table public.compras_purchase_lines enable row level security;

-- Artigos vendidos no ZSbms e a que receita / produto correspondem
create table if not exists public.compras_zs_items (
  codigo int primary key,
  descricao text not null default '',
  recipe_guara_id text,                -- receita do Guará consumida por cada venda
  product_id uuid references public.compras_products(id) on delete set null,  -- ou produto vendido tal e qual
  fator numeric not null default 1,    -- receitas (ou unidades do produto) por cada venda
  ignorar boolean not null default false,  -- menus cujos componentes já vêm em linhas próprias, taxas, etc.
  revisto boolean not null default false,
  atualizado_em timestamptz default now()
);
alter table public.compras_zs_items enable row level security;

-- Vendas por dia e artigo (somadas a partir dos documentos do ZSbms; NC a subtrair, anulados fora)
create table if not exists public.compras_sales (
  dia date not null,
  codigo int not null,
  descricao text not null default '',
  qtd numeric not null default 0,
  total numeric not null default 0,
  primary key (dia, codigo)
);
alter table public.compras_sales enable row level security;

-- Contagens de stock
create table if not exists public.compras_stock_counts (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  created_by uuid references public.compras_users(id) on delete set null,
  fechada_em timestamptz,
  fechada_por uuid references public.compras_users(id) on delete set null,
  resultado jsonb
);
create unique index if not exists compras_stock_counts_aberta on public.compras_stock_counts ((true)) where fechada_em is null;
alter table public.compras_stock_counts enable row level security;

create table if not exists public.compras_stock_count_lines (
  count_id uuid not null references public.compras_stock_counts(id) on delete cascade,
  product_id uuid not null references public.compras_products(id) on delete cascade,
  setor text not null,
  qty numeric not null,
  updated_by uuid references public.compras_users(id) on delete set null,
  updated_at timestamptz not null default now(),
  primary key (count_id, product_id, setor)
);
alter table public.compras_stock_count_lines enable row level security;

-- Quanto vale 1 unidade do produto nas receitas do Guará (ex.: Frize garrafa = 250 ml na receita)
alter table public.compras_products add column if not exists receita_fator numeric not null default 1 check (receita_fator > 0);
-- Acompanhamentos que o ZSbms regista em linha própria (não contam dentro do prato)
alter table public.compras_recipes add column if not exists acompanhamento boolean not null default false;

-- Quantidade efetiva de uma linha de receita: o Guará às vezes traz gramas/ml marcados como "un"
create or replace function public.compras__item_qty(i public.compras_recipe_items) returns numeric
language sql stable set search_path to 'public' as $$
  select case when i.unidade = 'un' and coalesce(i.qty,0) >= 5 and coalesce(
           (select p.unidade from public.compras_products p where p.id = i.product_id),
           (select s.rendimento_unidade from public.compras_recipes s where s.guara_id = i.sub_recipe_guara_id)) in ('kg','L')
         then i.qty / 1000 else coalesce(i.qty, 0) end
$$;

-- Quanto de cada produto gasta UMA receita inteira do Guará (sub-receitas até 6 níveis; acompanhamentos vendidos à parte não entram)
create or replace function public.compras__recipe_usage()
returns table(root text, product_id uuid, qty numeric)
language sql stable set search_path to 'public' as $$
  with recursive u(root, cur, f, depth) as (
    select r.guara_id, r.guara_id, 1::numeric, 0 from public.compras_recipes r
    union all
    select u.root, i.sub_recipe_guara_id, u.f * public.compras__item_qty(i) / coalesce(nullif(s.rendimento,0),1), u.depth + 1
      from u
      join public.compras_recipes r on r.guara_id = u.cur
      join public.compras_recipe_items i on i.recipe_id = r.id and i.sub_recipe_guara_id is not null
      join public.compras_recipes s on s.guara_id = i.sub_recipe_guara_id and not s.acompanhamento
     where u.depth < 6
  )
  select u.root, i.product_id, sum(u.f * public.compras__item_qty(i) / p.receita_fator)
    from u
    join public.compras_recipes r on r.guara_id = u.cur
    join public.compras_recipe_items i on i.recipe_id = r.id and i.product_id is not null
    join public.compras_products p on p.id = i.product_id
   group by 1, 2
$$;

-- Consumo teórico por produto e dia, a partir das vendas
create or replace function public.compras__consumption()
returns table(product_id uuid, dia date, qty numeric)
language sql stable set search_path to 'public' as $$
  with use as (select * from public.compras__recipe_usage())
  select x.product_id, s.dia, sum(s.qtd * z.fator * x.q)
    from public.compras_sales s
    join public.compras_zs_items z on z.codigo = s.codigo and not z.ignorar
    join lateral (
      select z.product_id as product_id, 1::numeric as q where z.product_id is not null
      union all
      select use.product_id, use.qty from use where z.recipe_guara_id is not null and use.root = z.recipe_guara_id
    ) x on true
   group by 1, 2
$$;

-- Stock calculado de cada produto: última contagem (ou 0 no início) + entradas (faturas) − saídas (vendas × receitas)
create or replace function public.compras__stock_rows()
returns table(product_id uuid, base date, base_q numeric, contado boolean, entradas numeric, saidas numeric, stock numeric, consumo_dia numeric)
language sql stable set search_path to 'public' as $$
  with ini as (select coalesce((select stock_inicio from public.compras_settings where id = 1), current_date) d),
  lastc as (
    select distinct on (l.product_id) l.product_id, c.id cid, c.created_at::date d
      from public.compras_stock_count_lines l join public.compras_stock_counts c on c.id = l.count_id
     where c.fechada_em is not null
     order by l.product_id, c.created_at desc),
  lc as (select lastc.product_id, lastc.d, (select sum(qty) from public.compras_stock_count_lines x where x.count_id = lastc.cid and x.product_id = lastc.product_id) q from lastc),
  cons as materialized (select * from public.compras__consumption()),
  win as (select max(dia) mx, greatest(1, count(distinct dia) filter (where dia > (select max(dia) from public.compras_sales) - 28)) nd from public.compras_sales),
  b as (
    select p.id, coalesce(lc.d, (select d from ini)) base, coalesce(lc.q, 0) base_q, lc.d is not null contado
      from public.compras_products p left join lc on lc.product_id = p.id)
  select b.id, b.base, b.base_q, b.contado,
         coalesce(e.q, 0), coalesce(s.q, 0), b.base_q + coalesce(e.q, 0) - coalesce(s.q, 0),
         coalesce(c.q, 0) / (select nd from win)
    from b
    left join lateral (select sum(pl.qty) q from public.compras_purchase_lines pl where pl.product_id = b.id and pl.data >= b.base) e on true
    left join lateral (select sum(cons.qty) q from cons where cons.product_id = b.id and cons.dia >= b.base) s on true
    left join lateral (select sum(cons.qty) q from cons where cons.product_id = b.id and cons.dia > (select mx from win) - 28) c on true
$$;

create or replace function public.compras_stock(p_token text) returns jsonb
language plpgsql security definer set search_path to 'public', 'extensions' as $function$
declare u public.compras_users;
begin
  u := public.compras__user(p_token);
  return jsonb_build_object(
    'inicio', (select stock_inicio from public.compras_settings where id = 1),
    'vendas_ate', (select max(dia) from public.compras_sales),
    'vendas_desde', (select min(dia) from public.compras_sales),
    'sem_receita', (select count(*) from public.compras_zs_items z where not z.ignorar and z.recipe_guara_id is null and z.product_id is null
                      and exists (select 1 from public.compras_sales s where s.codigo = z.codigo and s.dia > current_date - 35)),
    'contagem_aberta', (select c.id from public.compras_stock_counts c where c.fechada_em is null),
    'ultima_contagem', (select max(fechada_em) from public.compras_stock_counts),
    'produtos', coalesce((select jsonb_agg(jsonb_build_object('id', r.product_id, 'base', r.base, 'base_q', round(r.base_q, 3), 'contado', r.contado,
                 'entradas', round(r.entradas, 3), 'saidas', round(r.saidas, 3), 'stock', round(r.stock, 3), 'consumo_dia', round(r.consumo_dia, 4)))
                 from public.compras__stock_rows() r
                where r.entradas <> 0 or r.saidas <> 0 or r.contado or r.consumo_dia <> 0), '[]'::jsonb));
end $function$;

-- Vendas do ZSbms (substitui os dias enviados). O núcleo é comum à app (chefe) e à importação automática.
create or replace function public.compras__import_sales(p_rows jsonb) returns jsonb
language plpgsql security definer set search_path to 'public', 'extensions' as $function$
declare n int; nd int;
begin
  delete from public.compras_sales where dia in (select distinct (x->>'dia')::date from jsonb_array_elements(coalesce(p_rows,'[]')) x);
  get diagnostics nd = row_count;
  insert into public.compras_sales (dia, codigo, descricao, qtd, total)
  select (x->>'dia')::date, (x->>'codigo')::int, max(coalesce(x->>'descricao','')), sum(coalesce((x->>'qtd')::numeric,0)), sum(coalesce((x->>'total')::numeric,0))
    from jsonb_array_elements(coalesce(p_rows,'[]')) x
   where nullif(x->>'dia','') is not null and nullif(x->>'codigo','') is not null
   group by 1, 2;
  get diagnostics n = row_count;
  insert into public.compras_zs_items (codigo, descricao)
  select distinct on ((x->>'codigo')::int) (x->>'codigo')::int, coalesce(x->>'descricao','')
    from jsonb_array_elements(coalesce(p_rows,'[]')) x where nullif(x->>'codigo','') is not null
  on conflict (codigo) do update set descricao = excluded.descricao;
  perform public.compras__refresh_media_sushi();
  return jsonb_build_object('linhas', n, 'substituidas', nd);
end $function$;
revoke execute on function public.compras__import_sales(jsonb) from public, anon, authenticated;

create or replace function public.compras_import_sales(p_token text, p_rows jsonb) returns jsonb
language plpgsql security definer set search_path to 'public', 'extensions' as $function$
begin
  perform public.compras__chefe(p_token);
  return public.compras__import_sales(p_rows);
end $function$;

-- Contagens
create or replace function public.compras_count_get(p_token text) returns jsonb
language plpgsql security definer set search_path to 'public', 'extensions' as $function$
declare u public.compras_users; c public.compras_stock_counts;
begin
  u := public.compras__user(p_token);
  select * into c from public.compras_stock_counts where fechada_em is null;
  if not found then
    return jsonb_build_object('aberta', null,
      'ultima', (select jsonb_build_object('id', x.id, 'data', x.created_at, 'fechada_em', x.fechada_em, 'resultado', x.resultado)
                   from public.compras_stock_counts x where x.fechada_em is not null order by x.fechada_em desc limit 1));
  end if;
  return jsonb_build_object('aberta', jsonb_build_object('id', c.id, 'data', c.created_at,
    'linhas', coalesce((select jsonb_agg(jsonb_build_object('product_id', l.product_id, 'setor', l.setor, 'qty', l.qty,
                 'por', (select nome from public.compras_users where id = l.updated_by), 'em', l.updated_at))
               from public.compras_stock_count_lines l where l.count_id = c.id), '[]'::jsonb)));
end $function$;

create or replace function public.compras_count_start(p_token text) returns uuid
language plpgsql security definer set search_path to 'public', 'extensions' as $function$
declare u public.compras_users; cid uuid;
begin
  u := public.compras__chefe(p_token);
  select id into cid from public.compras_stock_counts where fechada_em is null;
  if cid is null then
    insert into public.compras_stock_counts (created_by) values (u.id) returning id into cid;
  end if;
  return cid;
end $function$;

create or replace function public.compras_count_set(p_token text, p_count uuid, p_product uuid, p_setor text, p_qty numeric) returns void
language plpgsql security definer set search_path to 'public', 'extensions' as $function$
declare u public.compras_users;
begin
  u := public.compras__user(p_token);
  if not exists (select 1 from public.compras_stock_counts where id = p_count and fechada_em is null) then raise exception 'contagem_fechada'; end if;
  if p_setor not in ('cozinha','sushi','bar','takeaway') then raise exception 'setor_invalido'; end if;
  if p_qty is null then
    delete from public.compras_stock_count_lines where count_id = p_count and product_id = p_product and setor = p_setor;
  else
    if p_qty < 0 then raise exception 'quantidade_invalida'; end if;
    insert into public.compras_stock_count_lines (count_id, product_id, setor, qty, updated_by, updated_at)
    values (p_count, p_product, p_setor, p_qty, u.id, now())
    on conflict (count_id, product_id, setor) do update set qty = excluded.qty, updated_by = excluded.updated_by, updated_at = now();
  end if;
end $function$;

create or replace function public.compras_count_close(p_token text, p_count uuid) returns jsonb
language plpgsql security definer set search_path to 'public', 'extensions' as $function$
declare u public.compras_users; res jsonb;
begin
  u := public.compras__chefe(p_token);
  if not exists (select 1 from public.compras_stock_counts where id = p_count and fechada_em is null) then raise exception 'contagem_fechada'; end if;
  select coalesce(jsonb_agg(jsonb_build_object('product_id', l.product_id, 'contado', l.q, 'esperado', round(coalesce(r.stock, 0), 3))), '[]'::jsonb)
    into res
    from (select product_id, sum(qty) q from public.compras_stock_count_lines where count_id = p_count group by 1) l
    left join public.compras__stock_rows() r on r.product_id = l.product_id;
  update public.compras_stock_counts set fechada_em = now(), fechada_por = u.id, resultado = res where id = p_count;
  return res;
end $function$;

create or replace function public.compras_count_cancel(p_token text, p_count uuid) returns void
language plpgsql security definer set search_path to 'public', 'extensions' as $function$
declare u public.compras_users;
begin
  u := public.compras__chefe(p_token);
  delete from public.compras_stock_counts where id = p_count and fechada_em is null;
end $function$;

-- Artigos do ZSbms e ligações (para o chefe rever)
create or replace function public.compras_zs_items(p_token text) returns jsonb
language plpgsql security definer set search_path to 'public', 'extensions' as $function$
declare u public.compras_users;
begin
  u := public.compras__chefe(p_token);
  return coalesce((select jsonb_agg(jsonb_build_object('codigo', z.codigo, 'descricao', z.descricao, 'recipe_guara_id', z.recipe_guara_id,
      'receita', r.nome, 'product_id', z.product_id, 'fator', z.fator, 'ignorar', z.ignorar,
      'vendidos', (select sum(qtd) from public.compras_sales s where s.codigo = z.codigo and s.dia > current_date - 35)) order by z.descricao)
    from public.compras_zs_items z left join public.compras_recipes r on r.guara_id = z.recipe_guara_id), '[]'::jsonb);
end $function$;

create or replace function public.compras_zs_map(p_token text, p_list jsonb) returns int
language plpgsql security definer set search_path to 'public', 'extensions' as $function$
declare u public.compras_users; x jsonb; n int := 0;
begin
  u := public.compras__chefe(p_token);
  for x in select * from jsonb_array_elements(coalesce(p_list,'[]')) loop
    update public.compras_zs_items set
      recipe_guara_id = case when x ? 'recipe_guara_id' then nullif(x->>'recipe_guara_id','') else recipe_guara_id end,
      product_id = case when x ? 'product_id' then nullif(x->>'product_id','')::uuid else product_id end,
      fator = coalesce(nullif(x->>'fator','')::numeric, fator),
      ignorar = coalesce((x->>'ignorar')::boolean, ignorar),
      revisto = true, atualizado_em = now()
     where codigo = (x->>'codigo')::int;
    n := n + 1;
  end loop;
  return n;
end $function$;

revoke execute on function public.compras__recipe_usage(), public.compras__consumption(), public.compras__stock_rows(), public.compras__item_qty(public.compras_recipe_items) from public, anon, authenticated;

-- Peças de sushi por venda (rolos do all you can eat = 4 peças) e "peça média" para as "@Repetição N peças"
alter table public.compras_zs_items add column if not exists pecas numeric;
insert into public.compras_recipes (guara_id, nome, categoria, rendimento, rendimento_unidade, extra)
values ('local-media-sushi', 'Peça média de sushi (all you can eat)', 'Local', 1, 'un', '{"local": true}')
on conflict (guara_id) do nothing;

-- Recalcula a peça média: o que se gastou no sushi do all you can eat (últimos 60 dias) a dividir pelas peças servidas
create or replace function public.compras__refresh_media_sushi() returns void
language plpgsql security definer set search_path to 'public' as $$
declare rid uuid; mx date; pcs numeric;
begin
  select id into rid from public.compras_recipes where guara_id = 'local-media-sushi';
  if rid is null then return; end if;
  select max(dia) into mx from public.compras_sales;
  select sum(s.qtd * z.pecas) into pcs from public.compras_sales s join public.compras_zs_items z on z.codigo = s.codigo
   where z.pecas is not null and s.dia > mx - 60;
  delete from public.compras_recipe_items where recipe_id = rid;
  if coalesce(pcs, 0) <= 0 then return; end if;
  insert into public.compras_recipe_items (recipe_id, ordem, ingrediente, product_id, qty, unidade, extra)
  select rid, row_number() over (order by p.nome), p.nome, p.id, round(x.q / pcs * p.receita_fator, 6), p.unidade, jsonb_build_object('calculado', true, 'pecas', pcs)
    from (select u.product_id, sum(s.qtd * z.fator * u.qty) q
            from public.compras_sales s
            join public.compras_zs_items z on z.codigo = s.codigo and z.pecas is not null and z.recipe_guara_id is not null
            join public.compras__recipe_usage() u on u.root = z.recipe_guara_id
           where s.dia > mx - 60 group by 1) x
    join public.compras_products p on p.id = x.product_id
   where x.q > 0;
end $$;
revoke execute on function public.compras__refresh_media_sushi() from public, anon, authenticated;

-- Data da fatura do preço anterior
alter table public.compras_offers add column if not exists prev_data date;

-- Importação automática das vendas do ZSbms (função compras-zs-vendas, sem PC ligado).
-- compras_zs_cfg: chave que a tarefa agendada envia à função (só acessível com a chave de serviço) e registo da última execução.
-- O utilizador do ZSbms fica nos segredos da função (ZS_NIF, ZS_USER, ZS_PASS), nunca aqui.
create table if not exists public.compras_zs_cfg (
  id boolean primary key default true check (id),
  chave text not null default replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', ''),
  ultima_em timestamptz,
  ultimo jsonb
);
alter table public.compras_zs_cfg enable row level security;
revoke all on public.compras_zs_cfg from anon, authenticated;
insert into public.compras_zs_cfg default values on conflict (id) do nothing;

-- Chamada pela função (chave de serviço): grava as vendas e regista o resultado. Com p_rows a null só regista (ex.: um erro).
create or replace function public.compras_zs_auto_import(p_rows jsonb, p_info jsonb) returns jsonb
language plpgsql security definer set search_path to 'public', 'extensions' as $function$
declare r jsonb := null;
begin
  if p_rows is not null then r := public.compras__import_sales(p_rows); end if;
  update public.compras_zs_cfg set ultima_em = now(), ultimo = coalesce(p_info, '{}'::jsonb) || coalesce(r, '{}'::jsonb) where id;
  return r;
end $function$;
revoke execute on function public.compras_zs_auto_import(jsonb, jsonb) from public, anon, authenticated;
grant execute on function public.compras_zs_auto_import(jsonb, jsonb) to service_role;

-- Agendamento (pg_cron corre em UTC): 10:10 e 11:10 UTC = 10:10 e 11:10 em Lisboa no inverno, uma hora mais tarde no verão.
-- A segunda chamada é uma rede de segurança; a importação substitui os dias, por isso repetir não duplica nada.
create extension if not exists pg_cron with schema pg_catalog;
create or replace function public.compras__zs_disparar() returns bigint
language sql security definer set search_path to 'public', 'extensions' as $$
  select net.http_post(
    url := 'https://cckgrpmspyurgmbgtjdu.supabase.co/functions/v1/compras-zs-vendas',
    body := '{}'::jsonb,
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-zs-key', (select chave from public.compras_zs_cfg)),
    timeout_milliseconds := 150000);
$$;
revoke execute on function public.compras__zs_disparar() from public, anon, authenticated;
select cron.schedule('compras-zs-vendas', '10 10,11 * * *', 'select public.compras__zs_disparar()');

-- ============================================================
-- Faturas e receitas do Guará sem PC (função compras-guara) e correspondência
-- ============================================================
-- Faturas e receitas do Guará sem PC: núcleos sem token (para a importação automática) e fila das faturas com artigos novos.

-- 1) Gravar fatura: núcleo com o utilizador explícito; a versão da app continua a exigir chefe.
create or replace function public.compras__save_invoice(p_user uuid, p_inv jsonb) returns jsonb
language plpgsql security definer set search_path to 'public', 'extensions' as $function$
declare
  sid uuid; inv uuid := gen_random_uuid(); l jsonb; pid uuid; k text;
  up numeric; pq numeric; pp numeric; prev public.compras_offers; n int := 0; newmap jsonb := '{}'; d date; v_nif text;
  known_pid uuid; known_pq numeric; is_nc boolean; v_total numeric;
begin
  d := coalesce(nullif(p_inv->>'data','')::date, current_date);
  v_nif := regexp_replace(coalesce(p_inv->>'nif',''), '\D', '', 'g');
  v_total := nullif(p_inv->>'total','')::numeric;
  -- nota de crédito: total negativo ou número começado por NC
  is_nc := coalesce(v_total, 0) < 0 or coalesce(p_inv->>'numero','') ~* '^\s*NC';
  sid := nullif(p_inv->>'supplier_id','')::uuid;
  if sid is null and v_nif <> '' then
    select s.id into sid from public.compras_suppliers s where s.nif = v_nif limit 1;
  end if;
  if sid is null then
    insert into public.compras_suppliers (nome, nif) values (coalesce(nullif(trim(p_inv->>'fornecedor_nome'),''), 'Fornecedor'), v_nif) returning id into sid;
  elsif v_nif <> '' then
    update public.compras_suppliers s set nif = v_nif where s.id = sid and s.nif = '';
  end if;
  insert into public.compras_invoices (id, supplier_id, fornecedor_nome, numero, data, total, linhas, created_by)
  values (inv, sid, (select s.nome from public.compras_suppliers s where s.id = sid), coalesce(p_inv->>'numero',''), d,
          v_total, coalesce(p_inv->'linhas','[]'::jsonb), p_user);
  for l in select * from jsonb_array_elements(coalesce(p_inv->'linhas','[]'::jsonb)) loop
    pp := nullif(l->>'price','')::numeric;
    pq := coalesce(nullif(l->>'pack_qty','')::numeric, 1);
    if pq <= 0 then pq := 1; end if;
    if pp is null or pp < 0 then continue; end if;
    -- vasilhame / caução não é produto (ex.: "Barril Damm 50L Vas")
    if coalesce(l->>'desc','') ~* '(vasilhame|cau[cç][aã]o)' or coalesce(l->>'desc','') ~* '(^|[^[:alnum:]])(vas|grade)([^[:alnum:]]|$)' then continue; end if;
    pid := nullif(l->>'product_id','')::uuid;
    -- artigo já conhecido neste fornecedor (pela descrição da fatura): usa sempre o mesmo produto e a mesma embalagem.
    -- Se o produto vier escolhido à mão (revisão na app), vale o que o chefe escolheu.
    known_pid := null; known_pq := null;
    if coalesce(l->>'desc','') <> '' then
      select o.product_id, o.pack_qty into known_pid, known_pq from public.compras_offers o
       where o.supplier_id = sid and lower(o.alias) = lower(l->>'desc') limit 1;
    end if;
    if pid is null and known_pid is not null then
      pid := known_pid;
      if known_pq > 0 then pq := known_pq; end if;
    end if;
    up := pp / pq;
    if pid is null then
      k := lower(trim(coalesce(l->>'novo_nome','')));
      if k = '' then continue; end if;
      if newmap ? k then pid := (newmap->>k)::uuid;
      else
        select p.id into pid from public.compras_products p where lower(p.nome) = k limit 1;
        if pid is null then
          insert into public.compras_products (nome, categoria, unidade)
          values (trim(l->>'novo_nome'), coalesce(nullif(l->>'categoria',''),'Outros'),
                  case when l->>'base_unit' in ('un','kg','L') then l->>'base_unit' else 'un' end)
          returning id into pid;
        end if;
        newmap := newmap || jsonb_build_object(k, pid);
      end if;
    end if;
    -- nota de crédito: tira stock e não conta como preço de compra
    if is_nc then
      if nullif(l->>'qty','') is not null then
        insert into public.compras_purchase_lines (invoice_id, product_id, data, qty) values (inv, pid, d, -abs((l->>'qty')::numeric * pq));
      end if;
      n := n + 1;
      continue;
    end if;
    insert into public.compras_price_history (product_id, supplier_id, data, unit_price, invoice_id) values (pid, sid, d, up, inv);
    if nullif(l->>'qty','') is not null then
      insert into public.compras_purchase_lines (invoice_id, product_id, data, qty) values (inv, pid, d, (l->>'qty')::numeric * pq);
    end if;
    select * into prev from public.compras_offers o where o.product_id = pid and o.supplier_id = sid;
    if not found then
      insert into public.compras_offers (product_id, supplier_id, alias, codigo, pack_qty, pack_price, unit_price, prev_unit_price, data, invoice_id)
      values (pid, sid, coalesce(l->>'desc',''), coalesce(l->>'codigo',''), pq, pp, up, null, d, inv);
    elsif prev.data is null or d >= prev.data then
      update public.compras_offers o set alias = coalesce(l->>'desc',''), codigo = coalesce(l->>'codigo',''), pack_qty = pq, pack_price = pp,
        unit_price = up, prev_unit_price = case when prev.invoice_id = inv then prev.prev_unit_price when lower(coalesce(prev.alias,'')) <> lower(coalesce(l->>'desc','')) then null when up > 0 and prev.unit_price > 0 and (up / prev.unit_price >= 2.5 or up / prev.unit_price <= 0.4) then null else prev.unit_price end, prev_data = case when prev.invoice_id = inv then prev.prev_data when lower(coalesce(prev.alias,'')) <> lower(coalesce(l->>'desc','')) then null else prev.data end, data = d, invoice_id = inv
       where o.product_id = pid and o.supplier_id = sid;
    end if;
    n := n + 1;
  end loop;
  return jsonb_build_object('invoice_id', inv, 'supplier_id', sid, 'linhas', n, 'nota_credito', is_nc);
end $function$;
revoke execute on function public.compras__save_invoice(uuid, jsonb) from public, anon, authenticated;

create or replace function public.compras_save_invoice(p_token text, p_inv jsonb) returns jsonb
language plpgsql security definer set search_path to 'public', 'extensions' as $function$
declare u public.compras_users;
begin
  u := public.compras__chefe(p_token);
  return public.compras__save_invoice(u.id, p_inv);
end $function$;

-- Fornecedor pelo nome (o mesmo critério da importação: igual ou começa pelo outro, sem espaços nem pontuação)
create or replace function public.compras__fornecedor(p_nome text) returns uuid
language sql stable security definer set search_path to 'public', 'extensions' as $function$
  with k as (select lower(regexp_replace(trim(coalesce(p_nome,'')), '[^A-Za-z0-9]', '', 'g')) nk)
  select s.id from public.compras_suppliers s, k
   where k.nk <> '' and (lower(regexp_replace(s.nome, '[^A-Za-z0-9]', '', 'g')) = k.nk
      or (length(k.nk) >= 4 and lower(regexp_replace(s.nome, '[^A-Za-z0-9]', '', 'g')) like k.nk || '%')
      or (length(lower(regexp_replace(s.nome, '[^A-Za-z0-9]', '', 'g'))) >= 4 and k.nk like lower(regexp_replace(s.nome, '[^A-Za-z0-9]', '', 'g')) || '%'))
   order by s.created_at limit 1
$function$;
revoke execute on function public.compras__fornecedor(text) from public, anon, authenticated;

create or replace function public.compras__import_invoice(p_user uuid, p_inv jsonb) returns jsonb
language plpgsql security definer set search_path to 'public', 'extensions' as $function$
declare sid uuid; nome text; numk text;
begin
  nome := trim(coalesce(p_inv->>'fornecedor_nome',''));
  numk := lower(regexp_replace(coalesce(p_inv->>'numero',''), '\s', '', 'g'));
  if lower(regexp_replace(nome, '[^A-Za-z0-9]', '', 'g')) = '' or numk = '' then return jsonb_build_object('ignorada', 'sem_dados'); end if;
  sid := public.compras__fornecedor(nome);
  if sid is not null and exists (select 1 from public.compras_invoices i where i.supplier_id = sid and lower(regexp_replace(coalesce(i.numero,''), '\s', '', 'g')) = numk) then
    return jsonb_build_object('ignorada', 'repetida');
  end if;
  if sid is null then
    insert into public.compras_suppliers (nome) values (nome) returning id into sid;
  end if;
  return public.compras__save_invoice(p_user, p_inv || jsonb_build_object('supplier_id', sid));
end $function$;
revoke execute on function public.compras__import_invoice(uuid, jsonb) from public, anon, authenticated;

create or replace function public.compras_import_invoice(p_token text, p_inv jsonb) returns jsonb
language plpgsql security definer set search_path to 'public', 'extensions' as $function$
declare u public.compras_users;
begin
  u := public.compras__chefe(p_token);
  return public.compras__import_invoice(u.id, p_inv);
end $function$;

-- 2) Receitas: núcleo sem token
create or replace function public.compras__import_recipes(p_receitas jsonb, p_completo boolean default false) returns jsonb
language plpgsql security definer set search_path to 'public', 'extensions' as $function$
declare r jsonb; it jsonb; rid uuid; pid uuid; nr int := 0; ni int := 0; ns int := 0; ord int; k text; un text;
begin
  for r in select * from jsonb_array_elements(coalesce(p_receitas,'[]')) loop
    if coalesce(r->>'guara_id','') = '' or coalesce(trim(r->>'nome'),'') = '' then continue; end if;
    un := case when r->>'rendimento_unidade' in ('un','kg','L') then r->>'rendimento_unidade' else 'un' end;
    insert into public.compras_recipes (guara_id, nome, categoria, rendimento, rendimento_unidade, preco_venda, extra, atualizado_em)
    values (r->>'guara_id', trim(r->>'nome'), coalesce(r->>'categoria',''), nullif(r->>'rendimento','')::numeric, un,
            nullif(r->>'preco_venda','')::numeric, coalesce(r->'extra','{}'::jsonb), now())
    on conflict (guara_id) do update set nome = excluded.nome, categoria = excluded.categoria, rendimento = excluded.rendimento,
      rendimento_unidade = excluded.rendimento_unidade, preco_venda = excluded.preco_venda, extra = excluded.extra, atualizado_em = now()
    returning id into rid;
    delete from public.compras_recipe_items where recipe_id = rid;
    ord := 0;
    for it in select * from jsonb_array_elements(coalesce(r->'ingredientes','[]')) loop
      ord := ord + 1; pid := null;
      if coalesce(it->>'sub_receita_id','') = '' then
        k := public.compras__norm(it->>'nome');
        select a.product_id into pid from public.compras_recipe_aliases a where a.ingrediente = k;
        if pid is null then
          select p.id into pid from public.compras_products p where public.compras__norm(p.nome) = k limit 1;
        end if;
        if pid is null then
          select o.product_id into pid from public.compras_offers o where public.compras__norm(o.alias) = k limit 1;
        end if;
        if pid is null then ns := ns + 1; end if;
      end if;
      insert into public.compras_recipe_items (recipe_id, ordem, ingrediente, qty, unidade, perda_pct, product_id, sub_recipe_guara_id, extra)
      values (rid, ord, coalesce(it->>'nome',''), nullif(it->>'qty','')::numeric,
              case when it->>'unidade' in ('un','kg','L') then it->>'unidade' else 'un' end,
              nullif(it->>'perda_pct','')::numeric, pid, nullif(it->>'sub_receita_id',''),
              coalesce(it->'extra','{}'::jsonb) || case when it ? 'custo' then jsonb_build_object('custo_guara', it->'custo') else '{}'::jsonb end);
      ni := ni + 1;
    end loop;
    nr := nr + 1;
  end loop;
  if p_completo then
    delete from public.compras_recipes where guara_id not in (select x->>'guara_id' from jsonb_array_elements(coalesce(p_receitas,'[]')) x);
  end if;
  return jsonb_build_object('receitas', nr, 'ingredientes', ni, 'sem_produto', ns);
end $function$;
revoke execute on function public.compras__import_recipes(jsonb, boolean) from public, anon, authenticated;

create or replace function public.compras_import_recipes(p_token text, p_receitas jsonb, p_completo boolean default false) returns jsonb
language plpgsql security definer set search_path to 'public', 'extensions' as $function$
declare u public.compras_users;
begin
  u := public.compras__chefe(p_token);
  return public.compras__import_recipes(p_receitas, p_completo);
end $function$;

-- 3) Faturas lidas do Guará (uma linha por fatura do Guará) e registo das execuções
create table if not exists public.compras_guara_faturas (
  guara_id int primary key,
  fornecedor text not null default '',
  numero text not null default '',
  data date,
  total numeric,
  estado text not null check (estado in ('importada', 'pendente', 'ja_existia', 'ignorada')),
  dados jsonb not null default '{}',     -- fatura tal como lida (linhas com desc, qty, unidade_fatura, price, guara_embalagem)
  resultado jsonb,
  criado_em timestamptz not null default now(),
  tratado_em timestamptz
);
alter table public.compras_guara_faturas enable row level security;
revoke all on public.compras_guara_faturas from anon, authenticated;

create table if not exists public.compras_guara_cfg (
  id boolean primary key default true check (id),
  faturas_em timestamptz, faturas jsonb,
  receitas_em timestamptz, receitas jsonb,
  correspondencia_em timestamptz, correspondencia jsonb
);
alter table public.compras_guara_cfg enable row level security;
revoke all on public.compras_guara_cfg from anon, authenticated;
insert into public.compras_guara_cfg default values on conflict (id) do nothing;

-- Ingredientes já vistos que não correspondem a nenhum produto comprado (feitos cá, sem fatura, etc.), para não voltar a tentar todos os dias
create table if not exists public.compras_ingredientes_sem_produto (
  ingrediente text primary key,   -- compras__norm(nome)
  nota text not null default '',
  revisto_em timestamptz not null default now()
);
alter table public.compras_ingredientes_sem_produto enable row level security;
revoke all on public.compras_ingredientes_sem_produto from anon, authenticated;

create or replace function public.compras__chefe_principal() returns uuid
language sql stable security definer set search_path to 'public' as $$
  select id from public.compras_users where role = 'chefe' and ativo order by created_at limit 1
$$;
revoke execute on function public.compras__chefe_principal() from public, anon, authenticated;

-- Recebe uma fatura lida pela função compras-guara. Se todos os artigos já são conhecidos neste fornecedor, importa logo;
-- senão fica 'pendente' para a correspondência (produto e embalagem dos artigos novos).
create or replace function public.compras_guara_receber(p_fat jsonb) returns jsonb
language plpgsql security definer set search_path to 'public', 'extensions' as $function$
declare gid int := nullif(p_fat->>'guara_id','')::int; sid uuid; numk text; l jsonb; novas int := 0; uteis int := 0; r jsonb;
begin
  if gid is null then raise exception 'sem_guara_id'; end if;
  if exists (select 1 from public.compras_guara_faturas where guara_id = gid) then return jsonb_build_object('estado', 'vista'); end if;
  sid := public.compras__fornecedor(p_fat->>'fornecedor_nome');
  numk := lower(regexp_replace(coalesce(p_fat->>'numero',''), '\s', '', 'g'));
  if sid is not null and numk <> '' and exists (select 1 from public.compras_invoices i where i.supplier_id = sid and lower(regexp_replace(coalesce(i.numero,''), '\s', '', 'g')) = numk) then
    insert into public.compras_guara_faturas (guara_id, fornecedor, numero, data, total, estado, dados, tratado_em)
    values (gid, coalesce(p_fat->>'fornecedor_nome',''), coalesce(p_fat->>'numero',''), nullif(p_fat->>'data','')::date, nullif(p_fat->>'total','')::numeric, 'ja_existia', p_fat, now());
    return jsonb_build_object('estado', 'ja_existia');
  end if;
  for l in select * from jsonb_array_elements(coalesce(p_fat->'linhas','[]')) loop
    if nullif(l->>'price','') is null then continue; end if;
    if coalesce(l->>'desc','') ~* '(vasilhame|cau[cç][aã]o)' or coalesce(l->>'desc','') ~* '(^|[^[:alnum:]])(vas|grade)([^[:alnum:]]|$)' then continue; end if;
    uteis := uteis + 1;
    if sid is null or not exists (select 1 from public.compras_offers o where o.supplier_id = sid and lower(o.alias) = lower(l->>'desc')) then novas := novas + 1; end if;
  end loop;
  if uteis > 0 and novas = 0 then
    r := public.compras__import_invoice(public.compras__chefe_principal(), p_fat);
    insert into public.compras_guara_faturas (guara_id, fornecedor, numero, data, total, estado, dados, resultado, tratado_em)
    values (gid, coalesce(p_fat->>'fornecedor_nome',''), coalesce(p_fat->>'numero',''), nullif(p_fat->>'data','')::date, nullif(p_fat->>'total','')::numeric,
            case when r ? 'ignorada' then 'ja_existia' else 'importada' end, p_fat, r, now());
    return jsonb_build_object('estado', case when r ? 'ignorada' then 'ja_existia' else 'importada' end) || r;
  end if;
  insert into public.compras_guara_faturas (guara_id, fornecedor, numero, data, total, estado, dados, resultado)
  values (gid, coalesce(p_fat->>'fornecedor_nome',''), coalesce(p_fat->>'numero',''), nullif(p_fat->>'data','')::date, nullif(p_fat->>'total','')::numeric,
          'pendente', p_fat, jsonb_build_object('linhas', uteis, 'novas', novas));
  return jsonb_build_object('estado', 'pendente', 'linhas', uteis, 'novas', novas);
end $function$;
revoke execute on function public.compras_guara_receber(jsonb) from public, anon, authenticated;
grant execute on function public.compras_guara_receber(jsonb) to service_role;

-- Correspondência (tarefa agendada do Claude): importa uma fatura pendente com as linhas já decididas
-- (cada linha: a original + product_id OU novo_nome/categoria/base_unit, e pack_qty; sem produto nem novo_nome = não é produto).
create or replace function public.compras_guara_importar(p_guara_id int, p_linhas jsonb) returns jsonb
language plpgsql security definer set search_path to 'public', 'extensions' as $function$
declare f public.compras_guara_faturas; r jsonb;
begin
  select * into f from public.compras_guara_faturas where guara_id = p_guara_id for update;
  if not found or f.estado <> 'pendente' then raise exception 'fatura_nao_pendente'; end if;
  r := public.compras__import_invoice(public.compras__chefe_principal(), f.dados || jsonb_build_object('linhas', coalesce(p_linhas, f.dados->'linhas')));
  update public.compras_guara_faturas set estado = case when r ? 'ignorada' then 'ja_existia' else 'importada' end, resultado = r, tratado_em = now()
   where guara_id = p_guara_id;
  return r;
end $function$;
revoke execute on function public.compras_guara_importar(int, jsonb) from public, anon, authenticated;

create or replace function public.compras_guara_ignorar(p_guara_id int, p_motivo text) returns void
language sql security definer set search_path to 'public' as $$
  update public.compras_guara_faturas set estado = 'ignorada', resultado = jsonb_build_object('motivo', p_motivo), tratado_em = now()
   where guara_id = p_guara_id and estado = 'pendente'
$$;
revoke execute on function public.compras_guara_ignorar(int, text) from public, anon, authenticated;

-- Liga um ingrediente do Guará a um produto (fica a regra para as próximas importações)
create or replace function public.compras_ligar_ingrediente(p_ingrediente text, p_product uuid) returns int
language plpgsql security definer set search_path to 'public' as $function$
declare k text := public.compras__norm(p_ingrediente); n int;
begin
  if k = '' or p_product is null then raise exception 'dados_invalidos'; end if;
  insert into public.compras_recipe_aliases (ingrediente, product_id) values (k, p_product)
  on conflict (ingrediente) do update set product_id = excluded.product_id;
  delete from public.compras_ingredientes_sem_produto where ingrediente = k;
  update public.compras_recipe_items set product_id = p_product
   where sub_recipe_guara_id is null and public.compras__norm(ingrediente) = k and product_id is distinct from p_product;
  get diagnostics n = row_count;
  return n;
end $function$;
revoke execute on function public.compras_ligar_ingrediente(text, uuid) from public, anon, authenticated;

create or replace function public.compras_guara_registo(p_modo text, p_info jsonb) returns void
language plpgsql security definer set search_path to 'public' as $function$
begin
  if p_modo = 'faturas' then update public.compras_guara_cfg set faturas_em = now(), faturas = p_info where id;
  elsif p_modo = 'receitas' then update public.compras_guara_cfg set receitas_em = now(), receitas = p_info where id;
  elsif p_modo = 'correspondencia' then update public.compras_guara_cfg set correspondencia_em = now(), correspondencia = p_info where id;
  end if;
end $function$;
revoke execute on function public.compras_guara_registo(text, jsonb) from public, anon, authenticated;
grant execute on function public.compras_guara_registo(text, jsonb) to service_role;
grant execute on function public.compras__import_recipes(jsonb, boolean) to service_role;

-- Faturas: depósitos (SDR) como vasilhame; ofertas a preço 0 só entram no stock; faturas sem artigos com preço ficam de lado.
create or replace function public.compras__save_invoice(p_user uuid, p_inv jsonb) returns jsonb
language plpgsql security definer set search_path to 'public', 'extensions' as $function$
declare
  sid uuid; inv uuid := gen_random_uuid(); l jsonb; pid uuid; k text;
  up numeric; pq numeric; pp numeric; prev public.compras_offers; n int := 0; newmap jsonb := '{}'; d date; v_nif text;
  known_pid uuid; known_pq numeric; is_nc boolean; v_total numeric;
begin
  d := coalesce(nullif(p_inv->>'data','')::date, current_date);
  v_nif := regexp_replace(coalesce(p_inv->>'nif',''), '\D', '', 'g');
  v_total := nullif(p_inv->>'total','')::numeric;
  -- nota de crédito: total negativo ou número começado por NC
  is_nc := coalesce(v_total, 0) < 0 or coalesce(p_inv->>'numero','') ~* '^\s*NC';
  sid := nullif(p_inv->>'supplier_id','')::uuid;
  if sid is null and v_nif <> '' then
    select s.id into sid from public.compras_suppliers s where s.nif = v_nif limit 1;
  end if;
  if sid is null then
    insert into public.compras_suppliers (nome, nif) values (coalesce(nullif(trim(p_inv->>'fornecedor_nome'),''), 'Fornecedor'), v_nif) returning id into sid;
  elsif v_nif <> '' then
    update public.compras_suppliers s set nif = v_nif where s.id = sid and s.nif = '';
  end if;
  insert into public.compras_invoices (id, supplier_id, fornecedor_nome, numero, data, total, linhas, created_by)
  values (inv, sid, (select s.nome from public.compras_suppliers s where s.id = sid), coalesce(p_inv->>'numero',''), d,
          v_total, coalesce(p_inv->'linhas','[]'::jsonb), p_user);
  for l in select * from jsonb_array_elements(coalesce(p_inv->'linhas','[]'::jsonb)) loop
    pp := nullif(l->>'price','')::numeric;
    pq := coalesce(nullif(l->>'pack_qty','')::numeric, 1);
    if pq <= 0 then pq := 1; end if;
    if pp is null or pp < 0 then continue; end if;
    -- vasilhame / caução / depósito não é produto (ex.: "Barril Damm 50L Vas")
    if coalesce(l->>'desc','') ~* '(vasilhame|cau[cç][aã]o|dep[oó]sito)' or coalesce(l->>'desc','') ~* '(^|[^[:alnum:]])(vas|grade)([^[:alnum:]]|$)' then continue; end if;
    pid := nullif(l->>'product_id','')::uuid;
    -- artigo já conhecido neste fornecedor (pela descrição da fatura): usa sempre o mesmo produto e a mesma embalagem.
    -- Se o produto vier escolhido à mão (revisão na app), vale o que o chefe escolheu.
    known_pid := null; known_pq := null;
    if coalesce(l->>'desc','') <> '' then
      select o.product_id, o.pack_qty into known_pid, known_pq from public.compras_offers o
       where o.supplier_id = sid and lower(o.alias) = lower(l->>'desc') limit 1;
    end if;
    if pid is null and known_pid is not null then
      pid := known_pid;
      if known_pq > 0 then pq := known_pq; end if;
    end if;
    up := pp / pq;
    if pid is null then
      k := lower(trim(coalesce(l->>'novo_nome','')));
      if k = '' then continue; end if;
      if newmap ? k then pid := (newmap->>k)::uuid;
      else
        select p.id into pid from public.compras_products p where lower(p.nome) = k limit 1;
        if pid is null then
          insert into public.compras_products (nome, categoria, unidade)
          values (trim(l->>'novo_nome'), coalesce(nullif(l->>'categoria',''),'Outros'),
                  case when l->>'base_unit' in ('un','kg','L') then l->>'base_unit' else 'un' end)
          returning id into pid;
        end if;
        newmap := newmap || jsonb_build_object(k, pid);
      end if;
    end if;
    -- nota de crédito: tira stock e não conta como preço de compra
    if is_nc then
      if nullif(l->>'qty','') is not null then
        insert into public.compras_purchase_lines (invoice_id, product_id, data, qty) values (inv, pid, d, -abs((l->>'qty')::numeric * pq));
      end if;
      n := n + 1;
      continue;
    end if;
    -- oferta (preço 0): entra no stock mas não conta como preço de compra
    if pp = 0 then
      if nullif(l->>'qty','') is not null then
        insert into public.compras_purchase_lines (invoice_id, product_id, data, qty) values (inv, pid, d, (l->>'qty')::numeric * pq);
      end if;
      n := n + 1;
      continue;
    end if;
    insert into public.compras_price_history (product_id, supplier_id, data, unit_price, invoice_id) values (pid, sid, d, up, inv);
    if nullif(l->>'qty','') is not null then
      insert into public.compras_purchase_lines (invoice_id, product_id, data, qty) values (inv, pid, d, (l->>'qty')::numeric * pq);
    end if;
    select * into prev from public.compras_offers o where o.product_id = pid and o.supplier_id = sid;
    if not found then
      insert into public.compras_offers (product_id, supplier_id, alias, codigo, pack_qty, pack_price, unit_price, prev_unit_price, data, invoice_id)
      values (pid, sid, coalesce(l->>'desc',''), coalesce(l->>'codigo',''), pq, pp, up, null, d, inv);
    elsif prev.data is null or d >= prev.data then
      update public.compras_offers o set alias = coalesce(l->>'desc',''), codigo = coalesce(l->>'codigo',''), pack_qty = pq, pack_price = pp,
        unit_price = up, prev_unit_price = case when prev.invoice_id = inv then prev.prev_unit_price when lower(coalesce(prev.alias,'')) <> lower(coalesce(l->>'desc','')) then null when up > 0 and prev.unit_price > 0 and (up / prev.unit_price >= 2.5 or up / prev.unit_price <= 0.4) then null else prev.unit_price end, prev_data = case when prev.invoice_id = inv then prev.prev_data when lower(coalesce(prev.alias,'')) <> lower(coalesce(l->>'desc','')) then null else prev.data end, data = d, invoice_id = inv
       where o.product_id = pid and o.supplier_id = sid;
    end if;
    n := n + 1;
  end loop;
  return jsonb_build_object('invoice_id', inv, 'supplier_id', sid, 'linhas', n, 'nota_credito', is_nc);
end $function$;

create or replace function public.compras_guara_receber(p_fat jsonb) returns jsonb
language plpgsql security definer set search_path to 'public', 'extensions' as $function$
declare gid int := nullif(p_fat->>'guara_id','')::int; sid uuid; numk text; l jsonb; novas int := 0; uteis int := 0; r jsonb;
begin
  if gid is null then raise exception 'sem_guara_id'; end if;
  if exists (select 1 from public.compras_guara_faturas where guara_id = gid) then return jsonb_build_object('estado', 'vista'); end if;
  sid := public.compras__fornecedor(p_fat->>'fornecedor_nome');
  numk := lower(regexp_replace(coalesce(p_fat->>'numero',''), '\s', '', 'g'));
  if sid is not null and numk <> '' and exists (select 1 from public.compras_invoices i where i.supplier_id = sid and lower(regexp_replace(coalesce(i.numero,''), '\s', '', 'g')) = numk) then
    insert into public.compras_guara_faturas (guara_id, fornecedor, numero, data, total, estado, dados, tratado_em)
    values (gid, coalesce(p_fat->>'fornecedor_nome',''), coalesce(p_fat->>'numero',''), nullif(p_fat->>'data','')::date, nullif(p_fat->>'total','')::numeric, 'ja_existia', p_fat, now());
    return jsonb_build_object('estado', 'ja_existia');
  end if;
  for l in select * from jsonb_array_elements(coalesce(p_fat->'linhas','[]')) loop
    if nullif(l->>'price','') is null then continue; end if;
    if coalesce(l->>'desc','') ~* '(vasilhame|cau[cç][aã]o|dep[oó]sito)' or coalesce(l->>'desc','') ~* '(^|[^[:alnum:]])(vas|grade)([^[:alnum:]]|$)' then continue; end if;
    uteis := uteis + 1;
    if sid is null or not exists (select 1 from public.compras_offers o where o.supplier_id = sid and lower(o.alias) = lower(l->>'desc')) then novas := novas + 1; end if;
  end loop;
  if uteis > 0 and novas = 0 then
    r := public.compras__import_invoice(public.compras__chefe_principal(), p_fat);
    insert into public.compras_guara_faturas (guara_id, fornecedor, numero, data, total, estado, dados, resultado, tratado_em)
    values (gid, coalesce(p_fat->>'fornecedor_nome',''), coalesce(p_fat->>'numero',''), nullif(p_fat->>'data','')::date, nullif(p_fat->>'total','')::numeric,
            case when r ? 'ignorada' then 'ja_existia' else 'importada' end, p_fat, r, now());
    return jsonb_build_object('estado', case when r ? 'ignorada' then 'ja_existia' else 'importada' end) || r;
  end if;
  -- sem nenhum artigo com preço (só vasilhame, ou o Guará não leu os preços): fica de lado, com a razão
  insert into public.compras_guara_faturas (guara_id, fornecedor, numero, data, total, estado, dados, resultado, tratado_em)
  values (gid, coalesce(p_fat->>'fornecedor_nome',''), coalesce(p_fat->>'numero',''), nullif(p_fat->>'data','')::date, nullif(p_fat->>'total','')::numeric,
          case when uteis = 0 then 'ignorada' else 'pendente' end, p_fat,
          case when uteis = 0 then jsonb_build_object('motivo', 'sem_artigos_com_preco') else jsonb_build_object('linhas', uteis, 'novas', novas) end,
          case when uteis = 0 then now() end);
  return jsonb_build_object('estado', case when uteis = 0 then 'ignorada' else 'pendente' end, 'linhas', uteis, 'novas', novas);
end $function$;

-- Fornecedor pelo nome: igual, começa pelo outro, ou (com 6+ letras) um contém o outro, por esta ordem
-- (ex.: "W4U - WINE CONCEPT" no Guará = "Wine Concept" na app).
create or replace function public.compras__fornecedor(p_nome text) returns uuid
language sql stable security definer set search_path to 'public', 'extensions' as $function$
  with k as (select lower(regexp_replace(trim(coalesce(p_nome,'')), '[^A-Za-z0-9]', '', 'g')) nk),
  s as (select id, created_at, lower(regexp_replace(nome, '[^A-Za-z0-9]', '', 'g')) sk from public.compras_suppliers)
  select s.id from s, k
   where k.nk <> '' and s.sk <> '' and (s.sk = k.nk
      or (length(k.nk) >= 4 and s.sk like k.nk || '%')
      or (length(s.sk) >= 4 and k.nk like s.sk || '%')
      or (length(k.nk) >= 6 and s.sk like '%' || k.nk || '%')
      or (length(s.sk) >= 6 and k.nk like '%' || s.sk || '%'))
   order by case when s.sk = k.nk then 0 when s.sk like k.nk || '%' or k.nk like s.sk || '%' then 1 else 2 end, s.created_at
   limit 1
$function$;
revoke execute on function public.compras__fornecedor(text) from public, anon, authenticated;

-- Guará sem PC: faturas às 10:30 e receitas às 10:35 (hora de Lisboa). O pg_cron corre em UTC, por isso cada tarefa
-- está marcada às 9h e às 10h UTC e só avança quando em Lisboa são 10h (funciona no horário de inverno e de verão).
create or replace function public.compras__guara_disparar(p_modo text) returns bigint
language sql security definer set search_path to 'public', 'extensions' as $$
  select net.http_post(
    url := 'https://cckgrpmspyurgmbgtjdu.supabase.co/functions/v1/compras-guara',
    body := jsonb_build_object('modo', p_modo),
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-zs-key', (select chave from public.compras_zs_cfg)),
    timeout_milliseconds := 300000);
$$;
revoke execute on function public.compras__guara_disparar(text) from public, anon, authenticated;
select cron.schedule('compras-guara-faturas', '30 9,10 * * *',
  $$select public.compras__guara_disparar('faturas') where extract(hour from now() at time zone 'Europe/Lisbon') = 10$$);
select cron.schedule('compras-guara-receitas', '35 9,10 * * *',
  $$select public.compras__guara_disparar('receitas') where extract(hour from now() at time zone 'Europe/Lisbon') = 10$$);

-- ============================================================
-- Releitura das faturas com os preços pagos (17/11/2026) e preços certos na importação diária
-- ============================================================
-- Faturas do Guará tal como foram lidas pela função compras-guara (modo "releitura"), para comparar e substituir.
create table if not exists public.compras_guara_releitura (
  guara_id int primary key,
  fornecedor text not null default '',
  numero text not null default '',
  data date,
  dados jsonb not null,
  lida_em timestamptz not null default now()
);
alter table public.compras_guara_releitura enable row level security;
revoke all on public.compras_guara_releitura from anon, authenticated;

create or replace function public.compras_guara_releitura_guardar(p_fat jsonb) returns void
language sql security definer set search_path to 'public' as $$
  insert into public.compras_guara_releitura (guara_id, fornecedor, numero, data, dados)
  values ((p_fat->>'guara_id')::int, coalesce(p_fat->>'fornecedor_nome',''), coalesce(p_fat->>'numero',''), nullif(p_fat->>'data','')::date, p_fat)
  on conflict (guara_id) do update set fornecedor = excluded.fornecedor, numero = excluded.numero, data = excluded.data, dados = excluded.dados, lida_em = now()
$$;
revoke execute on function public.compras_guara_releitura_guardar(jsonb) from public, anon, authenticated;
grant execute on function public.compras_guara_releitura_guardar(jsonb) to service_role;

-- Todas as descrições conhecidas de cada artigo por fornecedor (a oferta só guarda a última), para reconhecer variantes
-- como "Ebi Fry 2L (10x25g)" / "Ebi Fry 3L (10x30g)" sem as mandar para a correspondência.
create table if not exists public.compras_offer_aliases (
  supplier_id uuid not null references public.compras_suppliers(id) on delete cascade,
  alias text not null,                 -- descrição da fatura, em minúsculas
  product_id uuid not null references public.compras_products(id) on delete cascade,
  pack_qty numeric not null default 1,
  origem text not null default '',
  atualizado_em timestamptz not null default now(),
  primary key (supplier_id, alias)
);
alter table public.compras_offer_aliases enable row level security;
revoke all on public.compras_offer_aliases from anon, authenticated;

create or replace function public.compras__save_invoice(p_user uuid, p_inv jsonb) returns jsonb
language plpgsql security definer set search_path to 'public', 'extensions' as $function$
declare
  sid uuid; inv uuid := gen_random_uuid(); l jsonb; pid uuid; k text;
  up numeric; pq numeric; pp numeric; prev public.compras_offers; n int := 0; newmap jsonb := '{}'; d date; v_nif text;
  known_pid uuid; known_pq numeric; is_nc boolean; v_total numeric;
begin
  d := coalesce(nullif(p_inv->>'data','')::date, current_date);
  v_nif := regexp_replace(coalesce(p_inv->>'nif',''), '\D', '', 'g');
  v_total := nullif(p_inv->>'total','')::numeric;
  -- nota de crédito: total negativo ou número começado por NC
  is_nc := coalesce(v_total, 0) < 0 or coalesce(p_inv->>'numero','') ~* '^\s*NC';
  sid := nullif(p_inv->>'supplier_id','')::uuid;
  if sid is null and v_nif <> '' then
    select s.id into sid from public.compras_suppliers s where s.nif = v_nif limit 1;
  end if;
  if sid is null then
    insert into public.compras_suppliers (nome, nif) values (coalesce(nullif(trim(p_inv->>'fornecedor_nome'),''), 'Fornecedor'), v_nif) returning id into sid;
  elsif v_nif <> '' then
    update public.compras_suppliers s set nif = v_nif where s.id = sid and s.nif = '';
  end if;
  insert into public.compras_invoices (id, supplier_id, fornecedor_nome, numero, data, total, linhas, created_by)
  values (inv, sid, (select s.nome from public.compras_suppliers s where s.id = sid), coalesce(p_inv->>'numero',''), d,
          v_total, coalesce(p_inv->'linhas','[]'::jsonb), p_user);
  for l in select * from jsonb_array_elements(coalesce(p_inv->'linhas','[]'::jsonb)) loop
    pp := nullif(l->>'price','')::numeric;
    pq := coalesce(nullif(l->>'pack_qty','')::numeric, 1);
    if pq <= 0 then pq := 1; end if;
    if pp is null or pp < 0 then continue; end if;
    -- vasilhame / caução / depósito não é produto (ex.: "Barril Damm 50L Vas")
    if coalesce(l->>'desc','') ~* '(vasilhame|cau[cç][aã]o|dep[oó]sito)' or coalesce(l->>'desc','') ~* '(^|[^[:alnum:]])(vas|grade)([^[:alnum:]]|$)' then continue; end if;
    pid := nullif(l->>'product_id','')::uuid;
    -- artigo já conhecido neste fornecedor (pela descrição da fatura): usa sempre o mesmo produto e a mesma embalagem.
    -- Se o produto vier escolhido à mão (revisão na app), vale o que o chefe escolheu.
    known_pid := null; known_pq := null;
    if coalesce(l->>'desc','') <> '' then
      select o.product_id, o.pack_qty into known_pid, known_pq from public.compras_offers o
       where o.supplier_id = sid and lower(o.alias) = lower(l->>'desc') limit 1;
      -- outras descrições já vistas deste artigo neste fornecedor (ex.: "Ebi Fry 2L" e "Ebi Fry 3L")
      if known_pid is null then
        select a.product_id, a.pack_qty into known_pid, known_pq from public.compras_offer_aliases a
         where a.supplier_id = sid and a.alias = lower(l->>'desc');
      end if;
    end if;
    if pid is null and known_pid is not null then
      pid := known_pid;
      if known_pq > 0 then pq := known_pq; end if;
    end if;
    up := pp / pq;
    if pid is null then
      k := lower(trim(coalesce(l->>'novo_nome','')));
      if k = '' then continue; end if;
      if newmap ? k then pid := (newmap->>k)::uuid;
      else
        select p.id into pid from public.compras_products p where lower(p.nome) = k limit 1;
        if pid is null then
          insert into public.compras_products (nome, categoria, unidade)
          values (trim(l->>'novo_nome'), coalesce(nullif(l->>'categoria',''),'Outros'),
                  case when l->>'base_unit' in ('un','kg','L') then l->>'base_unit' else 'un' end)
          returning id into pid;
        end if;
        newmap := newmap || jsonb_build_object(k, pid);
      end if;
    end if;
    if coalesce(l->>'desc','') <> '' then
      insert into public.compras_offer_aliases (supplier_id, alias, product_id, pack_qty, origem)
      values (sid, lower(l->>'desc'), pid, pq, 'fatura')
      on conflict (supplier_id, alias) do update set product_id = excluded.product_id, pack_qty = excluded.pack_qty, atualizado_em = now();
    end if;
    -- nota de crédito: tira stock e não conta como preço de compra
    if is_nc then
      if nullif(l->>'qty','') is not null then
        insert into public.compras_purchase_lines (invoice_id, product_id, data, qty) values (inv, pid, d, -abs((l->>'qty')::numeric * pq));
      end if;
      n := n + 1;
      continue;
    end if;
    -- oferta (preço 0): entra no stock mas não conta como preço de compra
    if pp = 0 then
      if nullif(l->>'qty','') is not null then
        insert into public.compras_purchase_lines (invoice_id, product_id, data, qty) values (inv, pid, d, (l->>'qty')::numeric * pq);
      end if;
      n := n + 1;
      continue;
    end if;
    insert into public.compras_price_history (product_id, supplier_id, data, unit_price, invoice_id) values (pid, sid, d, up, inv);
    if nullif(l->>'qty','') is not null then
      insert into public.compras_purchase_lines (invoice_id, product_id, data, qty) values (inv, pid, d, (l->>'qty')::numeric * pq);
    end if;
    select * into prev from public.compras_offers o where o.product_id = pid and o.supplier_id = sid;
    if not found then
      insert into public.compras_offers (product_id, supplier_id, alias, codigo, pack_qty, pack_price, unit_price, prev_unit_price, data, invoice_id)
      values (pid, sid, coalesce(l->>'desc',''), coalesce(l->>'codigo',''), pq, pp, up, null, d, inv);
    elsif prev.data is null or d >= prev.data then
      update public.compras_offers o set alias = coalesce(l->>'desc',''), codigo = coalesce(l->>'codigo',''), pack_qty = pq, pack_price = pp,
        unit_price = up, prev_unit_price = case when prev.invoice_id = inv then prev.prev_unit_price when lower(coalesce(prev.alias,'')) <> lower(coalesce(l->>'desc','')) then null when up > 0 and prev.unit_price > 0 and (up / prev.unit_price >= 2.5 or up / prev.unit_price <= 0.4) then null else prev.unit_price end, prev_data = case when prev.invoice_id = inv then prev.prev_data when lower(coalesce(prev.alias,'')) <> lower(coalesce(l->>'desc','')) then null else prev.data end, data = d, invoice_id = inv
       where o.product_id = pid and o.supplier_id = sid;
    end if;
    n := n + 1;
  end loop;
  return jsonb_build_object('invoice_id', inv, 'supplier_id', sid, 'linhas', n, 'nota_credito', is_nc);
end $function$;

-- Desconto habitual de um artigo num fornecedor (preço pago / preço de tabela), aprendido com as faturas do Guará em que
-- o preço pago aparece por linha. Linhas sem desconto nessas faturas contam como 1. Precisa de pelo menos 2 faturas.
-- Se a descrição não tiver histórico, usa o mesmo produto (pelas ofertas / descrições conhecidas do fornecedor).
create or replace function public.compras__guara_desconto_habitual(p_forn text, p_sid uuid, p_desc text, p_excluir int default null) returns numeric
language sql stable security definer set search_path to 'public' as $$
  with h as (
    select g.guara_id, y, bool_or(y ? 'price_tabela') over (partition by g.guara_id) inv_pago
      from public.compras_guara_faturas g, jsonb_array_elements(g.dados->'linhas') y
     where g.fornecedor = p_forn and g.guara_id is distinct from p_excluir and g.data >= current_date - 180
       and coalesce(nullif(g.dados->>'total','')::numeric, 0) > 0),
  r as (select h.guara_id, lower(h.y->>'desc') a,
          case when h.y ? 'price_tabela' then (h.y->>'price')::numeric / nullif((h.y->>'price_tabela')::numeric, 0) else 1 end r
          from h
         where h.inv_pago and nullif(h.y->>'price','') is not null and (h.y->>'price')::numeric > 0
           and not (coalesce(h.y->>'desc','') ~* '(vasilhame|cau[cç][aã]o|dep[oó]sito)' or coalesce(h.y->>'desc','') ~* '(^|[^[:alnum:]])(vas|grade)([^[:alnum:]]|$)')),
  rv as (select * from r where r.r between 0.25 and 1.0),
  pdesc as (select case when count(distinct guara_id) >= 2 then percentile_cont(0.5) within group (order by r) end v from rv where a = lower(p_desc)),
  prod as (select coalesce(
             (select o.product_id from public.compras_offers o where o.supplier_id = p_sid and lower(o.alias) = lower(p_desc) limit 1),
             (select x.product_id from public.compras_offer_aliases x where x.supplier_id = p_sid and x.alias = lower(p_desc))) pid),
  pprod as (select case when count(distinct rv.guara_id) >= 2 then percentile_cont(0.5) within group (order by rv.r) end v
              from rv, prod
             where prod.pid is not null and p_sid is not null
               and prod.pid = coalesce(
                 (select o.product_id from public.compras_offers o where o.supplier_id = p_sid and lower(o.alias) = rv.a limit 1),
                 (select x.product_id from public.compras_offer_aliases x where x.supplier_id = p_sid and x.alias = rv.a)))
  select coalesce((select v from pdesc), (select v from pprod))::numeric
$$;
revoke execute on function public.compras__guara_desconto_habitual(text, uuid, text, int) from public, anon, authenticated;

-- Desconto habitual do fornecedor (todas as linhas com preço pago e tabela), para um "pago" absurdo num artigo sem histórico
create or replace function public.compras__guara_desconto_fornecedor(p_forn text, p_excluir int default null) returns numeric
language sql stable security definer set search_path to 'public' as $$
  with r as (select g.guara_id, (y->>'price')::numeric / nullif((y->>'price_tabela')::numeric, 0) r
               from public.compras_guara_faturas g, jsonb_array_elements(g.dados->'linhas') y
              where g.fornecedor = p_forn and g.guara_id is distinct from p_excluir and g.data >= current_date - 180
                and coalesce(nullif(g.dados->>'total','')::numeric, 0) > 0 and y ? 'price_tabela' and nullif(y->>'price','') is not null)
  select case when count(distinct guara_id) >= 2 then (percentile_cont(0.5) within group (order by r))::numeric end from r where r between 0.25 and 1.0
$$;
revoke execute on function public.compras__guara_desconto_fornecedor(text, int) from public, anon, authenticated;

-- Acerta os preços de uma fatura do Guará antes de entrar na app:
--  * fatura sem preço pago por linha (ex.: FRUSTOCK em que o Guará só leu a tabela, Sumol com desconto no fim da fatura):
--    cada artigo com desconto habitual conhecido fica a tabela x esse desconto (no lugar do desconto repartido por igual);
--  * linha com "pago" muito abaixo do habitual (o Guará já leu mal o pago): tabela x desconto habitual
--    (artigo sem histórico e pago abaixo de 40% da tabela: desconto habitual do fornecedor).
-- O preço lido fica em price_guara e o motivo em price_estimado.
create or replace function public.compras__guara_precos(p_fat jsonb) returns jsonb
language plpgsql security definer set search_path to 'public' as $$
declare
  forn text := coalesce(p_fat->>'fornecedor_nome', '');
  gid int := nullif(p_fat->>'guara_id','')::int;
  sid uuid; tem_pago boolean; saida jsonb := '[]'; l jsonb; base numeric; r numeric; rf numeric; rf_lido boolean := false;
  p numeric; pt numeric; n int := 0;
begin
  if coalesce(nullif(p_fat->>'total','')::numeric, 0) <= 0 or forn = '' then return p_fat; end if;
  sid := public.compras__fornecedor(forn);
  select coalesce(bool_or(y ? 'price_tabela'), false) into tem_pago from jsonb_array_elements(coalesce(p_fat->'linhas', '[]')) y;
  for l in select * from jsonb_array_elements(coalesce(p_fat->'linhas', '[]')) loop
    p := nullif(l->>'price','')::numeric; pt := nullif(l->>'price_tabela','')::numeric; r := null;
    if p is not null and p > 0 and not (coalesce(l->>'desc','') ~* '(vasilhame|cau[cç][aã]o|dep[oó]sito)' or coalesce(l->>'desc','') ~* '(^|[^[:alnum:]])(vas|grade)([^[:alnum:]]|$)') then
      r := public.compras__guara_desconto_habitual(forn, sid, l->>'desc', gid);
      if r is null and pt > 0 and p / pt < 0.4 then
        if not rf_lido then rf := public.compras__guara_desconto_fornecedor(forn, gid); rf_lido := true; end if;
        r := rf;
      end if;
    end if;
    if r is not null and not tem_pago then
      base := coalesce(nullif(l->>'price_bruto','')::numeric, p);
      if abs(base * r - p) > 0.005 then
        l := l || jsonb_build_object('price', round(base * r, 4), 'price_guara', p, 'price_estimado', 'desconto_artigo');
        n := n + 1;
      end if;
    elsif r is not null and pt > 0 and p / pt < 0.6 * r then
      l := l || jsonb_build_object('price', round(pt * r, 4), 'price_guara', p, 'price_estimado', 'pago_suspeito');
      n := n + 1;
    end if;
    saida := saida || jsonb_build_array(l);
  end loop;
  if n = 0 then return p_fat; end if;
  return p_fat || jsonb_build_object('linhas', saida, 'precos_estimados', n);
end $$;
revoke execute on function public.compras__guara_precos(jsonb) from public, anon, authenticated;

-- A importação diária acerta os preços antes de decidir/importar (o que fica guardado em dados já vem acertado)
-- e reconhece os artigos também pelas descrições antigas (compras_offer_aliases).
create or replace function public.compras_guara_receber(p_fat jsonb) returns jsonb
language plpgsql security definer set search_path to 'public', 'extensions' as $function$
declare gid int := nullif(p_fat->>'guara_id','')::int; sid uuid; numk text; l jsonb; novas int := 0; uteis int := 0; r jsonb;
begin
  if gid is null then raise exception 'sem_guara_id'; end if;
  if exists (select 1 from public.compras_guara_faturas where guara_id = gid) then return jsonb_build_object('estado', 'vista'); end if;
  p_fat := public.compras__guara_precos(p_fat);
  sid := public.compras__fornecedor(p_fat->>'fornecedor_nome');
  numk := lower(regexp_replace(coalesce(p_fat->>'numero',''), '\s', '', 'g'));
  if sid is not null and numk <> '' and exists (select 1 from public.compras_invoices i where i.supplier_id = sid and lower(regexp_replace(coalesce(i.numero,''), '\s', '', 'g')) = numk) then
    insert into public.compras_guara_faturas (guara_id, fornecedor, numero, data, total, estado, dados, tratado_em)
    values (gid, coalesce(p_fat->>'fornecedor_nome',''), coalesce(p_fat->>'numero',''), nullif(p_fat->>'data','')::date, nullif(p_fat->>'total','')::numeric, 'ja_existia', p_fat, now());
    return jsonb_build_object('estado', 'ja_existia');
  end if;
  for l in select * from jsonb_array_elements(coalesce(p_fat->'linhas','[]')) loop
    if nullif(l->>'price','') is null then continue; end if;
    if coalesce(l->>'desc','') ~* '(vasilhame|cau[cç][aã]o|dep[oó]sito)' or coalesce(l->>'desc','') ~* '(^|[^[:alnum:]])(vas|grade)([^[:alnum:]]|$)' then continue; end if;
    uteis := uteis + 1;
    if sid is null or (not exists (select 1 from public.compras_offers o where o.supplier_id = sid and lower(o.alias) = lower(l->>'desc'))
                       and not exists (select 1 from public.compras_offer_aliases a where a.supplier_id = sid and a.alias = lower(l->>'desc'))) then novas := novas + 1; end if;
  end loop;
  if uteis > 0 and novas = 0 then
    r := public.compras__import_invoice(public.compras__chefe_principal(), p_fat);
    insert into public.compras_guara_faturas (guara_id, fornecedor, numero, data, total, estado, dados, resultado, tratado_em)
    values (gid, coalesce(p_fat->>'fornecedor_nome',''), coalesce(p_fat->>'numero',''), nullif(p_fat->>'data','')::date, nullif(p_fat->>'total','')::numeric,
            case when r ? 'ignorada' then 'ja_existia' else 'importada' end, p_fat, r, now());
    return jsonb_build_object('estado', case when r ? 'ignorada' then 'ja_existia' else 'importada' end) || r;
  end if;
  insert into public.compras_guara_faturas (guara_id, fornecedor, numero, data, total, estado, dados, resultado, tratado_em)
  values (gid, coalesce(p_fat->>'fornecedor_nome',''), coalesce(p_fat->>'numero',''), nullif(p_fat->>'data','')::date, nullif(p_fat->>'total','')::numeric,
          case when uteis = 0 then 'ignorada' else 'pendente' end, p_fat,
          case when uteis = 0 then jsonb_build_object('motivo', 'sem_artigos_com_preco') else jsonb_build_object('linhas', uteis, 'novas', novas) end,
          case when uteis = 0 then now() end);
  return jsonb_build_object('estado', case when uteis = 0 then 'ignorada' else 'pendente' end, 'linhas', uteis, 'novas', novas);
end $function$;
revoke execute on function public.compras_guara_receber(jsonb) from public, anon, authenticated;
grant execute on function public.compras_guara_receber(jsonb) to service_role;

-- Tabelas de trabalho da releitura de 17/11 (não fazem parte da app; apagar quando já não forem precisas):
-- compras_bak_invoices, compras_bak_price_history, compras_bak_purchase_lines, compras_bak_offers, compras_bak_guara_faturas
-- (cópias de antes), compras_releitura_old, compras_releitura_linhas, compras_releitura_log.


-- ============================================================
-- 17/11: o vasilhame e os depósitos (grades, barris, cilindro CO2, depósito SDR) passam a ser produto (categoria Bebidas):
-- entram nas encomendas e no stock; as notas de crédito de vasilhame (ZCD da Sumol) tiram stock.
-- Produtos criados nesse dia (carnes da Meta para o staff, limpeza da Abreu, talheres da NB Machado, snacks, licores, etc.)
-- e as descrições respetivas estão em compras_offer_aliases (origem 'manual').
-- ============================================================
-- O vasilhame e os depósitos também são produto
create or replace function public.compras__save_invoice(p_user uuid, p_inv jsonb) returns jsonb
language plpgsql security definer set search_path to 'public', 'extensions' as $function$
declare
  sid uuid; inv uuid := gen_random_uuid(); l jsonb; pid uuid; k text;
  up numeric; pq numeric; pp numeric; prev public.compras_offers; n int := 0; newmap jsonb := '{}'; d date; v_nif text;
  known_pid uuid; known_pq numeric; is_nc boolean; v_total numeric;
begin
  d := coalesce(nullif(p_inv->>'data','')::date, current_date);
  v_nif := regexp_replace(coalesce(p_inv->>'nif',''), '\D', '', 'g');
  v_total := nullif(p_inv->>'total','')::numeric;
  -- nota de crédito: total negativo ou número começado por NC
  is_nc := coalesce(v_total, 0) < 0 or coalesce(p_inv->>'numero','') ~* '^\s*NC';
  sid := nullif(p_inv->>'supplier_id','')::uuid;
  if sid is null and v_nif <> '' then
    select s.id into sid from public.compras_suppliers s where s.nif = v_nif limit 1;
  end if;
  if sid is null then
    insert into public.compras_suppliers (nome, nif) values (coalesce(nullif(trim(p_inv->>'fornecedor_nome'),''), 'Fornecedor'), v_nif) returning id into sid;
  elsif v_nif <> '' then
    update public.compras_suppliers s set nif = v_nif where s.id = sid and s.nif = '';
  end if;
  insert into public.compras_invoices (id, supplier_id, fornecedor_nome, numero, data, total, linhas, created_by)
  values (inv, sid, (select s.nome from public.compras_suppliers s where s.id = sid), coalesce(p_inv->>'numero',''), d,
          v_total, coalesce(p_inv->'linhas','[]'::jsonb), p_user);
  for l in select * from jsonb_array_elements(coalesce(p_inv->'linhas','[]'::jsonb)) loop
    pp := nullif(l->>'price','')::numeric;
    pq := coalesce(nullif(l->>'pack_qty','')::numeric, 1);
    if pq <= 0 then pq := 1; end if;
    if pp is null or pp < 0 then continue; end if;
    pid := nullif(l->>'product_id','')::uuid;
    -- artigo já conhecido neste fornecedor (pela descrição da fatura): usa sempre o mesmo produto e a mesma embalagem.
    -- Se o produto vier escolhido à mão (revisão na app), vale o que o chefe escolheu.
    known_pid := null; known_pq := null;
    if coalesce(l->>'desc','') <> '' then
      select o.product_id, o.pack_qty into known_pid, known_pq from public.compras_offers o
       where o.supplier_id = sid and lower(o.alias) = lower(l->>'desc') limit 1;
      -- outras descrições já vistas deste artigo neste fornecedor (ex.: "Ebi Fry 2L" e "Ebi Fry 3L")
      if known_pid is null then
        select a.product_id, a.pack_qty into known_pid, known_pq from public.compras_offer_aliases a
         where a.supplier_id = sid and a.alias = lower(l->>'desc');
      end if;
    end if;
    if pid is null and known_pid is not null then
      pid := known_pid;
      if known_pq > 0 then pq := known_pq; end if;
    end if;
    up := pp / pq;
    if pid is null then
      k := lower(trim(coalesce(l->>'novo_nome','')));
      if k = '' then continue; end if;
      if newmap ? k then pid := (newmap->>k)::uuid;
      else
        select p.id into pid from public.compras_products p where lower(p.nome) = k limit 1;
        if pid is null then
          insert into public.compras_products (nome, categoria, unidade)
          values (trim(l->>'novo_nome'), coalesce(nullif(l->>'categoria',''),'Outros'),
                  case when l->>'base_unit' in ('un','kg','L') then l->>'base_unit' else 'un' end)
          returning id into pid;
        end if;
        newmap := newmap || jsonb_build_object(k, pid);
      end if;
    end if;
    if coalesce(l->>'desc','') <> '' then
      insert into public.compras_offer_aliases (supplier_id, alias, product_id, pack_qty, origem)
      values (sid, lower(l->>'desc'), pid, pq, 'fatura')
      on conflict (supplier_id, alias) do update set product_id = excluded.product_id, pack_qty = excluded.pack_qty, atualizado_em = now();
    end if;
    -- nota de crédito: tira stock e não conta como preço de compra
    if is_nc then
      if nullif(l->>'qty','') is not null then
        insert into public.compras_purchase_lines (invoice_id, product_id, data, qty) values (inv, pid, d, -abs((l->>'qty')::numeric * pq));
      end if;
      n := n + 1;
      continue;
    end if;
    -- oferta (preço 0): entra no stock mas não conta como preço de compra
    if pp = 0 then
      if nullif(l->>'qty','') is not null then
        insert into public.compras_purchase_lines (invoice_id, product_id, data, qty) values (inv, pid, d, (l->>'qty')::numeric * pq);
      end if;
      n := n + 1;
      continue;
    end if;
    insert into public.compras_price_history (product_id, supplier_id, data, unit_price, invoice_id) values (pid, sid, d, up, inv);
    if nullif(l->>'qty','') is not null then
      insert into public.compras_purchase_lines (invoice_id, product_id, data, qty) values (inv, pid, d, (l->>'qty')::numeric * pq);
    end if;
    select * into prev from public.compras_offers o where o.product_id = pid and o.supplier_id = sid;
    if not found then
      insert into public.compras_offers (product_id, supplier_id, alias, codigo, pack_qty, pack_price, unit_price, prev_unit_price, data, invoice_id)
      values (pid, sid, coalesce(l->>'desc',''), coalesce(l->>'codigo',''), pq, pp, up, null, d, inv);
    elsif prev.data is null or d >= prev.data then
      update public.compras_offers o set alias = coalesce(l->>'desc',''), codigo = coalesce(l->>'codigo',''), pack_qty = pq, pack_price = pp,
        unit_price = up, prev_unit_price = case when prev.invoice_id = inv then prev.prev_unit_price when lower(coalesce(prev.alias,'')) <> lower(coalesce(l->>'desc','')) then null when up > 0 and prev.unit_price > 0 and (up / prev.unit_price >= 2.5 or up / prev.unit_price <= 0.4) then null else prev.unit_price end, prev_data = case when prev.invoice_id = inv then prev.prev_data when lower(coalesce(prev.alias,'')) <> lower(coalesce(l->>'desc','')) then null else prev.data end, data = d, invoice_id = inv
       where o.product_id = pid and o.supplier_id = sid;
    end if;
    n := n + 1;
  end loop;
  return jsonb_build_object('invoice_id', inv, 'supplier_id', sid, 'linhas', n, 'nota_credito', is_nc);
end $function$;

-- Importação diária: o vasilhame conta como artigo (entra se for conhecido, senão vai para a correspondência)
create or replace function public.compras_guara_receber(p_fat jsonb) returns jsonb
language plpgsql security definer set search_path to 'public', 'extensions' as $function$
declare gid int := nullif(p_fat->>'guara_id','')::int; sid uuid; numk text; l jsonb; novas int := 0; uteis int := 0; r jsonb;
begin
  if gid is null then raise exception 'sem_guara_id'; end if;
  if exists (select 1 from public.compras_guara_faturas where guara_id = gid) then return jsonb_build_object('estado', 'vista'); end if;
  p_fat := public.compras__guara_precos(p_fat);
  sid := public.compras__fornecedor(p_fat->>'fornecedor_nome');
  numk := lower(regexp_replace(coalesce(p_fat->>'numero',''), '\s', '', 'g'));
  if sid is not null and numk <> '' and exists (select 1 from public.compras_invoices i where i.supplier_id = sid and lower(regexp_replace(coalesce(i.numero,''), '\s', '', 'g')) = numk) then
    insert into public.compras_guara_faturas (guara_id, fornecedor, numero, data, total, estado, dados, tratado_em)
    values (gid, coalesce(p_fat->>'fornecedor_nome',''), coalesce(p_fat->>'numero',''), nullif(p_fat->>'data','')::date, nullif(p_fat->>'total','')::numeric, 'ja_existia', p_fat, now());
    return jsonb_build_object('estado', 'ja_existia');
  end if;
  for l in select * from jsonb_array_elements(coalesce(p_fat->'linhas','[]')) loop
    if nullif(l->>'price','') is null then continue; end if;
    uteis := uteis + 1;
    if sid is null or (not exists (select 1 from public.compras_offers o where o.supplier_id = sid and lower(o.alias) = lower(l->>'desc'))
                       and not exists (select 1 from public.compras_offer_aliases a where a.supplier_id = sid and a.alias = lower(l->>'desc'))) then novas := novas + 1; end if;
  end loop;
  if uteis > 0 and novas = 0 then
    r := public.compras__import_invoice(public.compras__chefe_principal(), p_fat);
    insert into public.compras_guara_faturas (guara_id, fornecedor, numero, data, total, estado, dados, resultado, tratado_em)
    values (gid, coalesce(p_fat->>'fornecedor_nome',''), coalesce(p_fat->>'numero',''), nullif(p_fat->>'data','')::date, nullif(p_fat->>'total','')::numeric,
            case when r ? 'ignorada' then 'ja_existia' else 'importada' end, p_fat, r, now());
    return jsonb_build_object('estado', case when r ? 'ignorada' then 'ja_existia' else 'importada' end) || r;
  end if;
  insert into public.compras_guara_faturas (guara_id, fornecedor, numero, data, total, estado, dados, resultado, tratado_em)
  values (gid, coalesce(p_fat->>'fornecedor_nome',''), coalesce(p_fat->>'numero',''), nullif(p_fat->>'data','')::date, nullif(p_fat->>'total','')::numeric,
          case when uteis = 0 then 'ignorada' else 'pendente' end, p_fat,
          case when uteis = 0 then jsonb_build_object('motivo', 'sem_artigos_com_preco') else jsonb_build_object('linhas', uteis, 'novas', novas) end,
          case when uteis = 0 then now() end);
  return jsonb_build_object('estado', case when uteis = 0 then 'ignorada' else 'pendente' end, 'linhas', uteis, 'novas', novas);
end $function$;

-- ============================================================
-- Back office (página /backoffice): só o dono entra (compras_settings.dono_id).
-- Lá só se mudam nomes: o nome do produto (o que os colaboradores veem) e o nome que vai na mensagem
-- da encomenda de cada fornecedor (compras_offers.nome_encomenda; a descrição da fatura, alias, não se toca
-- porque é por ela que as faturas são reconhecidas). O resto são relatórios de preços.
-- ============================================================
alter table public.compras_settings add column if not exists dono_id uuid references public.compras_users(id) on delete set null;
update public.compras_settings set dono_id = public.compras__chefe_principal() where dono_id is null;
alter table public.compras_offers add column if not exists nome_encomenda text not null default '';

create or replace function public.compras__dono(p_token text) returns public.compras_users
language plpgsql security definer set search_path to 'public', 'extensions' as $$
declare u public.compras_users;
begin
  u := public.compras__chefe(p_token);
  if u.id is distinct from (select dono_id from public.compras_settings where id = 1) then raise exception 'so_dono'; end if;
  return u;
end $$;
revoke execute on function public.compras__dono(text) from public, anon, authenticated;

-- A app passa a receber o nome na encomenda de cada oferta (para a mensagem ao fornecedor)
create or replace function public.compras_catalog(p_token text) returns jsonb
language plpgsql security definer set search_path to 'public', 'extensions' as $function$
declare u public.compras_users;
begin
  u := public.compras__user(p_token);
  return jsonb_build_object(
    'restaurante', (select restaurante from public.compras_settings where id = 1),
    'suppliers', coalesce((select jsonb_agg(jsonb_build_object('id', s.id, 'nome', s.nome, 'telefone', s.telefone, 'dias', s.dias, 'nif', s.nif, 'minimo', s.minimo, 'via', s.via) order by lower(s.nome)) from public.compras_suppliers s), '[]'),
    'products', coalesce((select jsonb_agg(jsonb_build_object(
        'id', p.id, 'nome', p.nome, 'categoria', p.categoria, 'unidade', p.unidade, 'setores', to_jsonb(p.setores),
        'offers', coalesce((select jsonb_agg(jsonb_build_object('supplier_id', o.supplier_id, 'alias', o.alias, 'nome_encomenda', o.nome_encomenda, 'codigo', o.codigo,
             'pack_qty', o.pack_qty, 'pack_price', o.pack_price, 'unit_price', o.unit_price, 'prev_unit_price', o.prev_unit_price, 'prev_data', o.prev_data, 'data', o.data)
             order by o.unit_price) from public.compras_offers o where o.product_id = p.id), '[]')
      ) order by lower(p.nome)) from public.compras_products p), '[]')
  );
end $function$;

create or replace function public.compras_bo_entrar(p_token text) returns jsonb
language plpgsql security definer set search_path to 'public', 'extensions' as $$
declare u public.compras_users;
begin
  u := public.compras__dono(p_token);
  return jsonb_build_object('nome', u.nome, 'restaurante', (select restaurante from public.compras_settings where id = 1));
end $$;

-- Produtos com as ofertas de cada fornecedor e quantos pratos vendidos os usam
create or replace function public.compras_bo_produtos(p_token text) returns jsonb
language plpgsql security definer set search_path to 'public', 'extensions' as $$
begin
  perform public.compras__dono(p_token);
  return coalesce((
    with vend as (select distinct recipe_guara_id g from public.compras_zs_items where recipe_guara_id is not null and not ignorar),
    pr as (select u.product_id, count(distinct u.root) n from public.compras__recipe_usage() u join vend on vend.g = u.root group by 1)
    select jsonb_agg(jsonb_build_object('id', p.id, 'nome', p.nome, 'categoria', p.categoria, 'unidade', p.unidade,
      'pratos', coalesce(pr.n, 0),
      'ofertas', coalesce((select jsonb_agg(jsonb_build_object('supplier_id', o.supplier_id, 'fornecedor', s.nome, 'alias', o.alias,
           'nome_encomenda', o.nome_encomenda, 'codigo', o.codigo, 'pack_qty', o.pack_qty, 'pack_price', o.pack_price,
           'unit_price', o.unit_price, 'data', o.data) order by o.unit_price)
         from public.compras_offers o join public.compras_suppliers s on s.id = o.supplier_id where o.product_id = p.id), '[]'))
      order by lower(p.nome))
    from public.compras_products p left join pr on pr.product_id = p.id), '[]');
end $$;

-- Mudar o nome do produto (o que os colaboradores veem). O nome antigo fica como sinónimo nas receitas do Guará,
-- para os ingredientes continuarem ligados ao produto.
create or replace function public.compras_bo_nome_produto(p_token text, p_id uuid, p_nome text) returns jsonb
language plpgsql security definer set search_path to 'public', 'extensions' as $$
declare v text; antigo text;
begin
  perform public.compras__dono(p_token);
  v := btrim(regexp_replace(coalesce(p_nome, ''), '\s+', ' ', 'g'));
  if v = '' then raise exception 'nome_vazio'; end if;
  if length(v) > 80 then raise exception 'nome_longo'; end if;
  select nome into antigo from public.compras_products where id = p_id;
  if not found then raise exception 'produto_nao_existe'; end if;
  if exists (select 1 from public.compras_products where lower(nome) = lower(v) and id <> p_id) then raise exception 'nome_repetido'; end if;
  if public.compras__norm(antigo) <> '' and public.compras__norm(antigo) <> public.compras__norm(v) then
    insert into public.compras_recipe_aliases (ingrediente, product_id) values (public.compras__norm(antigo), p_id) on conflict (ingrediente) do nothing;
  end if;
  update public.compras_products set nome = v where id = p_id;
  return jsonb_build_object('id', p_id, 'nome', v);
end $$;

-- Mudar o nome que vai na mensagem da encomenda a um fornecedor (vazio = volta à descrição da fatura)
create or replace function public.compras_bo_nome_encomenda(p_token text, p_product uuid, p_supplier uuid, p_nome text) returns jsonb
language plpgsql security definer set search_path to 'public', 'extensions' as $$
declare v text;
begin
  perform public.compras__dono(p_token);
  v := btrim(regexp_replace(coalesce(p_nome, ''), '\s+', ' ', 'g'));
  if length(v) > 120 then raise exception 'nome_longo'; end if;
  update public.compras_offers set nome_encomenda = v where product_id = p_product and supplier_id = p_supplier;
  if not found then raise exception 'oferta_nao_existe'; end if;
  return jsonb_build_object('product_id', p_product, 'supplier_id', p_supplier, 'nome_encomenda', v);
end $$;

-- Linhas de fatura com preço estimado (o Guará não mostrou o pago, ou mostrou-o mal), por fatura e produto
create or replace function public.compras__precos_estimados() returns table(invoice_id uuid, product_id uuid, motivo text)
language sql stable security definer set search_path to 'public' as $$
  select i.id, coalesce(nullif(y->>'product_id','')::uuid,
           (select o.product_id from public.compras_offers o where o.supplier_id = i.supplier_id and lower(o.alias) = lower(y->>'desc') limit 1),
           (select a.product_id from public.compras_offer_aliases a where a.supplier_id = i.supplier_id and a.alias = lower(y->>'desc'))),
         y->>'price_estimado'
    from public.compras_invoices i, jsonb_array_elements(i.linhas) y
   where y ? 'price_estimado'
$$;
revoke execute on function public.compras__precos_estimados() from public, anon, authenticated;

-- Subidas e descidas de preço (por unidade base e por fornecedor) entre duas datas
create or replace function public.compras_bo_precos(p_token text, p_de date, p_ate date) returns jsonb
language plpgsql security definer set search_path to 'public', 'extensions' as $$
begin
  perform public.compras__dono(p_token);
  return coalesce((
    with est as (select * from public.compras__precos_estimados()),
    ph as (select h.product_id, h.supplier_id, h.invoice_id, h.data, avg(h.unit_price) u, min(h.id) id
             from public.compras_price_history h group by 1, 2, 3, 4),
    seq as (select ph.*, lag(u) over w pu, lag(data) over w pd, lag(invoice_id) over w pinv
              from ph window w as (partition by product_id, supplier_id order by data, id)),
    ev as (select * from seq where pu > 0 and abs(u / pu - 1) >= 0.005 and data between p_de and p_ate),
    qtd as (select pl.product_id, i.supplier_id, sum(pl.qty) q from public.compras_purchase_lines pl join public.compras_invoices i on i.id = pl.invoice_id
             where pl.data > p_ate - 90 and pl.data <= p_ate and pl.qty > 0 group by 1, 2),
    vend as (select distinct recipe_guara_id g from public.compras_zs_items where recipe_guara_id is not null and not ignorar),
    pr as (select u.product_id, count(distinct u.root) n from public.compras__recipe_usage() u join vend on vend.g = u.root group by 1)
    select jsonb_agg(jsonb_build_object(
        'product_id', ev.product_id, 'produto', p.nome, 'categoria', p.categoria, 'unidade', p.unidade,
        'supplier_id', ev.supplier_id, 'fornecedor', s.nome, 'data', ev.data, 'data_anterior', ev.pd, 'numero', i.numero,
        'preco', round(ev.u, 4), 'preco_anterior', round(ev.pu, 4), 'var_pct', round((ev.u / ev.pu - 1) * 100, 1),
        'qtd_fatura', (select sum(pl.qty) from public.compras_purchase_lines pl where pl.invoice_id = ev.invoice_id and pl.product_id = ev.product_id),
        'qtd_mes', round(coalesce(q.q, 0) / 3, 3),
        'estimado', exists (select 1 from est where est.invoice_id = ev.invoice_id and est.product_id = ev.product_id),
        'estimado_anterior', exists (select 1 from est where est.invoice_id = ev.pinv and est.product_id = ev.product_id),
        'pratos', coalesce(pr.n, 0))
      order by ev.data desc, abs(ev.u / ev.pu - 1) desc)
    from ev join public.compras_products p on p.id = ev.product_id join public.compras_suppliers s on s.id = ev.supplier_id
    join public.compras_invoices i on i.id = ev.invoice_id
    left join qtd q on q.product_id = ev.product_id and q.supplier_id = ev.supplier_id
    left join pr on pr.product_id = ev.product_id), '[]');
end $$;

-- Um produto: histórico de preços (faturas) e pratos vendidos que o usam, com o custo da dose
create or replace function public.compras_bo_produto(p_token text, p_id uuid) returns jsonb
language plpgsql security definer set search_path to 'public', 'extensions' as $$
declare r jsonb;
begin
  perform public.compras__dono(p_token);
  with est as (select * from public.compras__precos_estimados() e where e.product_id = p_id),
  hist as (select h.invoice_id, h.supplier_id, h.data, avg(h.unit_price) u, min(h.id) id from public.compras_price_history h where h.product_id = p_id group by 1, 2, 3),
  ult as (select * from hist order by data desc, id desc limit 1),
  ant as (select h.* from hist h, ult where h.supplier_id = ult.supplier_id and h.data < ult.data order by h.data desc, h.id desc limit 1),
  use as (select * from public.compras__recipe_usage()),
  preco as (select distinct on (product_id) product_id, unit_price from public.compras_price_history order by product_id, data desc, id desc),
  vend as (select z.recipe_guara_id g, sum(s.qtd * z.fator) q from public.compras_sales s join public.compras_zs_items z on z.codigo = s.codigo
            where s.dia > current_date - 30 and z.recipe_guara_id is not null and not z.ignorar group by 1),
  mapeadas as (select distinct recipe_guara_id g from public.compras_zs_items where recipe_guara_id is not null and not ignorar),
  pratos as (select r.guara_id, r.nome, r.preco_venda pvp, u.qty qtd_produto,
               (select sum(u2.qty * coalesce(pc.unit_price, 0)) from use u2 left join preco pc on pc.product_id = u2.product_id where u2.root = r.guara_id) custo,
               (select count(*) from use u2 left join preco pc on pc.product_id = u2.product_id where u2.root = r.guara_id and pc.unit_price is null) sem_preco,
               coalesce(v.q, 0) vendidos_30d
               from use u join public.compras_recipes r on r.guara_id = u.root join mapeadas m on m.g = r.guara_id left join vend v on v.g = r.guara_id
              where u.product_id = p_id)
  select jsonb_build_object(
    'produto', (select jsonb_build_object('id', p.id, 'nome', p.nome, 'categoria', p.categoria, 'unidade', p.unidade) from public.compras_products p where p.id = p_id),
    'preco_atual', (select u from ult), 'preco_anterior', (select u from ant), 'data_atual', (select data from ult), 'data_anterior', (select data from ant),
    'historico', coalesce((select jsonb_agg(jsonb_build_object('data', h.data, 'fornecedor', s.nome, 'supplier_id', h.supplier_id, 'numero', i.numero,
        'preco', round(h.u, 4), 'qtd', (select sum(pl.qty) from public.compras_purchase_lines pl where pl.invoice_id = h.invoice_id and pl.product_id = p_id),
        'estimado', exists (select 1 from est where est.invoice_id = h.invoice_id)) order by h.data, h.id)
      from hist h join public.compras_suppliers s on s.id = h.supplier_id join public.compras_invoices i on i.id = h.invoice_id), '[]'),
    'pratos', coalesce((select jsonb_agg(jsonb_build_object('guara_id', guara_id, 'nome', nome, 'pvp', pvp, 'qtd_produto', round(qtd_produto, 5),
        'custo', round(custo, 4), 'sem_preco', sem_preco, 'vendidos_30d', vendidos_30d) order by vendidos_30d desc, nome) from pratos), '[]'))
  into r;
  return r;
end $$;

-- Juntar produtos (também usado pelo "Juntar com" da app): leva as descrições das faturas (ofertas e
-- compras_offer_aliases), o nome na encomenda, o nome antigo como sinónimo nas receitas e as encomendas.
-- 17/11: "Picado hambúrguer" (PICADO E HAMBUR) junto em "Carne picada para hambúrguer" (PICADO E HAMBURGUER).
create or replace function public.compras__merge_products(p_from uuid, p_into uuid) returns void
language plpgsql security definer set search_path to 'public', 'extensions' as $function$
declare o public.compras_offers; cur public.compras_offers; fs text[]; antigo text;
begin
  if p_from = p_into then return; end if;
  select setores, nome into fs, antigo from public.compras_products where id = p_from;
  if not found then raise exception 'produto_nao_existe'; end if;
  update public.compras_products set setores = case when cardinality(setores) = 0 or cardinality(coalesce(fs,'{}')) = 0 then '{}' else public.compras__setores(setores || fs) end where id = p_into;
  update public.compras_offer_aliases set product_id = p_into where product_id = p_from;
  for o in select * from public.compras_offers where product_id = p_from loop
    if coalesce(o.alias,'') <> '' then
      insert into public.compras_offer_aliases (supplier_id, alias, product_id, pack_qty, origem)
      values (o.supplier_id, lower(o.alias), p_into, o.pack_qty, 'juntar')
      on conflict (supplier_id, alias) do update set product_id = excluded.product_id, pack_qty = excluded.pack_qty, atualizado_em = now();
    end if;
    select * into cur from public.compras_offers where product_id = p_into and supplier_id = o.supplier_id;
    if not found then
      insert into public.compras_offers (product_id, supplier_id, alias, codigo, pack_qty, pack_price, unit_price, prev_unit_price, data, invoice_id, nome_encomenda)
      values (p_into, o.supplier_id, o.alias, o.codigo, o.pack_qty, o.pack_price, o.unit_price, o.prev_unit_price, o.data, o.invoice_id, o.nome_encomenda);
    else
      if coalesce(o.data, '1900-01-01'::date) > coalesce(cur.data, '1900-01-01'::date) then
        update public.compras_offers set alias = o.alias, codigo = o.codigo, pack_qty = o.pack_qty, pack_price = o.pack_price, unit_price = o.unit_price,
          prev_unit_price = cur.unit_price, data = o.data, invoice_id = o.invoice_id where product_id = p_into and supplier_id = o.supplier_id;
      end if;
      if coalesce(cur.nome_encomenda, '') = '' and coalesce(o.nome_encomenda, '') <> '' then
        update public.compras_offers set nome_encomenda = o.nome_encomenda where product_id = p_into and supplier_id = o.supplier_id;
      end if;
    end if;
  end loop;
  update public.compras_price_history set product_id = p_into where product_id = p_from;
  update public.compras_purchase_lines set product_id = p_into where product_id = p_from;
  update public.compras_recipe_items set product_id = p_into where product_id = p_from;
  update public.compras_recipe_aliases set product_id = p_into where product_id = p_from;
  if public.compras__norm(antigo) <> '' then
    insert into public.compras_recipe_aliases (ingrediente, product_id) values (public.compras__norm(antigo), p_into) on conflict (ingrediente) do nothing;
  end if;
  update public.compras_zs_items set product_id = p_into where product_id = p_from;
  insert into public.compras_stock_count_lines (count_id, product_id, setor, qty, updated_by, updated_at)
    select count_id, p_into, setor, qty, updated_by, updated_at from public.compras_stock_count_lines where product_id = p_from
    on conflict (count_id, product_id, setor) do update set qty = public.compras_stock_count_lines.qty + excluded.qty;
  update public.compras_orders set items = replace(items::text, p_from::text, p_into::text)::jsonb where items::text like '%' || p_from::text || '%';
  delete from public.compras_products where id = p_from;
end $function$;
revoke execute on function public.compras__merge_products(uuid, uuid) from public, anon, authenticated;

create or replace function public.compras_merge_products(p_token text, p_from uuid, p_into uuid) returns void
language plpgsql security definer set search_path to 'public', 'extensions' as $function$
declare u public.compras_users;
begin
  u := public.compras__chefe(p_token);
  perform public.compras__merge_products(p_from, p_into);
end $function$;

-- Relatório de preços resumido (back office): uma linha por produto e fornecedor com mudanças no período —
-- preço no início (o que estava em vigor antes do período) e no fim, quantas vezes mudou, mínimo e máximo,
-- quanto se pagou a mais/menos nas compras do período face ao preço do início, e impacto por mês.
create or replace function public.compras_bo_precos_resumo(p_token text, p_de date, p_ate date) returns jsonb
language plpgsql security definer set search_path to 'public', 'extensions' as $$
begin
  perform public.compras__dono(p_token);
  return coalesce((
    with est as (select * from public.compras__precos_estimados()),
    ph as (select h.product_id, h.supplier_id, h.invoice_id, h.data, avg(h.unit_price) u, min(h.id) id
             from public.compras_price_history h group by 1, 2, 3, 4),
    seq as (select ph.*, lag(u) over w pu from ph window w as (partition by product_id, supplier_id order by data, id)),
    mud as (select product_id, supplier_id, count(*) n from seq where pu > 0 and abs(u / pu - 1) >= 0.005 and data between p_de and p_ate group by 1, 2),
    antes as (select distinct on (ph.product_id, ph.supplier_id) ph.product_id, ph.supplier_id, ph.u, ph.data, ph.invoice_id
                from ph join mud using (product_id, supplier_id) where ph.data < p_de order by ph.product_id, ph.supplier_id, ph.data desc, ph.id desc),
    primeiro as (select distinct on (ph.product_id, ph.supplier_id) ph.product_id, ph.supplier_id, ph.u, ph.data, ph.invoice_id
                from ph join mud using (product_id, supplier_id) where ph.data between p_de and p_ate order by ph.product_id, ph.supplier_id, ph.data, ph.id),
    ini as (select m.product_id, m.supplier_id, coalesce(a.u, f.u) u, coalesce(a.data, f.data) data, coalesce(a.invoice_id, f.invoice_id) invoice_id
              from mud m left join antes a using (product_id, supplier_id) left join primeiro f using (product_id, supplier_id)),
    fim as (select distinct on (ph.product_id, ph.supplier_id) ph.product_id, ph.supplier_id, ph.u, ph.data
                from ph join mud using (product_id, supplier_id) where ph.data <= p_ate order by ph.product_id, ph.supplier_id, ph.data desc, ph.id desc),
    compras as (select ph.product_id, ph.supplier_id, ph.invoice_id, ph.u,
                  (select coalesce(sum(pl.qty), 0) from public.compras_purchase_lines pl where pl.invoice_id = ph.invoice_id and pl.product_id = ph.product_id and pl.qty > 0) q
                  from ph join mud using (product_id, supplier_id) where ph.data between p_de and p_ate),
    per as (select c.product_id, c.supplier_id, min(c.u) pmin, max(c.u) pmax, count(*) n, sum(c.q) q, sum((c.u - i.u) * c.q) impacto,
                   bool_or(exists (select 1 from est where est.invoice_id = c.invoice_id and est.product_id = c.product_id)) est
              from compras c join ini i using (product_id, supplier_id) group by 1, 2),
    qtd as (select pl.product_id, i.supplier_id, sum(pl.qty) q from public.compras_purchase_lines pl join public.compras_invoices i on i.id = pl.invoice_id
             where pl.data > p_ate - 90 and pl.data <= p_ate and pl.qty > 0 group by 1, 2),
    vend as (select distinct recipe_guara_id g from public.compras_zs_items where recipe_guara_id is not null and not ignorar),
    pr as (select u.product_id, count(distinct u.root) n from public.compras__recipe_usage() u join vend on vend.g = u.root group by 1)
    select jsonb_agg(jsonb_build_object(
        'product_id', m.product_id, 'produto', p.nome, 'categoria', p.categoria, 'unidade', p.unidade,
        'supplier_id', m.supplier_id, 'fornecedor', s.nome,
        'preco_inicio', round(i.u, 4), 'data_inicio', i.data, 'preco_fim', round(f.u, 4), 'data_fim', f.data,
        'var_pct', round((f.u / nullif(i.u, 0) - 1) * 100, 1), 'mudancas', m.n,
        'preco_min', round(least(per.pmin, i.u), 4), 'preco_max', round(greatest(per.pmax, i.u), 4), 'compras', per.n,
        'qtd_periodo', round(per.q, 3), 'impacto_periodo', round(per.impacto, 2), 'qtd_mes', round(coalesce(q.q, 0) / 3, 3),
        'estimado', per.est or exists (select 1 from est where est.invoice_id = i.invoice_id and est.product_id = m.product_id),
        'pratos', coalesce(pr.n, 0))
      order by abs(f.u / nullif(i.u, 0) - 1) desc)
    from mud m join ini i using (product_id, supplier_id) join fim f using (product_id, supplier_id) join per using (product_id, supplier_id)
    join public.compras_products p on p.id = m.product_id join public.compras_suppliers s on s.id = m.supplier_id
    left join qtd q on q.product_id = m.product_id and q.supplier_id = m.supplier_id
    left join pr on pr.product_id = m.product_id), '[]');
end $$;

-- ============================================================
-- Forma de encomenda por fornecedor (17/11, back office): ex.: abacate na FRUSTOCK pede-se à unidade, mas fatura-se ao kg.
-- Só muda a encomenda (quantidade, passo de 1 e mensagem "10 un Abacate"); faturas, preços e stock continuam na unidade
-- do produto. Vazio = como antes. As linhas com forma ficam sem preço na encomenda (sem peso aproximado, a pedido do dono).
-- ============================================================
alter table public.compras_offers add column if not exists forma_encomenda text not null default '';
create table if not exists public.compras_formas_encomenda (nome text primary key, criado_em timestamptz not null default now());
alter table public.compras_formas_encomenda enable row level security;
revoke all on public.compras_formas_encomenda from anon, authenticated;
insert into public.compras_formas_encomenda (nome) values ('un'), ('caixa'), ('molho'), ('cuvete'), ('saco') on conflict do nothing;

create or replace function public.compras_catalog(p_token text) returns jsonb
language plpgsql security definer set search_path to 'public', 'extensions' as $function$
declare u public.compras_users;
begin
  u := public.compras__user(p_token);
  return jsonb_build_object(
    'restaurante', (select restaurante from public.compras_settings where id = 1),
    'suppliers', coalesce((select jsonb_agg(jsonb_build_object('id', s.id, 'nome', s.nome, 'telefone', s.telefone, 'dias', s.dias, 'nif', s.nif, 'minimo', s.minimo, 'via', s.via) order by lower(s.nome)) from public.compras_suppliers s), '[]'),
    'products', coalesce((select jsonb_agg(jsonb_build_object(
        'id', p.id, 'nome', p.nome, 'categoria', p.categoria, 'unidade', p.unidade, 'setores', to_jsonb(p.setores),
        'offers', coalesce((select jsonb_agg(jsonb_build_object('supplier_id', o.supplier_id, 'alias', o.alias, 'nome_encomenda', o.nome_encomenda,
             'forma_encomenda', o.forma_encomenda, 'codigo', o.codigo,
             'pack_qty', o.pack_qty, 'pack_price', o.pack_price, 'unit_price', o.unit_price, 'prev_unit_price', o.prev_unit_price, 'prev_data', o.prev_data, 'data', o.data)
             order by o.unit_price) from public.compras_offers o where o.product_id = p.id), '[]')
      ) order by lower(p.nome)) from public.compras_products p), '[]')
  );
end $function$;

-- Encomendas: a linha leva a forma (se houver) e fica sem preço; só se junta a uma linha aberta com a mesma forma
create or replace function public.compras_submit_order(p_token text, p_items jsonb, p_nota text) returns jsonb
language plpgsql security definer set search_path to 'public', 'extensions' as $function$
declare u public.compras_users; r record; n int := 0; j int := 0; ex public.compras_orders; merged jsonb; it jsonb; idx int; found_i boolean;
begin
  u := public.compras__user(p_token);
  update public.compras_products p set setores = public.compras__setores(p.setores || array[i->>'setor'])
    from jsonb_array_elements(coalesce(p_items,'[]')) i
   where p.id = (i->>'product_id')::uuid and cardinality(p.setores) > 0
     and (i->>'setor') in ('cozinha','sushi','bar','takeaway') and not ((i->>'setor') = any(p.setores));
  for r in
    select o.supplier_id, sup.nome as sup_nome,
           jsonb_agg(jsonb_build_object('product_id', p.id, 'nome', p.nome, 'alias', o.alias, 'codigo', o.codigo,
             'qty', x.qty, 'pack_qty', o.pack_qty, 'pack_price', case when o.forma_encomenda <> '' then null else o.pack_price end,
             'base_unit', p.unidade, 'setor', x.setor) || case when o.forma_encomenda <> '' then jsonb_build_object('forma', o.forma_encomenda) else '{}'::jsonb end
             order by p.nome, x.setor) as items
      from (select (i->>'product_id')::uuid pid, (i->>'supplier_id')::uuid sid,
                   case when (i->>'setor') in ('cozinha','sushi','bar','takeaway') then i->>'setor' else u.setor end setor,
                   sum((i->>'qty')::numeric) qty
              from jsonb_array_elements(coalesce(p_items,'[]')) i where (i->>'qty')::numeric > 0 group by 1,2,3) x
      join public.compras_offers o on o.product_id = x.pid and o.supplier_id = x.sid
      join public.compras_products p on p.id = o.product_id
      join public.compras_suppliers sup on sup.id = o.supplier_id
     group by o.supplier_id, sup.nome
  loop
    select * into ex from public.compras_orders
     where supplier_id = r.supplier_id and status in ('pendente','aprovada')
     order by created_at desc limit 1;
    if found then
      merged := ex.items;
      for it in select * from jsonb_array_elements(r.items) loop
        found_i := false;
        for idx in 0 .. jsonb_array_length(merged) - 1 loop
          if merged->idx->>'product_id' = it->>'product_id' and coalesce(merged->idx->>'setor','') = coalesce(it->>'setor','')
             and coalesce(merged->idx->>'forma','') = coalesce(it->>'forma','') then
            merged := jsonb_set(merged, array[idx::text, 'qty'], to_jsonb((merged->idx->>'qty')::numeric + (it->>'qty')::numeric));
            found_i := true; exit;
          end if;
        end loop;
        if not found_i then merged := merged || jsonb_build_array(it); end if;
      end loop;
      update public.compras_orders set items = merged,
        nota = case when coalesce(p_nota,'') = '' then nota when nota = '' then left(p_nota, 500) else left(nota || ' / ' || p_nota, 500) end,
        status = case when u.role = 'chefe' then 'aprovada' else 'pendente' end,
        approved_by = case when u.role = 'chefe' then u.id else null end,
        approved_at = case when u.role = 'chefe' then now() else null end
      where id = ex.id;
      j := j + 1;
    else
      insert into public.compras_orders (supplier_id, fornecedor_nome, items, nota, status, created_by, approved_by, approved_at)
      values (r.supplier_id, r.sup_nome, r.items, left(coalesce(p_nota,''), 500),
              case when u.role = 'chefe' then 'aprovada' else 'pendente' end, u.id,
              case when u.role = 'chefe' then u.id end, case when u.role = 'chefe' then now() end);
      n := n + 1;
    end if;
  end loop;
  if n + j = 0 then raise exception 'carrinho_vazio'; end if;
  return jsonb_build_object('encomendas', n, 'juntadas', j, 'aprovadas', u.role = 'chefe');
end $function$;

create or replace function public.compras_bo_formas(p_token text) returns jsonb
language plpgsql security definer set search_path to 'public', 'extensions' as $$
begin
  perform public.compras__dono(p_token);
  return coalesce((select jsonb_agg(nome order by case nome when 'un' then 0 else 1 end, nome) from public.compras_formas_encomenda), '[]');
end $$;

create or replace function public.compras_bo_forma_encomenda(p_token text, p_product uuid, p_supplier uuid, p_forma text) returns jsonb
language plpgsql security definer set search_path to 'public', 'extensions' as $$
declare v text;
begin
  perform public.compras__dono(p_token);
  v := lower(btrim(regexp_replace(coalesce(p_forma, ''), '\s+', ' ', 'g')));
  if length(v) > 20 then raise exception 'forma_longa'; end if;
  if v <> '' then insert into public.compras_formas_encomenda (nome) values (v) on conflict do nothing; end if;
  update public.compras_offers set forma_encomenda = v where product_id = p_product and supplier_id = p_supplier;
  if not found then raise exception 'oferta_nao_existe'; end if;
  return jsonb_build_object('product_id', p_product, 'supplier_id', p_supplier, 'forma_encomenda', v);
end $$;

create or replace function public.compras_bo_produtos(p_token text) returns jsonb
language plpgsql security definer set search_path to 'public', 'extensions' as $$
begin
  perform public.compras__dono(p_token);
  return coalesce((
    with vend as (select distinct recipe_guara_id g from public.compras_zs_items where recipe_guara_id is not null and not ignorar),
    pr as (select u.product_id, count(distinct u.root) n from public.compras__recipe_usage() u join vend on vend.g = u.root group by 1)
    select jsonb_agg(jsonb_build_object('id', p.id, 'nome', p.nome, 'categoria', p.categoria, 'unidade', p.unidade,
      'pratos', coalesce(pr.n, 0),
      'ofertas', coalesce((select jsonb_agg(jsonb_build_object('supplier_id', o.supplier_id, 'fornecedor', s.nome, 'alias', o.alias,
           'nome_encomenda', o.nome_encomenda, 'forma_encomenda', o.forma_encomenda, 'codigo', o.codigo, 'pack_qty', o.pack_qty, 'pack_price', o.pack_price,
           'unit_price', o.unit_price, 'data', o.data) order by o.unit_price)
         from public.compras_offers o join public.compras_suppliers s on s.id = o.supplier_id where o.product_id = p.id), '[]'))
      order by lower(p.nome))
    from public.compras_products p left join pr on pr.product_id = p.id), '[]');
end $$;

-- ============================================================
-- Várias formas de encomenda por fornecedor (17/11): ex.: banana na FRUSTOCK em kg ou un; quem encomenda escolhe.
-- formas_encomenda: lista ordenada ('' = como está); vazia = só como está; a 1.ª é a de defeito. forma_encomenda = 1.ª.
-- ============================================================
alter table public.compras_offers add column if not exists formas_encomenda text[] not null default '{}';
update public.compras_offers set formas_encomenda = array[forma_encomenda] where forma_encomenda <> '' and cardinality(formas_encomenda) = 0;

create or replace function public.compras__formas_oferta(o public.compras_offers) returns text[]
language sql immutable as $$
  select case when cardinality(o.formas_encomenda) > 0 then o.formas_encomenda when coalesce(o.forma_encomenda, '') <> '' then array[o.forma_encomenda] else array[''] end
$$;

create or replace function public.compras_catalog(p_token text) returns jsonb
language plpgsql security definer set search_path to 'public', 'extensions' as $function$
declare u public.compras_users;
begin
  u := public.compras__user(p_token);
  return jsonb_build_object(
    'restaurante', (select restaurante from public.compras_settings where id = 1),
    'suppliers', coalesce((select jsonb_agg(jsonb_build_object('id', s.id, 'nome', s.nome, 'telefone', s.telefone, 'dias', s.dias, 'nif', s.nif, 'minimo', s.minimo, 'via', s.via) order by lower(s.nome)) from public.compras_suppliers s), '[]'),
    'products', coalesce((select jsonb_agg(jsonb_build_object(
        'id', p.id, 'nome', p.nome, 'categoria', p.categoria, 'unidade', p.unidade, 'setores', to_jsonb(p.setores),
        'offers', coalesce((select jsonb_agg(jsonb_build_object('supplier_id', o.supplier_id, 'alias', o.alias, 'nome_encomenda', o.nome_encomenda,
             'forma_encomenda', o.forma_encomenda, 'formas', to_jsonb(public.compras__formas_oferta(o)), 'codigo', o.codigo,
             'pack_qty', o.pack_qty, 'pack_price', o.pack_price, 'unit_price', o.unit_price, 'prev_unit_price', o.prev_unit_price, 'prev_data', o.prev_data, 'data', o.data)
             order by o.unit_price) from public.compras_offers o where o.product_id = p.id), '[]')
      ) order by lower(p.nome)) from public.compras_products p), '[]')
  );
end $function$;

-- Encomendas: cada linha leva a forma escolhida (se for uma das permitidas; senão a primeira); com forma, sem preço
create or replace function public.compras_submit_order(p_token text, p_items jsonb, p_nota text) returns jsonb
language plpgsql security definer set search_path to 'public', 'extensions' as $function$
declare u public.compras_users; r record; n int := 0; j int := 0; ex public.compras_orders; merged jsonb; it jsonb; idx int; found_i boolean;
begin
  u := public.compras__user(p_token);
  update public.compras_products p set setores = public.compras__setores(p.setores || array[i->>'setor'])
    from jsonb_array_elements(coalesce(p_items,'[]')) i
   where p.id = (i->>'product_id')::uuid and cardinality(p.setores) > 0
     and (i->>'setor') in ('cozinha','sushi','bar','takeaway') and not ((i->>'setor') = any(p.setores));
  for r in
    select y.supplier_id, y.sup_nome,
           jsonb_agg(jsonb_build_object('product_id', y.pid, 'nome', y.nome, 'alias', y.alias, 'codigo', y.codigo,
             'qty', y.qty, 'pack_qty', y.pack_qty, 'pack_price', case when y.forma <> '' then null else y.pack_price end,
             'base_unit', y.unidade, 'setor', y.setor) || case when y.forma <> '' then jsonb_build_object('forma', y.forma) else '{}'::jsonb end
             order by y.nome, y.setor, y.forma) as items
      from (select o.supplier_id, sup.nome sup_nome, p.id pid, p.nome, o.alias, o.codigo, o.pack_qty, o.pack_price, p.unidade, x.setor,
                   case when x.forma = any(public.compras__formas_oferta(o)) then x.forma else (public.compras__formas_oferta(o))[1] end forma,
                   sum(x.qty) qty
              from (select (i->>'product_id')::uuid pid, (i->>'supplier_id')::uuid sid,
                           case when (i->>'setor') in ('cozinha','sushi','bar','takeaway') then i->>'setor' else u.setor end setor,
                           lower(btrim(coalesce(i->>'forma',''))) forma, (i->>'qty')::numeric qty
                      from jsonb_array_elements(coalesce(p_items,'[]')) i where (i->>'qty')::numeric > 0) x
              join public.compras_offers o on o.product_id = x.pid and o.supplier_id = x.sid
              join public.compras_products p on p.id = o.product_id
              join public.compras_suppliers sup on sup.id = o.supplier_id
             group by 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11) y
     group by y.supplier_id, y.sup_nome
  loop
    select * into ex from public.compras_orders
     where supplier_id = r.supplier_id and status in ('pendente','aprovada')
     order by created_at desc limit 1;
    if found then
      merged := ex.items;
      for it in select * from jsonb_array_elements(r.items) loop
        found_i := false;
        for idx in 0 .. jsonb_array_length(merged) - 1 loop
          if merged->idx->>'product_id' = it->>'product_id' and coalesce(merged->idx->>'setor','') = coalesce(it->>'setor','')
             and coalesce(merged->idx->>'forma','') = coalesce(it->>'forma','') then
            merged := jsonb_set(merged, array[idx::text, 'qty'], to_jsonb((merged->idx->>'qty')::numeric + (it->>'qty')::numeric));
            found_i := true; exit;
          end if;
        end loop;
        if not found_i then merged := merged || jsonb_build_array(it); end if;
      end loop;
      update public.compras_orders set items = merged,
        nota = case when coalesce(p_nota,'') = '' then nota when nota = '' then left(p_nota, 500) else left(nota || ' / ' || p_nota, 500) end,
        status = case when u.role = 'chefe' then 'aprovada' else 'pendente' end,
        approved_by = case when u.role = 'chefe' then u.id else null end,
        approved_at = case when u.role = 'chefe' then now() else null end
      where id = ex.id;
      j := j + 1;
    else
      insert into public.compras_orders (supplier_id, fornecedor_nome, items, nota, status, created_by, approved_by, approved_at)
      values (r.supplier_id, r.sup_nome, r.items, left(coalesce(p_nota,''), 500),
              case when u.role = 'chefe' then 'aprovada' else 'pendente' end, u.id,
              case when u.role = 'chefe' then u.id end, case when u.role = 'chefe' then now() end);
      n := n + 1;
    end if;
  end loop;
  if n + j = 0 then raise exception 'carrinho_vazio'; end if;
  return jsonb_build_object('encomendas', n, 'juntadas', j, 'aprovadas', u.role = 'chefe');
end $function$;

create or replace function public.compras_bo_formas_oferta(p_token text, p_product uuid, p_supplier uuid, p_formas text[]) returns jsonb
language plpgsql security definer set search_path to 'public', 'extensions' as $$
declare arr text[] := '{}'; f text; v text;
begin
  perform public.compras__dono(p_token);
  foreach f in array coalesce(p_formas, '{}') loop
    v := lower(btrim(regexp_replace(coalesce(f, ''), '\s+', ' ', 'g')));
    if length(v) > 20 then raise exception 'forma_longa'; end if;
    if not (v = any(arr)) then arr := arr || v; end if;
    if v <> '' then insert into public.compras_formas_encomenda (nome) values (v) on conflict do nothing; end if;
  end loop;
  if arr = array[''] then arr := '{}'; end if;
  update public.compras_offers set formas_encomenda = arr, forma_encomenda = coalesce(nullif(arr[1], ''), '')
   where product_id = p_product and supplier_id = p_supplier;
  if not found then raise exception 'oferta_nao_existe'; end if;
  return jsonb_build_object('product_id', p_product, 'supplier_id', p_supplier, 'formas', to_jsonb(case when cardinality(arr) = 0 then array[''] else arr end));
end $$;

create or replace function public.compras_bo_produtos(p_token text) returns jsonb
language plpgsql security definer set search_path to 'public', 'extensions' as $$
begin
  perform public.compras__dono(p_token);
  return coalesce((
    with vend as (select distinct recipe_guara_id g from public.compras_zs_items where recipe_guara_id is not null and not ignorar),
    pr as (select u.product_id, count(distinct u.root) n from public.compras__recipe_usage() u join vend on vend.g = u.root group by 1)
    select jsonb_agg(jsonb_build_object('id', p.id, 'nome', p.nome, 'categoria', p.categoria, 'unidade', p.unidade,
      'pratos', coalesce(pr.n, 0),
      'ofertas', coalesce((select jsonb_agg(jsonb_build_object('supplier_id', o.supplier_id, 'fornecedor', s.nome, 'alias', o.alias,
           'nome_encomenda', o.nome_encomenda, 'formas', to_jsonb(public.compras__formas_oferta(o)), 'codigo', o.codigo, 'pack_qty', o.pack_qty, 'pack_price', o.pack_price,
           'unit_price', o.unit_price, 'data', o.data) order by o.unit_price)
         from public.compras_offers o join public.compras_suppliers s on s.id = o.supplier_id where o.product_id = p.id), '[]'))
      order by lower(p.nome))
    from public.compras_products p left join pr on pr.product_id = p.id), '[]');
end $$;

-- A app sabe se quem entrou é o dono (mostra o atalho com a casa para o back office)
create or replace function public.compras_me(p_token text) returns jsonb
language plpgsql security definer set search_path to 'public', 'extensions' as $function$
declare u public.compras_users;
begin
  u := public.compras__user(p_token);
  return jsonb_build_object('id', u.id, 'nome', u.nome, 'role', u.role, 'setor', u.setor,
    'restaurante', (select restaurante from public.compras_settings where id = 1),
    'dono', u.id = (select dono_id from public.compras_settings where id = 1));
end $function$;

-- ===================== Vendas: valor sem IVA, preço de tabela e IVA (18/11) =====================
alter table public.compras_sales
  add column if not exists valor numeric,   -- total sem IVA (ZSbms `valor`)
  add column if not exists pvp numeric,     -- preço de tabela com IVA mais vendido nesse dia (ZSbms `precovenda`; 0 no all you can eat)
  add column if not exists iva numeric;     -- taxa de IVA (%)

create or replace function public.compras__import_sales(p_rows jsonb)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'public', 'extensions'
as $function$
declare n int; nd int;
begin
  delete from public.compras_sales where dia in (select distinct (x->>'dia')::date from jsonb_array_elements(coalesce(p_rows,'[]')) x);
  get diagnostics nd = row_count;
  insert into public.compras_sales (dia, codigo, descricao, qtd, total, valor, pvp, iva)
  select (x->>'dia')::date, (x->>'codigo')::int, max(coalesce(x->>'descricao','')), sum(coalesce((x->>'qtd')::numeric,0)), sum(coalesce((x->>'total')::numeric,0)),
         sum(nullif(x->>'valor','')::numeric), max(nullif(x->>'pvp','')::numeric), max(nullif(x->>'iva','')::numeric)
    from jsonb_array_elements(coalesce(p_rows,'[]')) x
   where nullif(x->>'dia','') is not null and nullif(x->>'codigo','') is not null
   group by 1, 2;
  get diagnostics n = row_count;
  insert into public.compras_zs_items (codigo, descricao)
  select distinct on ((x->>'codigo')::int) (x->>'codigo')::int, coalesce(x->>'descricao','')
    from jsonb_array_elements(coalesce(p_rows,'[]')) x where nullif(x->>'codigo','') is not null
  on conflict (codigo) do update set descricao = excluded.descricao;
  perform public.compras__refresh_media_sushi();
  return jsonb_build_object('linhas', n, 'substituidas', nd);
end $function$;

-- ===================== CMV por artigo, por prato e global (18/11) =====================
-- CMV (custo da mercadoria vendida) por artigo do ZSbms, por prato e global.
-- Custo: o da receita no Guará (extra.custo_guara); se o Guará não tiver custo (ou der 0 ou negativo), o das faturas
-- (receita × últimos preços). Artigos ligados a um produto: último preço do produto × fator.
-- Preço de venda: o preço de tabela do ZSbms (precovenda) mais vendido no período, só nas linhas pagas; sem IVA com a
-- taxa da própria linha. CMV = custo ÷ preço de venda sem IVA. Linhas do all you can eat (a 0 €) não têm preço.
create or replace function public.compras__vendas_artigos(p_de date, p_ate date)
returns table(codigo int, descricao text, tipo text, recipe_guara_id text, receita text, categoria text, product_id uuid, produto text,
  fator numeric, custo numeric, custo_fonte text, custo_guara numeric, custo_faturas numeric, pvp numeric, iva numeric, pvp_sem_iva numeric,
  cmv_pct numeric, qtd numeric, qtd_paga numeric, vendas numeric, vendas_sem_iva numeric, custo_total numeric, ayce boolean)
language sql stable security definer set search_path = public as $$
  with s as (
    select s.codigo, s.qtd, s.total, s.pvp, s.iva,
           coalesce(s.valor, s.total / (1 + coalesce(s.iva, 13) / 100)) valor
      from public.compras_sales s where s.dia between p_de and p_ate),
  ag as (select s.codigo, sum(s.qtd) qtd, coalesce(sum(s.qtd) filter (where s.total > 0), 0) qtd_paga,
                sum(s.total) vendas, sum(s.valor) vendas_sem_iva from s group by 1),
  pv as (select distinct on (x.codigo) x.codigo, x.pvp, x.iva from (
           select s.codigo, coalesce(nullif(s.pvp, 0), round(s.total / nullif(s.qtd, 0), 2)) pvp,
                  coalesce(case when s.iva > 0 then s.iva end, round((s.total / nullif(s.valor, 0) - 1) * 100), 13) iva, sum(s.qtd) q
             from s where s.total > 0 and s.qtd > 0 group by 1, 2, 3) x
         order by x.codigo, x.q desc, x.pvp desc),
  use as (select * from public.compras__recipe_usage()),
  preco as (select distinct on (h.product_id) h.product_id, h.unit_price from public.compras_price_history h order by h.product_id, h.data desc, h.id desc),
  capp as (select u.root, sum(u.qty * coalesce(p.unit_price, 0)) c from use u left join preco p on p.product_id = u.product_id group by 1),
  b as (
    select a.codigo, z.descricao,
           case when z.ignorar then 'menu' when z.recipe_guara_id is not null then 'receita' when z.product_id is not null then 'produto' else 'sem_ligacao' end tipo,
           z.recipe_guara_id, r.nome receita, coalesce(nullif(r.categoria, ''), pr.categoria) categoria, z.product_id, pr.nome produto, z.fator,
           case when not z.ignorar and z.recipe_guara_id is not null then nullif((r.extra->>'custo_guara')::numeric, 0) * z.fator end cg,
           case when z.ignorar then null when z.recipe_guara_id is not null then nullif(ca.c, 0) * z.fator
                when z.product_id is not null then pc.unit_price * z.fator end cf,
           pv.pvp, pv.iva, a.qtd, a.qtd_paga, a.vendas, a.vendas_sem_iva,
           coalesce(z.descricao like '@%' or (a.qtd > 0 and a.qtd_paga = 0), false) ayce
      from ag a
      left join public.compras_zs_items z on z.codigo = a.codigo
      left join public.compras_recipes r on r.guara_id = z.recipe_guara_id
      left join public.compras_products pr on pr.id = z.product_id
      left join capp ca on ca.root = z.recipe_guara_id
      left join preco pc on pc.product_id = z.product_id
      left join pv on pv.codigo = a.codigo)
  select b.codigo, coalesce(b.descricao, ''), coalesce(b.tipo, 'sem_ligacao'), b.recipe_guara_id, b.receita, b.categoria, b.product_id, b.produto, b.fator,
         round(c.custo, 4), c.fonte, round(b.cg, 4), round(b.cf, 4),
         case when not b.ayce then b.pvp end, case when not b.ayce then b.iva end,
         case when not b.ayce then round(b.pvp / (1 + b.iva / 100), 4) end,
         case when not b.ayce and b.pvp > 0 and c.custo is not null then round(c.custo / (b.pvp / (1 + b.iva / 100)) * 100, 1) end,
         b.qtd, b.qtd_paga, round(b.vendas, 2), round(b.vendas_sem_iva, 2), round(c.custo * b.qtd, 2), b.ayce
    from b, lateral (select case when b.cg > 0 then b.cg when b.cf > 0 then b.cf end custo,
                            case when b.cg > 0 then 'guara' when b.cf > 0 then 'faturas' end fonte) c
$$;
revoke all on function public.compras__vendas_artigos(date, date) from public, anon, authenticated;

-- Por prato (receita do Guará): custo da receita, preço de venda por receita (média dos artigos pagos que a usam,
-- ponderada pelas quantidades) e CMV. Só all you can eat → sem preço.
create or replace function public.compras__pratos_cmv(p_de date, p_ate date)
returns table(guara_id text, custo numeric, custo_fonte text, custo_guara numeric, custo_faturas numeric, pvp numeric, pvp_sem_iva numeric,
  iva numeric, cmv_pct numeric, vendidos numeric, so_ayce boolean)
language sql stable security definer set search_path = public as $$
  with a as (select * from public.compras__vendas_artigos(p_de, p_ate) v where v.tipo = 'receita'),
  r as (select a.recipe_guara_id g,
               sum(a.qtd * a.fator) vendidos,
               sum(a.pvp * a.qtd_paga) filter (where a.pvp > 0) / nullif(sum(a.qtd_paga * a.fator) filter (where a.pvp > 0), 0) pvp,
               sum(a.pvp_sem_iva * a.qtd_paga) filter (where a.pvp > 0) / nullif(sum(a.qtd_paga * a.fator) filter (where a.pvp > 0), 0) pvp_sem_iva,
               bool_and(a.ayce) so_ayce
          from a group by 1),
  use as (select * from public.compras__recipe_usage()),
  preco as (select distinct on (h.product_id) h.product_id, h.unit_price from public.compras_price_history h order by h.product_id, h.data desc, h.id desc),
  capp as (select u.root, sum(u.qty * coalesce(p.unit_price, 0)) c from use u left join preco p on p.product_id = u.product_id group by 1)
  select r.g, round(c.custo, 4), c.fonte, round(nullif((rc.extra->>'custo_guara')::numeric, 0), 4), round(nullif(ca.c, 0), 4),
         round(r.pvp, 2), round(r.pvp_sem_iva, 4), round((r.pvp / nullif(r.pvp_sem_iva, 0) - 1) * 100),
         case when r.pvp_sem_iva > 0 and c.custo is not null then round(c.custo / r.pvp_sem_iva * 100, 1) end,
         r.vendidos, r.so_ayce
    from r join public.compras_recipes rc on rc.guara_id = r.g left join capp ca on ca.root = r.g,
    lateral (select case when (rc.extra->>'custo_guara')::numeric > 0 then (rc.extra->>'custo_guara')::numeric when ca.c > 0 then ca.c end custo,
                    case when (rc.extra->>'custo_guara')::numeric > 0 then 'guara' when ca.c > 0 then 'faturas' end fonte) c
$$;
revoke all on function public.compras__pratos_cmv(date, date) from public, anon, authenticated;

-- Back office: artigos vendidos no período com CMV e totais (CMV global e do all you can eat)
create or replace function public.compras_bo_pratos(p_token text, p_de date default null, p_ate date default null)
returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare v_de date := coalesce(p_de, current_date - 29); v_ate date := coalesce(p_ate, current_date); r jsonb;
begin
  perform public.compras__dono(p_token);
  if v_ate < v_de then raise exception 'periodo_invalido'; end if;
  with a as (select * from public.compras__vendas_artigos(v_de, v_ate))
  select jsonb_build_object(
    'de', v_de, 'ate', v_ate,
    'dias', (select count(distinct s.dia) from public.compras_sales s where s.dia between v_de and v_ate),
    'vendas_sem_iva', (select round(sum(vendas_sem_iva), 2) from a),
    'vendas', (select round(sum(vendas), 2) from a),
    'custo', (select round(sum(custo_total), 2) from a),
    'sem_custo_vendas', (select round(sum(vendas_sem_iva), 2) from a where tipo <> 'menu' and custo is null and not ayce),
    'sem_custo_artigos', (select count(*) from a where tipo <> 'menu' and custo is null and qtd > 0),
    'ayce_vendas', (select round(sum(vendas_sem_iva), 2) from a where tipo = 'menu' and descricao ilike '%all you can eat%'),
    'ayce_custo', (select round(sum(custo_total), 2) from a where descricao like '@%'),
    'artigos', coalesce((select jsonb_agg(to_jsonb(a) order by a.vendas_sem_iva desc nulls last, a.qtd desc) from a where a.qtd <> 0), '[]'))
  into r;
  return r;
end $$;
revoke all on function public.compras_bo_pratos(text, date, date) from public;
grant execute on function public.compras_bo_pratos(text, date, date) to anon, authenticated;

-- Detalhe do produto: os pratos afetados levam custo do Guará, preço de venda do ZSbms e CMV (últimos 30 dias)
create or replace function public.compras_bo_produto(p_token text, p_id uuid)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'public', 'extensions'
as $function$
declare r jsonb;
begin
  perform public.compras__dono(p_token);
  with est as (select * from public.compras__precos_estimados() e where e.product_id = p_id),
  hist as (select h.invoice_id, h.supplier_id, h.data, avg(h.unit_price) u, min(h.id) id from public.compras_price_history h where h.product_id = p_id group by 1, 2, 3),
  ult as (select * from hist order by data desc, id desc limit 1),
  ant as (select h.* from hist h, ult where h.supplier_id = ult.supplier_id and h.data < ult.data order by h.data desc, h.id desc limit 1),
  use as (select * from public.compras__recipe_usage()),
  preco as (select distinct on (product_id) product_id, unit_price from public.compras_price_history order by product_id, data desc, id desc),
  cmv as (select * from public.compras__pratos_cmv(current_date - 29, current_date)),
  mapeadas as (select distinct recipe_guara_id g from public.compras_zs_items where recipe_guara_id is not null and not ignorar),
  pratos as (select r.guara_id, r.nome, u.qty qtd_produto,
               (select sum(u2.qty * coalesce(pc.unit_price, 0)) from use u2 left join preco pc on pc.product_id = u2.product_id where u2.root = r.guara_id) custo_faturas,
               (select count(*) from use u2 left join preco pc on pc.product_id = u2.product_id where u2.root = r.guara_id and pc.unit_price is null) sem_preco,
               c.custo, c.custo_fonte, c.custo_guara, c.pvp, c.pvp_sem_iva, c.iva, c.cmv_pct, coalesce(c.so_ayce, false) so_ayce,
               coalesce(c.vendidos, 0) vendidos_30d
               from use u join public.compras_recipes r on r.guara_id = u.root join mapeadas m on m.g = r.guara_id left join cmv c on c.guara_id = r.guara_id
              where u.product_id = p_id)
  select jsonb_build_object(
    'produto', (select jsonb_build_object('id', p.id, 'nome', p.nome, 'categoria', p.categoria, 'unidade', p.unidade) from public.compras_products p where p.id = p_id),
    'preco_atual', (select u from ult), 'preco_anterior', (select u from ant), 'data_atual', (select data from ult), 'data_anterior', (select data from ant),
    'historico', coalesce((select jsonb_agg(jsonb_build_object('data', h.data, 'fornecedor', s.nome, 'supplier_id', h.supplier_id, 'numero', i.numero,
        'preco', round(h.u, 4), 'qtd', (select sum(pl.qty) from public.compras_purchase_lines pl where pl.invoice_id = h.invoice_id and pl.product_id = p_id),
        'estimado', exists (select 1 from est where est.invoice_id = h.invoice_id)) order by h.data, h.id)
      from hist h join public.compras_suppliers s on s.id = h.supplier_id join public.compras_invoices i on i.id = h.invoice_id), '[]'),
    'pratos', coalesce((select jsonb_agg(jsonb_build_object('guara_id', guara_id, 'nome', nome, 'qtd_produto', round(qtd_produto, 5),
        'custo', round(custo, 4), 'custo_fonte', custo_fonte, 'custo_guara', custo_guara, 'custo_faturas', round(custo_faturas, 4), 'sem_preco', sem_preco,
        'pvp', pvp, 'pvp_sem_iva', pvp_sem_iva, 'iva', iva, 'cmv_pct', cmv_pct, 'so_ayce', so_ayce,
        'vendidos_30d', vendidos_30d) order by vendidos_30d desc, nome) from pratos), '[]'))
  into r;
  return r;
end $function$;

-- ===================== Texto extra na mensagem da encomenda, por fornecedor (18/11) =====================
-- Ex.: a Keta Foods pede o NIF do restaurante em cada encomenda: mensagem = 'Nif: 515750115'.
alter table public.compras_suppliers add column if not exists mensagem text not null default '';

create or replace function public.compras_catalog(p_token text)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'public', 'extensions'
as $function$
declare u public.compras_users;
begin
  u := public.compras__user(p_token);
  return jsonb_build_object(
    'restaurante', (select restaurante from public.compras_settings where id = 1),
    'suppliers', coalesce((select jsonb_agg(jsonb_build_object('id', s.id, 'nome', s.nome, 'telefone', s.telefone, 'dias', s.dias, 'nif', s.nif, 'minimo', s.minimo, 'via', s.via, 'mensagem', s.mensagem) order by lower(s.nome)) from public.compras_suppliers s), '[]'),
    'products', coalesce((select jsonb_agg(jsonb_build_object(
        'id', p.id, 'nome', p.nome, 'categoria', p.categoria, 'unidade', p.unidade, 'setores', to_jsonb(p.setores),
        'offers', coalesce((select jsonb_agg(jsonb_build_object('supplier_id', o.supplier_id, 'alias', o.alias, 'nome_encomenda', o.nome_encomenda,
             'forma_encomenda', o.forma_encomenda, 'formas', to_jsonb(public.compras__formas_oferta(o)), 'codigo', o.codigo,
             'pack_qty', o.pack_qty, 'pack_price', o.pack_price, 'unit_price', o.unit_price, 'prev_unit_price', o.prev_unit_price, 'prev_data', o.prev_data, 'data', o.data)
             order by o.unit_price) from public.compras_offers o where o.product_id = p.id), '[]')
      ) order by lower(p.nome)) from public.compras_products p), '[]')
  );
end $function$;

drop function if exists public.compras_save_supplier(text, uuid, text, text, text, text, numeric, text);
create or replace function public.compras_save_supplier(p_token text, p_id uuid, p_nome text, p_telefone text, p_dias text, p_nif text,
  p_minimo numeric default null, p_via text default null, p_mensagem text default null)
returns uuid language plpgsql security definer set search_path to 'public', 'extensions' as $function$
declare u public.compras_users; rid uuid; v_via text := case when p_via in ('numero','grupo') then p_via end;
begin
  u := public.compras__chefe(p_token);
  if coalesce(trim(p_nome),'') = '' then raise exception 'nome_obrigatorio'; end if;
  if p_minimo is not null and p_minimo < 0 then raise exception 'preco_invalido'; end if;
  -- p_minimo / p_via / p_mensagem: null = não mexer; p_minimo 0 = sem mínimo
  if p_id is null then
    insert into public.compras_suppliers (nome, telefone, dias, nif, minimo, via, mensagem)
    values (trim(p_nome), coalesce(trim(p_telefone),''), coalesce(trim(p_dias),''), regexp_replace(coalesce(p_nif,''),'\D','','g'),
            nullif(p_minimo, 0), coalesce(v_via, 'numero'), left(coalesce(trim(p_mensagem), ''), 300))
    returning id into rid;
  else
    update public.compras_suppliers set nome = trim(p_nome), telefone = coalesce(trim(p_telefone),''), dias = coalesce(trim(p_dias),''),
      nif = regexp_replace(coalesce(p_nif,''),'\D','','g'), minimo = case when p_minimo is null then minimo else nullif(p_minimo, 0) end,
      via = coalesce(v_via, via), mensagem = case when p_mensagem is null then mensagem else left(trim(p_mensagem), 300) end
    where id = p_id returning id into rid;
  end if;
  return rid;
end $function$;
grant execute on function public.compras_save_supplier(text, uuid, text, text, text, text, numeric, text, text) to anon, authenticated;

-- ===================== Garcias: IEC à parte, correções de faturas e conferência no documento (18/11) =====================
-- Desde 19/10 a Garcias mostra o IEC (imposto sobre o álcool) numa coluna à parte e o Guará lê o "Pr. Unit." sem IEC.
-- compras__guara_iec junta o IEC às bebidas espirituosas (≥ 15% vol.) quando a soma das linhas fica abaixo do total sem IVA:
-- IEC = litros × grau × 16,0265 € (taxa de 2026 por litro de álcool puro; atualizar quando mudar). Preço marcado como estimado ("iec").
create or replace function public.compras__guara_iec(p_fat jsonb)
 returns jsonb
 language plpgsql
 immutable
 set search_path to 'public'
as $function$
declare
  taxa constant numeric := 16.0265;
  semiva numeric := nullif(p_fat->>'total_sem_iva','')::numeric;
  l jsonb; novas jsonb := '[]'::jsonb; soma numeric := 0; falta numeric; iec_total numeric := 0; fator numeric := 1;
  resto numeric; outras numeric := 0; d text; grau numeric; litros numeric; m text[]; q numeric; p numeric; iec numeric; n int := 0;
begin
  if semiva is null or semiva <= 0 then return p_fat; end if;
  select coalesce(sum((x->>'qty')::numeric * (x->>'price')::numeric), 0) into soma
    from jsonb_array_elements(coalesce(p_fat->'linhas','[]')) x where nullif(x->>'price','') is not null and nullif(x->>'qty','') is not null;
  falta := semiva - soma;
  if falta <= greatest(0.5, semiva * 0.02) then return p_fat; end if;
  -- 1.ª volta: IEC de cada bebida espirituosa
  for l in select * from jsonb_array_elements(p_fat->'linhas') loop
    d := coalesce(l->>'desc',''); grau := null; litros := null;
    m := regexp_match(d, '([0-9]+(?:[.,][0-9]+)?)\s*%');
    if m is not null then grau := replace(m[1], ',', '.')::numeric; end if;
    m := regexp_match(substring(d from position('%' in d) + 1), '([0-9]+(?:[.,][0-9]+)?)\s*(cl|lt|l)?', 'i');
    if grau is not null and m is not null then litros := replace(m[1], ',', '.')::numeric / case when lower(coalesce(m[2],'')) = 'cl' then 100 else 1 end; end if;
    if (litros is null or litros <= 0 or litros > 5) and nullif(l->>'pack_qty','') is not null then litros := (l->>'pack_qty')::numeric; end if;
    if grau >= 15 and grau <= 80 and litros > 0 and litros <= 5 and nullif(l->>'qty','')::numeric > 0 then
      l := l || jsonb_build_object('_iec', round(litros * grau / 100 * taxa, 4));
      iec_total := iec_total + (l->>'qty')::numeric * litros * grau / 100 * taxa;
    elsif nullif(l->>'price','') is not null and coalesce(l->>'desc','') !~* '(vasilhame|cau[cç][aã]o|dep[oó]sito)' then
      outras := outras + coalesce((l->>'qty')::numeric, 0) * (l->>'price')::numeric;
    end if;
    novas := novas || jsonb_build_array(l);
  end loop;
  if iec_total <= 0 then return p_fat; end if;
  if iec_total > falta then fator := falta / iec_total; end if;
  resto := falta - least(iec_total, falta);
  -- 2.ª volta: aplicar
  p_fat := jsonb_set(p_fat, '{linhas}', '[]'::jsonb);
  for l in select * from jsonb_array_elements(novas) loop
    p := nullif(l->>'price','')::numeric;
    if l ? '_iec' and p is not null then
      iec := round((l->>'_iec')::numeric * fator, 4);
      l := (l - '_iec') || jsonb_build_object('price', round(p + iec, 4), 'price_guara', coalesce(l->'price_guara', to_jsonb(p)), 'iec', iec, 'price_estimado', 'iec');
      n := n + 1;
    elsif p is not null and resto > 0.01 and outras > 0 and resto <= soma * 0.05 and coalesce(l->>'desc','') !~* '(vasilhame|cau[cç][aã]o|dep[oó]sito)' then
      l := l || jsonb_build_object('price', round(p * (1 + resto / outras), 4), 'price_guara', coalesce(l->'price_guara', to_jsonb(p)), 'price_estimado', 'iec');
    end if;
    p_fat := jsonb_set(p_fat, '{linhas}', (p_fat->'linhas') || jsonb_build_array(l));
  end loop;
  return p_fat || jsonb_build_object('iec', jsonb_build_object('falta', round(falta, 2), 'iec', round(least(iec_total, falta), 2), 'resto', round(resto, 2), 'linhas', n));
end $function$;
revoke all on function public.compras__guara_iec(jsonb) from public, anon, authenticated;

create or replace function public.compras_guara_receber(p_fat jsonb)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'public', 'extensions'
as $function$
declare gid int := nullif(p_fat->>'guara_id','')::int; sid uuid; numk text; l jsonb; novas int := 0; uteis int := 0; r jsonb;
begin
  if gid is null then raise exception 'sem_guara_id'; end if;
  if exists (select 1 from public.compras_guara_faturas where guara_id = gid) then return jsonb_build_object('estado', 'vista'); end if;
  p_fat := public.compras__guara_precos(public.compras__guara_iec(p_fat));
  sid := public.compras__fornecedor(p_fat->>'fornecedor_nome');
  numk := lower(regexp_replace(coalesce(p_fat->>'numero',''), '\s', '', 'g'));
  if sid is not null and numk <> '' and exists (select 1 from public.compras_invoices i where i.supplier_id = sid and lower(regexp_replace(coalesce(i.numero,''), '\s', '', 'g')) = numk) then
    insert into public.compras_guara_faturas (guara_id, fornecedor, numero, data, total, estado, dados, tratado_em)
    values (gid, coalesce(p_fat->>'fornecedor_nome',''), coalesce(p_fat->>'numero',''), nullif(p_fat->>'data','')::date, nullif(p_fat->>'total','')::numeric, 'ja_existia', p_fat, now());
    return jsonb_build_object('estado', 'ja_existia');
  end if;
  for l in select * from jsonb_array_elements(coalesce(p_fat->'linhas','[]')) loop
    if nullif(l->>'price','') is null then continue; end if;
    uteis := uteis + 1;
    if sid is null or (not exists (select 1 from public.compras_offers o where o.supplier_id = sid and lower(o.alias) = lower(l->>'desc'))
                       and not exists (select 1 from public.compras_offer_aliases a where a.supplier_id = sid and a.alias = lower(l->>'desc'))) then novas := novas + 1; end if;
  end loop;
  if uteis > 0 and novas = 0 then
    r := public.compras__import_invoice(public.compras__chefe_principal(), p_fat);
    insert into public.compras_guara_faturas (guara_id, fornecedor, numero, data, total, estado, dados, resultado, tratado_em)
    values (gid, coalesce(p_fat->>'fornecedor_nome',''), coalesce(p_fat->>'numero',''), nullif(p_fat->>'data','')::date, nullif(p_fat->>'total','')::numeric,
            case when r ? 'ignorada' then 'ja_existia' else 'importada' end, p_fat, r, now());
    return jsonb_build_object('estado', case when r ? 'ignorada' then 'ja_existia' else 'importada' end) || r;
  end if;
  insert into public.compras_guara_faturas (guara_id, fornecedor, numero, data, total, estado, dados, resultado, tratado_em)
  values (gid, coalesce(p_fat->>'fornecedor_nome',''), coalesce(p_fat->>'numero',''), nullif(p_fat->>'data','')::date, nullif(p_fat->>'total','')::numeric,
          case when uteis = 0 then 'ignorada' else 'pendente' end, p_fat,
          case when uteis = 0 then jsonb_build_object('motivo', 'sem_artigos_com_preco') else jsonb_build_object('linhas', uteis, 'novas', novas) end,
          case when uteis = 0 then now() end);
  return jsonb_build_object('estado', case when uteis = 0 then 'ignorada' else 'pendente' end, 'linhas', uteis, 'novas', novas);
end $function$;

-- Corrige o preço de linhas de uma fatura já gravada (ex.: o Guará leu o preço sem o IEC da Garcias).
-- p_precos: [{"desc": "...", "price": 11.95, "qty": 1 (opcional)}] (preço da embalagem sem IVA, como na linha).
-- Atualiza a linha (o preço antigo fica em price_guara e o motivo em price_corrigido), o histórico de preços dessa
-- fatura (na mesma proporção) e as ofertas desses produtos nesse fornecedor (último e anterior preço).
create or replace function public.compras__corrigir_fatura(p_invoice uuid, p_precos jsonb, p_motivo text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare inv public.compras_invoices; l jsonb; c jsonb; novas jsonb := '[]'::jsonb; n int := 0; pid uuid; velho numeric; novo numeric;
  afetados uuid[] := '{}';
begin
  select * into inv from public.compras_invoices where id = p_invoice for update;
  if not found then raise exception 'fatura_nao_existe'; end if;
  for l in select * from jsonb_array_elements(inv.linhas) loop
    c := null;
    select x into c from jsonb_array_elements(p_precos) x
     where lower(btrim(x->>'desc')) = lower(btrim(l->>'desc')) and (x->>'qty' is null or (x->>'qty')::numeric = (l->>'qty')::numeric) limit 1;
    velho := nullif(l->>'price', '')::numeric; novo := (c->>'price')::numeric;
    if c is not null and novo is not null and novo is distinct from velho then
      pid := coalesce(nullif(l->>'product_id','')::uuid,
        (select o.product_id from public.compras_offers o where o.supplier_id = inv.supplier_id and lower(o.alias) = lower(l->>'desc') limit 1),
        (select a.product_id from public.compras_offer_aliases a where a.supplier_id = inv.supplier_id and a.alias = lower(l->>'desc')));
      l := l || jsonb_build_object('price', novo, 'price_guara', coalesce(l->'price_guara', to_jsonb(velho)), 'price_corrigido', p_motivo);
      if pid is not null and velho > 0 then
        update public.compras_price_history set unit_price = round(unit_price * novo / velho, 6) where invoice_id = p_invoice and product_id = pid;
        afetados := afetados || pid;
      end if;
      n := n + 1;
    end if;
    novas := novas || jsonb_build_array(l);
  end loop;
  update public.compras_invoices set linhas = novas where id = p_invoice;
  -- ofertas: último preço e o anterior (de outra fatura), a partir do histórico
  update public.compras_offers o set unit_price = u.unit_price, pack_price = round(u.unit_price * o.pack_qty, 4), data = u.data, invoice_id = u.invoice_id,
         prev_unit_price = a.unit_price, prev_data = a.data
    from (select distinct on (h.product_id) h.product_id, h.unit_price, h.data, h.invoice_id from public.compras_price_history h
           where h.supplier_id = inv.supplier_id and h.product_id = any(afetados) order by h.product_id, h.data desc, h.id desc) u
    left join lateral (select h2.unit_price, h2.data from public.compras_price_history h2
           where h2.supplier_id = inv.supplier_id and h2.product_id = u.product_id and h2.invoice_id <> u.invoice_id order by h2.data desc, h2.id desc limit 1) a on true
   where o.product_id = u.product_id and o.supplier_id = inv.supplier_id;
  return jsonb_build_object('fatura', inv.numero, 'linhas_corrigidas', n, 'produtos', cardinality(afetados));
end $$;
revoke all on function public.compras__corrigir_fatura(uuid, jsonb, text) from public, anon, authenticated;

-- ===================== Descrições escritas de outra maneira e juntar produtos (18/11) =====================
-- Chave de uma descrição de fatura que ignora maiúsculas, acentos, pontuação e espaços, a vírgula/ponto decimal,
-- zeros à direita nas casas decimais (0,70 = 0.7) e uma letra entre parênteses no fim ("1 L (B)" = "1 L").
create or replace function public.compras__desc_chave(p text)
returns text language sql immutable set search_path = public as $$
  select btrim(regexp_replace(
    regexp_replace(
      regexp_replace(
        regexp_replace(
          regexp_replace(
            translate(lower(coalesce(p, '')), 'áàâãäéèêëíìîïóòôõöúùûüçñ', 'aaaaaeeeeiiiiooooouuuucn'),
            '\(\s*[a-z]\s*\)\s*$', ''),                 -- "(B)" no fim
          '([0-9])\s*[.,]\s*([0-9])', '\1.\2', 'g'),    -- 0,70 / 0.70 / 0 . 70
        '(\.[0-9]*?)0+(?![0-9])', '\1', 'g'),           -- 0.70 -> 0.7 ; 1.0 -> 1.
      '\.(?![0-9])|(?<![0-9])\.|[^a-z0-9.]+', ' ', 'g'),
    '\s+', ' ', 'g'))
$$;

-- Artigo de um fornecedor pela chave da descrição (só quando aponta para um único produto)
create or replace function public.compras__artigo_chave(p_sid uuid, p_desc text)
returns table(product_id uuid, pack_qty numeric) language sql stable security definer set search_path = public as $$
  with k as (select public.compras__desc_chave(p_desc) k),
  c as (select o.product_id, o.pack_qty from public.compras_offers o, k where o.supplier_id = p_sid and k.k <> '' and public.compras__desc_chave(o.alias) = k.k
        union all
        select a.product_id, a.pack_qty from public.compras_offer_aliases a, k where a.supplier_id = p_sid and k.k <> '' and public.compras__desc_chave(a.alias) = k.k)
  select c.product_id, max(c.pack_qty) from c group by c.product_id
  having (select count(distinct c2.product_id) from c c2) = 1
$$;
revoke all on function public.compras__artigo_chave(uuid, text) from public, anon, authenticated;

-- compras__save_invoice: depois da descrição exata (oferta e descrições alternativas), procura pela chave;
-- o preço anterior só se perde quando muda o artigo (chave diferente), não quando muda a pontuação
do $$
declare d text; d2 text;
begin
  d := pg_get_functiondef('public.compras__save_invoice'::regproc);
  d2 := d;
  if position('compras__artigo_chave' in d2) = 0 then
    d2 := regexp_replace(d2, '(a\.alias = lower\(l->>''desc''\);\s*end if;)',
      '\1
      -- a mesma descrição escrita de outra maneira (pontuação, espaços, 0,70/0.70, "(B)" no fim)
      if known_pid is null then select k.product_id, k.pack_qty into known_pid, known_pq from public.compras__artigo_chave(sid, l->>''desc'') k; end if;');
  end if;
  d2 := replace(d2, 'lower(coalesce(prev.alias,'''')) <> lower(coalesce(l->>''desc'',''''))',
                    'public.compras__desc_chave(prev.alias) <> public.compras__desc_chave(l->>''desc'')');
  if d2 <> d then execute d2; end if;
end $$;

-- compras_guara_receber: um artigo com a mesma chave não conta como novo
do $$
declare d text; d2 text;
begin
  d := pg_get_functiondef('public.compras_guara_receber'::regproc);
  if position('compras__artigo_chave' in d) = 0 then
    d2 := replace(d, 'and a.alias = lower(l->>''desc''))) then novas := novas + 1;',
      'and a.alias = lower(l->>''desc''))
                       and not exists (select 1 from public.compras__artigo_chave(sid, l->>''desc''))) then novas := novas + 1;');
    if d2 <> d then execute d2; end if;
  end if;
end $$;

-- Juntar produtos: guarda também a descrição do produto que fica, a data do preço anterior e passa as linhas das faturas
do $$
declare d text; d2 text;
begin
  d := pg_get_functiondef('public.compras__merge_products'::regproc);
  if position('compras_invoices' in d) = 0 then
    d2 := replace(d, 'prev_unit_price = cur.unit_price, data = o.data', 'prev_unit_price = cur.unit_price, prev_data = cur.data, data = o.data');
    d2 := replace(d2, 'if coalesce(o.data, ''1900-01-01''::date) > coalesce(cur.data, ''1900-01-01''::date) then',
      'if coalesce(cur.alias, '''') <> '''' then
          insert into public.compras_offer_aliases (supplier_id, alias, product_id, pack_qty, origem)
          values (cur.supplier_id, lower(cur.alias), p_into, cur.pack_qty, ''juntar'') on conflict (supplier_id, alias) do nothing;
        end if;
        if coalesce(o.data, ''1900-01-01''::date) > coalesce(cur.data, ''1900-01-01''::date) then');
    d2 := replace(d2, 'delete from public.compras_products where id = p_from;',
      'update public.compras_invoices set linhas = replace(linhas::text, p_from::text, p_into::text)::jsonb where linhas::text like ''%'' || p_from::text || ''%'';
  delete from public.compras_products where id = p_from;');
    execute d2;
  end if;
end $$;

-- ===================== Fornecedores com outros nomes e juntar fornecedores (19/11) =====================
-- Ex.: "CONTINENTE" e "MAKRO" são o fornecedor "Bernardo Mendes" (o dono vai comprar); "Genialis, Lda" é "Genialis".
create table if not exists public.compras_supplier_nomes (
  chave text primary key,
  supplier_id uuid not null references public.compras_suppliers(id) on delete cascade,
  nome text not null,
  criado_em timestamptz not null default now()
);
alter table public.compras_supplier_nomes enable row level security;

create or replace function public.compras__fornecedor_chave(p text)
returns text language sql immutable set search_path = public as $$
  select lower(regexp_replace(translate(coalesce(p,''), 'áàâãäéèêëíìîïóòôõöúùûüçñÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ', 'aaaaaeeeeiiiiooooouuuucnAAAAAEEEEIIIIOOOOOUUUUCN'), '[^A-Za-z0-9]', '', 'g'))
$$;

-- primeiro os outros nomes guardados (igual, começa por, ou contém com 6+ letras), depois a regra de sempre
create or replace function public.compras__fornecedor(p_nome text)
returns uuid language sql stable security definer set search_path to 'public', 'extensions' as $function$
  with k as (select lower(regexp_replace(trim(coalesce(p_nome,'')), '[^A-Za-z0-9]', '', 'g')) nk),
  al as (select n.supplier_id from public.compras_supplier_nomes n, k
          where k.nk <> '' and (n.chave = k.nk or n.chave = public.compras__fornecedor_chave(p_nome)
             or (length(n.chave) >= 4 and k.nk like n.chave || '%')
             or (length(n.chave) >= 6 and k.nk like '%' || n.chave || '%')) limit 1),
  s as (select id, created_at, lower(regexp_replace(nome, '[^A-Za-z0-9]', '', 'g')) sk from public.compras_suppliers)
  select coalesce((select supplier_id from al), (
  select s.id from s, k
   where k.nk <> '' and s.sk <> '' and (s.sk = k.nk
      or (length(k.nk) >= 4 and s.sk like k.nk || '%')
      or (length(s.sk) >= 4 and k.nk like s.sk || '%')
      or (length(k.nk) >= 6 and s.sk like '%' || k.nk || '%')
      or (length(s.sk) >= 6 and k.nk like '%' || s.sk || '%'))
   order by case when s.sk = k.nk then 0 when s.sk like k.nk || '%' or k.nk like s.sk || '%' then 1 else 2 end, s.created_at
   limit 1))
$function$;

-- Juntar dois fornecedores: tudo do p_from passa para p_into; o nome do p_from fica como outro nome do p_into.
create or replace function public.compras__merge_suppliers(p_from uuid, p_into uuid)
returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare f public.compras_suppliers; o public.compras_offers; cur public.compras_offers; n_of int := 0;
begin
  if p_from = p_into then return jsonb_build_object('igual', true); end if;
  select * into f from public.compras_suppliers where id = p_from;
  if not found then raise exception 'fornecedor_nao_existe'; end if;
  perform 1 from public.compras_suppliers where id = p_into; if not found then raise exception 'fornecedor_nao_existe'; end if;
  insert into public.compras_offer_aliases (supplier_id, alias, product_id, pack_qty, origem, atualizado_em)
    select p_into, a.alias, a.product_id, a.pack_qty, coalesce(a.origem, 'juntar'), a.atualizado_em from public.compras_offer_aliases a where a.supplier_id = p_from
    on conflict (supplier_id, alias) do nothing;
  delete from public.compras_offer_aliases where supplier_id = p_from;
  for o in select * from public.compras_offers where supplier_id = p_from loop
    if coalesce(o.alias, '') <> '' then
      insert into public.compras_offer_aliases (supplier_id, alias, product_id, pack_qty, origem)
      values (p_into, lower(o.alias), o.product_id, o.pack_qty, 'juntar') on conflict (supplier_id, alias) do nothing;
    end if;
    select * into cur from public.compras_offers where product_id = o.product_id and supplier_id = p_into;
    if not found then
      update public.compras_offers set supplier_id = p_into where product_id = o.product_id and supplier_id = p_from;
    else
      if coalesce(cur.alias, '') <> '' then
        insert into public.compras_offer_aliases (supplier_id, alias, product_id, pack_qty, origem)
        values (p_into, lower(cur.alias), cur.product_id, cur.pack_qty, 'juntar') on conflict (supplier_id, alias) do nothing;
      end if;
      if coalesce(o.data, '1900-01-01'::date) > coalesce(cur.data, '1900-01-01'::date) then
        update public.compras_offers set alias = o.alias, codigo = o.codigo, pack_qty = o.pack_qty, pack_price = o.pack_price, unit_price = o.unit_price,
          prev_unit_price = cur.unit_price, prev_data = cur.data, data = o.data, invoice_id = o.invoice_id,
          nome_encomenda = coalesce(nullif(cur.nome_encomenda, ''), o.nome_encomenda)
         where product_id = o.product_id and supplier_id = p_into;
      end if;
      delete from public.compras_offers where product_id = o.product_id and supplier_id = p_from;
    end if;
    n_of := n_of + 1;
  end loop;
  update public.compras_price_history set supplier_id = p_into where supplier_id = p_from;
  update public.compras_invoices set supplier_id = p_into where supplier_id = p_from;
  update public.compras_orders set supplier_id = p_into where supplier_id = p_from;
  update public.compras_suppliers s set nif = case when coalesce(s.nif,'') = '' then coalesce(f.nif,'') else s.nif end,
    telefone = case when coalesce(s.telefone,'') = '' then coalesce(f.telefone,'') else s.telefone end,
    dias = case when coalesce(s.dias,'') = '' then coalesce(f.dias,'') else s.dias end,
    minimo = coalesce(s.minimo, f.minimo),
    mensagem = case when coalesce(s.mensagem,'') = '' then coalesce(f.mensagem,'') else s.mensagem end
   where s.id = p_into;
  update public.compras_supplier_nomes set supplier_id = p_into where supplier_id = p_from;
  insert into public.compras_supplier_nomes (chave, supplier_id, nome) values (public.compras__fornecedor_chave(f.nome), p_into, f.nome)
    on conflict (chave) do update set supplier_id = excluded.supplier_id;
  delete from public.compras_suppliers where id = p_from;
  return jsonb_build_object('ofertas', n_of, 'de', f.nome);
end $$;
revoke all on function public.compras__merge_suppliers(uuid, uuid) from public, anon, authenticated;

-- Gravar fatura sem fornecedor escolhido: antes de criar um fornecedor novo, procura pelos outros nomes e pelo nome sem "Lda", "S.A."
do $$
declare d text; d2 text;
begin
  d := pg_get_functiondef('public.compras__save_invoice'::regproc);
  if position('compras_supplier_nomes' in d) = 0 then
    d2 := replace(d, '  if sid is null then
    insert into public.compras_suppliers (nome, nif)',
'  if sid is null and coalesce(trim(p_inv->>''fornecedor_nome''), '''') <> '''' then
    select n.supplier_id into sid from public.compras_supplier_nomes n where n.chave = public.compras__fornecedor_chave(p_inv->>''fornecedor_nome'')
        or (length(n.chave) >= 4 and public.compras__fornecedor_chave(p_inv->>''fornecedor_nome'') like n.chave || ''%'')
     order by length(n.chave) desc limit 1;
    if sid is null then
      select s.id into sid from public.compras_suppliers s
       where public.compras__fornecedor_chave(regexp_replace(s.nome, ''[,.]?\s*(lda|limitada|s\.?\s*a|unipessoal|unip)\.?\s*$'', '''', ''i''))
           = public.compras__fornecedor_chave(regexp_replace(p_inv->>''fornecedor_nome'', ''[,.]?\s*(lda|limitada|s\.?\s*a|unipessoal|unip)\.?\s*$'', '''', ''i''))
       order by s.created_at limit 1;
    end if;
  end if;
  if sid is null then
    insert into public.compras_suppliers (nome, nif)');
    if d2 <> d then execute d2; end if;
  end if;
end $$;

-- Entregas por semana de cada fornecedor (escrito em Gestão; vazio = estimado pelas faturas) e texto extra/entregas no gravar fornecedor
alter table public.compras_suppliers add column if not exists entregas_semana numeric;
drop function if exists public.compras_save_supplier(text, uuid, text, text, text, text, numeric, text, text);
create or replace function public.compras_save_supplier(p_token text, p_id uuid, p_nome text, p_telefone text, p_dias text, p_nif text,
  p_minimo numeric default null, p_via text default null, p_mensagem text default null, p_entregas numeric default null)
returns uuid language plpgsql security definer set search_path to 'public', 'extensions' as $function$
declare u public.compras_users; rid uuid; v_via text := case when p_via in ('numero','grupo') then p_via end;
begin
  u := public.compras__chefe(p_token);
  if coalesce(trim(p_nome),'') = '' then raise exception 'nome_obrigatorio'; end if;
  if p_minimo is not null and p_minimo < 0 then raise exception 'preco_invalido'; end if;
  if p_entregas is not null and (p_entregas < 0 or p_entregas > 14) then raise exception 'preco_invalido'; end if;
  if p_id is null then
    insert into public.compras_suppliers (nome, telefone, dias, nif, minimo, via, mensagem, entregas_semana)
    values (trim(p_nome), coalesce(trim(p_telefone),''), coalesce(trim(p_dias),''), regexp_replace(coalesce(p_nif,''),'\D','','g'),
            nullif(p_minimo, 0), coalesce(v_via, 'numero'), left(coalesce(trim(p_mensagem), ''), 300), nullif(p_entregas, 0))
    returning id into rid;
  else
    update public.compras_suppliers set nome = trim(p_nome), telefone = coalesce(trim(p_telefone),''), dias = coalesce(trim(p_dias),''),
      nif = regexp_replace(coalesce(p_nif,''),'\D','','g'), minimo = case when p_minimo is null then minimo else nullif(p_minimo, 0) end,
      via = coalesce(v_via, via), mensagem = case when p_mensagem is null then mensagem else left(trim(p_mensagem), 300) end,
      entregas_semana = case when p_entregas is null then entregas_semana else nullif(p_entregas, 0) end
    where id = p_id returning id into rid;
  end if;
  return rid;
end $function$;
grant execute on function public.compras_save_supplier(text, uuid, text, text, text, text, numeric, text, text, numeric) to anon, authenticated;

-- ===================== Contagem em garrafas/barris/un, armazém, data certa, ritmo de entradas (19/11) =====================
alter table public.compras_products add column if not exists contar_em text, add column if not exists contar_fator numeric;
alter table public.compras_stock_count_lines add column if not exists contado numeric, add column if not exists fator numeric not null default 1;

-- Forma de contar: o que se conta na prateleira e quantas unidades do produto vale cada um (contar_em/contar_fator mandam se existirem;
-- senão, produtos em L contam-se em garrafas/barris/latas/embalagens com o volume do nome ou da embalagem; o resto na unidade do produto)
create or replace function public.compras__contar(p_id uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  with p as (select * from public.compras_products where id = p_id),
  o as (select o.pack_qty from public.compras_offers o where o.product_id = p_id order by o.data desc nulls last limit 1),
  nm as (select regexp_match(p.nome, '([0-9]+(?:[.,][0-9]+)?)\s*(l|lt|cl|ml)\y', 'i') m from p),
  v as (select coalesce(
          (select case when lower(nm.m[2]) = 'cl' then replace(nm.m[1], ',', '.')::numeric / 100
                       when lower(nm.m[2]) = 'ml' then replace(nm.m[1], ',', '.')::numeric / 1000
                       else replace(nm.m[1], ',', '.')::numeric end from nm where nm.m is not null),
          (select o.pack_qty from o where o.pack_qty > 0 and o.pack_qty <= 60)) vol)
  select case
    when p.contar_em is not null and p.contar_fator > 0 then jsonb_build_object('em', p.contar_em, 'fator', p.contar_fator)
    when p.unidade = 'L' and (select vol from v) > 0 then
      jsonb_build_object('em', case when p.nome ~* 'barril' then 'barril' when p.nome ~* 'lata' then 'lata' when (select vol from v) >= 5 then 'embalagem' else 'garrafa' end,
                         'fator', (select vol from v))
    else jsonb_build_object('em', p.unidade, 'fator', 1) end
  from p
$$;
revoke all on function public.compras__contar(uuid) from public, anon, authenticated;

-- p_unidades = true: p_qty vem na forma de contar (ex.: 1,5 garrafas) e grava-se qty = p_qty × fator; sítios + armazém
drop function if exists public.compras_count_set(text, uuid, uuid, text, numeric);
create or replace function public.compras_count_set(p_token text, p_count uuid, p_product uuid, p_setor text, p_qty numeric, p_unidades boolean default false)
returns void language plpgsql security definer set search_path to 'public', 'extensions' as $function$
declare u public.compras_users; f numeric := 1;
begin
  u := public.compras__user(p_token);
  if not exists (select 1 from public.compras_stock_counts where id = p_count and fechada_em is null) then raise exception 'contagem_fechada'; end if;
  if p_setor not in ('cozinha','sushi','bar','takeaway','armazem') then raise exception 'setor_invalido'; end if;
  if p_qty is null then
    delete from public.compras_stock_count_lines where count_id = p_count and product_id = p_product and setor = p_setor;
  else
    if p_qty < 0 then raise exception 'quantidade_invalida'; end if;
    if p_unidades then f := coalesce(nullif((public.compras__contar(p_product)->>'fator')::numeric, 0), 1); end if;
    insert into public.compras_stock_count_lines (count_id, product_id, setor, qty, contado, fator, updated_by, updated_at)
    values (p_count, p_product, p_setor, p_qty * f, case when p_unidades then p_qty end, f, u.id, now())
    on conflict (count_id, product_id, setor) do update set qty = excluded.qty, contado = excluded.contado, fator = excluded.fator, updated_by = excluded.updated_by, updated_at = now();
  end if;
end $function$;
grant execute on function public.compras_count_set(text, uuid, uuid, text, numeric, boolean) to anon, authenticated;

do $$
declare d text; d2 text;
begin
  d := pg_get_functiondef('public.compras_count_get'::regproc);
  if position('''contado'', l.contado' in d) = 0 then
    d2 := replace(d, '''qty'', l.qty,', '''qty'', l.qty, ''contado'', l.contado, ''fator'', l.fator,');
    if d2 <> d then execute d2; end if;
  end if;
end $$;

-- Stock: um produto contado conta a partir do momento em que foi contado. Vendas: contado antes das 17h entram as desse dia,
-- depois só as do dia seguinte. Faturas: contado antes das 10h entram as desse dia.
create or replace function public.compras__stock_rows()
returns table(product_id uuid, base date, base_q numeric, contado boolean, entradas numeric, saidas numeric, stock numeric, consumo_dia numeric)
language sql stable set search_path to 'public' as $function$
  with ini as (select coalesce((select stock_inicio from public.compras_settings where id = 1), current_date) d),
  lastc as (
    select distinct on (l.product_id) l.product_id, c.id cid
      from public.compras_stock_count_lines l join public.compras_stock_counts c on c.id = l.count_id
     where c.fechada_em is not null order by l.product_id, c.created_at desc),
  lc as (select lastc.product_id, x.q, x.t
           from lastc, lateral (select sum(y.qty) q, max(y.updated_at at time zone 'Europe/Lisbon') t
                                  from public.compras_stock_count_lines y where y.count_id = lastc.cid and y.product_id = lastc.product_id) x),
  cons as materialized (select * from public.compras__consumption()),
  win as (select max(dia) mx, greatest(1, count(distinct dia) filter (where dia > (select max(dia) from public.compras_sales) - 28)) nd from public.compras_sales),
  b as (select p.id, coalesce(lc.t::date, (select d from ini)) base, coalesce(lc.q, 0) base_q, lc.t is not null contado,
          case when lc.t is null then (select d from ini) when lc.t::time < time '17:00' then lc.t::date else lc.t::date + 1 end cons_desde,
          case when lc.t is null then (select d from ini) when lc.t::time < time '10:00' then lc.t::date else lc.t::date + 1 end entr_desde
          from public.compras_products p left join lc on lc.product_id = p.id)
  select b.id, b.base, b.base_q, b.contado, coalesce(e.q, 0), coalesce(s.q, 0), b.base_q + coalesce(e.q, 0) - coalesce(s.q, 0), coalesce(c.q, 0) / (select nd from win)
    from b
    left join lateral (select sum(pl.qty) q from public.compras_purchase_lines pl where pl.product_id = b.id and pl.data >= b.entr_desde) e on true
    left join lateral (select sum(cons.qty) q from cons where cons.product_id = b.id and cons.dia >= b.cons_desde) s on true
    left join lateral (select sum(cons.qty) q from cons where cons.product_id = b.id and cons.dia > (select mx from win) - 28) c on true
$function$;

-- Quanto entra por semana (últimas 4 semanas) e quantas vezes por semana entrega o fornecedor da última compra
drop function if exists public.compras__entradas_freq();
create or replace function public.compras__entradas_freq()
returns table(product_id uuid, entra_semana numeric, entregas_semana numeric, ultima_entrega date, supplier_id uuid)
language sql stable set search_path to 'public' as $$
  with pl as (select pl.product_id, pl.qty, pl.data, i.supplier_id from public.compras_purchase_lines pl join public.compras_invoices i on i.id = pl.invoice_id where pl.qty > 0),
  est as (select i.supplier_id, round(count(distinct i.data)::numeric / 4, 2) ent from public.compras_invoices i
           where i.data > current_date - 28 and coalesce(i.total, 0) >= 0 group by 1),
  ult as (select distinct on (pl.product_id) pl.product_id, pl.supplier_id, pl.data from pl order by pl.product_id, pl.data desc),
  ent as (select pl.product_id, round(sum(pl.qty) / 4, 3) q from pl where pl.data > current_date - 28 group by 1)
  select u.product_id, e.q, coalesce(sp.entregas_semana, s.ent), u.data, u.supplier_id
    from ult u left join ent e on e.product_id = u.product_id left join est s on s.supplier_id = u.supplier_id
    left join public.compras_suppliers sp on sp.id = u.supplier_id
$$;

create or replace function public.compras_stock(p_token text)
returns jsonb language plpgsql security definer set search_path to 'public', 'extensions' as $function$
declare u public.compras_users;
begin
  u := public.compras__user(p_token);
  return jsonb_build_object(
    'inicio', (select stock_inicio from public.compras_settings where id = 1),
    'vendas_ate', (select max(dia) from public.compras_sales),
    'vendas_desde', (select min(dia) from public.compras_sales),
    'sem_receita', (select count(*) from public.compras_zs_items z where not z.ignorar and z.recipe_guara_id is null and z.product_id is null
                      and exists (select 1 from public.compras_sales s where s.codigo = z.codigo and s.dia > current_date - 35)),
    'contagem_aberta', (select c.id from public.compras_stock_counts c where c.fechada_em is null),
    'ultima_contagem', (select max(fechada_em) from public.compras_stock_counts),
    'produtos', coalesce((select jsonb_agg(jsonb_build_object('id', r.product_id, 'base', r.base, 'base_q', round(r.base_q, 3), 'contado', r.contado,
                 'entradas', round(r.entradas, 3), 'saidas', round(r.saidas, 3), 'stock', round(r.stock, 3), 'consumo_dia', round(r.consumo_dia, 4),
                 'entra_semana', f.entra_semana, 'entregas_semana', f.entregas_semana, 'ultima_entrega', f.ultima_entrega))
                 from public.compras__stock_rows() r left join public.compras__entradas_freq() f on f.product_id = r.product_id
                where r.entradas <> 0 or r.saidas <> 0 or r.contado or r.consumo_dia <> 0 or f.entra_semana is not null), '[]'::jsonb));
end $function$;

-- O catálogo leva a forma de contar de cada produto e as entregas por semana de cada fornecedor
do $$
declare d text; d2 text;
begin
  d := pg_get_functiondef('public.compras_catalog'::regproc);
  d2 := d;
  if position('compras__contar' in d2) = 0 then
    d2 := replace(d2, '''setores'', to_jsonb(p.setores),', '''setores'', to_jsonb(p.setores), ''contar'', public.compras__contar(p.id),');
  end if;
  if position('''entregas_semana'', s.entregas_semana' in d2) = 0 then
    d2 := replace(d2, '''mensagem'', s.mensagem)', '''mensagem'', s.mensagem, ''entregas_semana'', s.entregas_semana)');
  end if;
  if d2 <> d then execute d2; end if;
end $$;

-- ===================== Contagem sem sítios, com somas (19/11) =====================
-- Uma lista só; cada vez que se escreve uma quantidade soma-se ao que já estava (10 águas na cozinha + 10 no armazém = 20).
-- Cada soma fica em parcelas (na forma de contar); a linha fica no "sítio" 'geral'; ↶ tira a última.
alter table public.compras_stock_count_lines add column if not exists parcelas numeric[];

create or replace function public.compras__count_estado(p_count uuid, p_product uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object('product_id', p_product, 'setor', 'geral', 'qty', l.qty, 'contado', l.contado, 'fator', l.fator, 'parcelas', to_jsonb(l.parcelas),
           'por', (select nome from public.compras_users where id = l.updated_by), 'em', l.updated_at)
    from public.compras_stock_count_lines l where l.count_id = p_count and l.product_id = p_product and l.setor = 'geral'
$$;
revoke all on function public.compras__count_estado(uuid, uuid) from public, anon, authenticated;

create or replace function public.compras_count_add(p_token text, p_count uuid, p_product uuid, p_qty numeric)
returns jsonb language plpgsql security definer set search_path to 'public', 'extensions' as $function$
declare u public.compras_users; f numeric; ant numeric[]; tot numeric;
begin
  u := public.compras__user(p_token);
  perform 1 from public.compras_stock_counts where id = p_count and fechada_em is null for update;
  if not found then raise exception 'contagem_fechada'; end if;
  if p_qty is null or p_qty = 0 or abs(p_qty) > 100000 then raise exception 'quantidade_invalida'; end if;
  if not exists (select 1 from public.compras_products where id = p_product) then raise exception 'produto_nao_existe'; end if;
  f := coalesce(nullif((public.compras__contar(p_product)->>'fator')::numeric, 0), 1);
  select coalesce(array_agg(x order by o), '{}') into ant from (
    select l.updated_at o, unnest(case when l.parcelas is not null then l.parcelas
                                       when l.contado is not null and coalesce(l.fator, 1) = f then array[l.contado]
                                       else array[round(l.qty / f, 3)] end) x
      from public.compras_stock_count_lines l where l.count_id = p_count and l.product_id = p_product) t;
  ant := ant || round(p_qty, 3);
  select sum(v) into tot from unnest(ant) v;
  if tot < 0 then raise exception 'quantidade_invalida'; end if;
  delete from public.compras_stock_count_lines where count_id = p_count and product_id = p_product;
  insert into public.compras_stock_count_lines (count_id, product_id, setor, qty, contado, fator, parcelas, updated_by, updated_at)
  values (p_count, p_product, 'geral', tot * f, tot, f, ant, u.id, now());
  return public.compras__count_estado(p_count, p_product);
end $function$;
grant execute on function public.compras_count_add(text, uuid, uuid, numeric) to anon, authenticated;

create or replace function public.compras_count_undo(p_token text, p_count uuid, p_product uuid)
returns jsonb language plpgsql security definer set search_path to 'public', 'extensions' as $function$
declare u public.compras_users; l public.compras_stock_count_lines; ps numeric[]; tot numeric;
begin
  u := public.compras__user(p_token);
  perform 1 from public.compras_stock_counts where id = p_count and fechada_em is null for update;
  if not found then raise exception 'contagem_fechada'; end if;
  select * into l from public.compras_stock_count_lines where count_id = p_count and product_id = p_product and setor = 'geral';
  if not found or coalesce(array_length(l.parcelas, 1), 0) <= 1 then
    delete from public.compras_stock_count_lines where count_id = p_count and product_id = p_product;
    return null;
  end if;
  ps := l.parcelas[1:array_length(l.parcelas, 1) - 1];
  select sum(v) into tot from unnest(ps) v;
  update public.compras_stock_count_lines set parcelas = ps, contado = tot, qty = tot * l.fator, updated_by = u.id, updated_at = now()
   where count_id = p_count and product_id = p_product and setor = 'geral';
  return public.compras__count_estado(p_count, p_product);
end $function$;
grant execute on function public.compras_count_undo(text, uuid, uuid) to anon, authenticated;

do $$
declare d text; d2 text;
begin
  d := pg_get_functiondef('public.compras_count_get'::regproc);
  if position('''parcelas''' in d) = 0 then
    d2 := replace(d, '''fator'', l.fator,', '''fator'', l.fator, ''parcelas'', to_jsonb(l.parcelas),');
    if d2 <> d then execute d2; end if;
  end if;
  d := pg_get_functiondef('public.compras_count_set'::regproc);
  d2 := d;
  if position('''geral''' in d2) = 0 then d2 := replace(d2, '''takeaway'',''armazem'')', '''takeaway'',''armazem'',''geral'')'); end if;
  if position('parcelas = null' in d2) = 0 then d2 := replace(d2, 'fator = excluded.fator,', 'fator = excluded.fator, parcelas = null,'); end if;
  if d2 <> d then execute d2; end if;
end $$;

-- ===================== Faturas antigas (jan–ago 2026) lidas no documento com a IA, em segundo plano (19/11) =====================
-- O Guará só tem as linhas das faturas desde o fim de agosto; as de janeiro a agosto estão só em imagem ("Linhas: Inativa").
-- A função compras-guara-doc com {"fila": true} lê-as uma a uma (Gemini) e grava o resultado aqui. Quando a Gemini diz que o
-- limite acabou, marca uma pausa em compras_guara_doc_estado e o pg_cron (compras__doc_fila_disparar) volta quando a pausa passar.
-- Depois, os artigos que ainda não existem entram como produto + oferta com o preço final (sem faturas nem stock).
create table if not exists public.compras_guara_doc_fila (
  guara_id integer primary key,
  fornecedor text not null,
  numero text,
  data date,
  total numeric,
  sem_iva numeric,
  estado text not null default 'pendente' check (estado in ('pendente','a_ler','lida','erro','sem_documento','tratada')),
  tentativas integer not null default 0,
  a_ler_desde timestamptz,
  modelo text,
  resultado jsonb,
  erro text,
  lida_em timestamptz,
  criado_em timestamptz not null default now()
);
alter table public.compras_guara_doc_fila enable row level security;
create index if not exists compras_guara_doc_fila_estado on public.compras_guara_doc_fila (estado, data desc);

create table if not exists public.compras_guara_doc_estado (
  id boolean primary key default true check (id),
  pausa_ate timestamptz,
  motivo text,
  ultimo jsonb,
  atualizado_em timestamptz not null default now()
);
alter table public.compras_guara_doc_estado enable row level security;
insert into public.compras_guara_doc_estado (id) values (true) on conflict do nothing;

create or replace function public.compras__doc_fila_proximas(p_n integer)
returns setof public.compras_guara_doc_fila language plpgsql security definer set search_path = public as $$
begin
  update public.compras_guara_doc_fila set estado = 'pendente', a_ler_desde = null
   where estado = 'a_ler' and a_ler_desde < now() - interval '15 minutes';
  if (select pausa_ate from public.compras_guara_doc_estado) > now() then return; end if;
  return query
  update public.compras_guara_doc_fila f set estado = 'a_ler', a_ler_desde = now(), tentativas = f.tentativas + 1
   where f.guara_id in (select guara_id from public.compras_guara_doc_fila where estado = 'pendente'
                         order by data desc nulls last, guara_id desc limit greatest(1, least(p_n, 20)) for update skip locked)
  returning f.*;
end $$;

create or replace function public.compras__doc_fila_gravar(p_guara_id integer, p_estado text, p_resultado jsonb, p_erro text, p_modelo text)
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.compras_guara_doc_fila
     set estado = case when p_estado = 'pendente_limite' then 'pendente'
                       when p_estado = 'pendente' and tentativas >= 5 then 'erro' else p_estado end,
         tentativas = case when p_estado = 'pendente_limite' then greatest(0, tentativas - 1) else tentativas end,
         resultado = coalesce(p_resultado, resultado), erro = p_erro, modelo = coalesce(p_modelo, modelo),
         a_ler_desde = null, lida_em = case when p_estado = 'lida' then now() else lida_em end
   where guara_id = p_guara_id;
end $$;

create or replace function public.compras__doc_fila_pausa(p_ate timestamptz, p_motivo text)
returns void language sql security definer set search_path = public as $$
  update public.compras_guara_doc_estado set pausa_ate = p_ate, motivo = p_motivo, atualizado_em = now();
$$;

create or replace function public.compras__doc_fila_registo(p_info jsonb)
returns void language sql security definer set search_path = public as $$
  update public.compras_guara_doc_estado set ultimo = p_info, atualizado_em = now();
$$;

create or replace function public.compras__doc_fila_disparar()
returns text language plpgsql security definer set search_path = public, extensions as $$
declare n int;
begin
  select count(*) into n from public.compras_guara_doc_fila where estado in ('pendente','a_ler');
  if n = 0 then
    perform cron.unschedule('compras-guara-doc-fila');
    return 'acabou';
  end if;
  if (select pausa_ate from public.compras_guara_doc_estado) > now() then return 'pausa'; end if;
  if exists (select 1 from public.compras_guara_doc_fila where estado = 'a_ler' and a_ler_desde > now() - interval '4 minutes') then return 'a_ler'; end if;
  perform net.http_post(
    url := 'https://cckgrpmspyurgmbgtjdu.supabase.co/functions/v1/compras-guara-doc',
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-zs-key', (select chave from public.compras_zs_cfg limit 1)),
    body := jsonb_build_object('fila', true),
    timeout_milliseconds := 300000);
  return 'pedido';
end $$;

revoke all on function public.compras__doc_fila_proximas(integer) from public, anon, authenticated;
revoke all on function public.compras__doc_fila_gravar(integer, text, jsonb, text, text) from public, anon, authenticated;
revoke all on function public.compras__doc_fila_pausa(timestamptz, text) from public, anon, authenticated;
revoke all on function public.compras__doc_fila_registo(jsonb) from public, anon, authenticated;
revoke all on function public.compras__doc_fila_disparar() from public, anon, authenticated;

-- Artigos das faturas antigas (jan–ago): preço final por linha, artigos por ligar, ligar a produto (sem faturas nem stock)
create or replace function public.compras__num(p text)
returns numeric language plpgsql immutable as $$
declare t text := regexp_replace(coalesce(p, ''), '[^0-9,.\-]', '', 'g');
begin
  if t = '' or t = '-' then return null; end if;
  if t like '%,%' then t := replace(replace(t, '.', ''), ',', '.'); end if;
  return t::numeric;
exception when others then return null;
end $$;

create table if not exists public.compras_antigas_decisoes (
  supplier_id uuid not null references public.compras_suppliers(id) on delete cascade,
  chave text not null,
  descricao text not null,
  product_id uuid references public.compras_products(id) on delete set null,
  ignorar boolean not null default false,
  motivo text,
  decidido_em timestamptz not null default now(),
  primary key (supplier_id, chave)
);
alter table public.compras_antigas_decisoes enable row level security;
-- compras__antigas_linhas(), compras_antigas_por_ligar(), compras__antigas_ligar(fornecedor, descricao, produto, nome, unidade,
-- categoria, pack) e compras__antigas_ignorar(fornecedor, descricao, motivo): ver a migration compras_faturas_antigas_artigos.
