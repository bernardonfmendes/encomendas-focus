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
  constraint compras_suppliers_pkey PRIMARY KEY (id),
  constraint compras_suppliers_minimo_check CHECK (((minimo IS NULL) OR (minimo > (0)::numeric)))
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
  constraint compras_orders_pkey PRIMARY KEY (id),
  constraint compras_orders_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES compras_users(id) ON DELETE SET NULL,
  constraint compras_orders_created_by_fkey FOREIGN KEY (created_by) REFERENCES compras_users(id) ON DELETE SET NULL,
  constraint compras_orders_supplier_id_fkey FOREIGN KEY (supplier_id) REFERENCES compras_suppliers(id) ON DELETE SET NULL,
  constraint compras_orders_status_check CHECK ((status = ANY (ARRAY['pendente'::text, 'aprovada'::text, 'rejeitada'::text, 'enviada'::text])))
);
alter table public.compras_orders enable row level security;

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
    'suppliers', coalesce((select jsonb_agg(jsonb_build_object('id', s.id, 'nome', s.nome, 'telefone', s.telefone, 'dias', s.dias, 'nif', s.nif, 'minimo', s.minimo) order by lower(s.nome)) from public.compras_suppliers s), '[]'),
    'products', coalesce((select jsonb_agg(jsonb_build_object(
        'id', p.id, 'nome', p.nome, 'categoria', p.categoria, 'unidade', p.unidade, 'setores', to_jsonb(p.setores),
        'offers', coalesce((select jsonb_agg(jsonb_build_object('supplier_id', o.supplier_id, 'alias', o.alias, 'codigo', o.codigo,
             'pack_qty', o.pack_qty, 'pack_price', o.pack_price, 'unit_price', o.unit_price, 'prev_unit_price', o.prev_unit_price, 'data', o.data)
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
CREATE OR REPLACE FUNCTION public.compras_order_decide(p_token text, p_id uuid, p_status text, p_items jsonb, p_entrega date)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare u public.compras_users;
begin
  u := public.compras__chefe(p_token);
  if p_status not in ('aprovada','rejeitada','enviada') then raise exception 'estado_invalido'; end if;
  update public.compras_orders set
    status = p_status,
    items = case when p_items is not null and jsonb_typeof(p_items) = 'array' then p_items else items end,
    entrega = case when p_status = 'enviada' then entrega else p_entrega end,
    approved_by = case when p_status in ('aprovada','rejeitada') then u.id else approved_by end,
    approved_at = case when p_status in ('aprovada','rejeitada') then now() else approved_at end,
    sent_at = case when p_status = 'enviada' then now() else sent_at end
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
         'minimo', s.minimo, 'items', o.items, 'nota', o.nota, 'status', o.status, 'entrega', o.entrega,
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
begin
  u := public.compras__chefe(p_token);
  d := coalesce(nullif(p_inv->>'data','')::date, current_date);
  v_nif := regexp_replace(coalesce(p_inv->>'nif',''), '\D', '', 'g');
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
          nullif(p_inv->>'total','')::numeric, coalesce(p_inv->'linhas','[]'::jsonb), u.id);
  for l in select * from jsonb_array_elements(coalesce(p_inv->'linhas','[]'::jsonb)) loop
    pp := nullif(l->>'price','')::numeric;
    pq := coalesce(nullif(l->>'pack_qty','')::numeric, 1);
    if pq <= 0 then pq := 1; end if;
    if pp is null or pp < 0 then continue; end if;
    up := pp / pq;
    pid := nullif(l->>'product_id','')::uuid;
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
    insert into public.compras_price_history (product_id, supplier_id, data, unit_price, invoice_id) values (pid, sid, d, up, inv);
    select * into prev from public.compras_offers o where o.product_id = pid and o.supplier_id = sid;
    if not found then
      insert into public.compras_offers (product_id, supplier_id, alias, codigo, pack_qty, pack_price, unit_price, prev_unit_price, data, invoice_id)
      values (pid, sid, coalesce(l->>'desc',''), coalesce(l->>'codigo',''), pq, pp, up, null, d, inv);
    elsif prev.data is null or d >= prev.data then
      update public.compras_offers o set alias = coalesce(l->>'desc',''), codigo = coalesce(l->>'codigo',''), pack_qty = pq, pack_price = pp,
        unit_price = up, prev_unit_price = case when prev.invoice_id = inv then prev.prev_unit_price else prev.unit_price end, data = d, invoice_id = inv
       where o.product_id = pid and o.supplier_id = sid;
    end if;
    n := n + 1;
  end loop;
  return jsonb_build_object('invoice_id', inv, 'supplier_id', sid, 'linhas', n);
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
CREATE OR REPLACE FUNCTION public.compras_save_supplier(p_token text, p_id uuid, p_nome text, p_telefone text, p_dias text, p_nif text, p_minimo numeric DEFAULT NULL::numeric)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare u public.compras_users; rid uuid;
begin
  u := public.compras__chefe(p_token);
  if coalesce(trim(p_nome),'') = '' then raise exception 'nome_obrigatorio'; end if;
  if p_minimo is not null and p_minimo < 0 then raise exception 'preco_invalido'; end if;
  -- p_minimo: null = não mexer; 0 = sem mínimo
  if p_id is null then
    insert into public.compras_suppliers (nome, telefone, dias, nif, minimo) values (trim(p_nome), coalesce(trim(p_telefone),''), coalesce(trim(p_dias),''), regexp_replace(coalesce(p_nif,''),'\D','','g'), nullif(p_minimo, 0)) returning id into rid;
  else
    update public.compras_suppliers set nome = trim(p_nome), telefone = coalesce(trim(p_telefone),''), dias = coalesce(trim(p_dias),''), nif = regexp_replace(coalesce(p_nif,''),'\D','','g'),
      minimo = case when p_minimo is null then minimo else nullif(p_minimo, 0) end
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
