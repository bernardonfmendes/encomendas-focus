# Tarefa agendada: correspondência diária

Corre todos os dias às 10:47 (Lisboa), numa sessão nova do Claude na nuvem, depois das importações automáticas
(vendas do ZSbms às 10:10, faturas do Guará às 10:30, receitas às 10:35). Precisa do conector Supabase.
Texto da tarefa (é este o que está guardado na tarefa agendada "Correspondência diária das compras (Guará e ZSbms)"):

```
Tarefa diária da app de compras do restaurante Focus Sushi & Steak: fazer a correspondência do que entrou hoje do Guará e do ZSbms. Responde em português de Portugal, curto.

Regras: usa só o conector Supabase (ferramentas mcp__Supabase__*, carrega-as com ToolSearch), projeto cckgrpmspyurgmbgtjdu, e só tabelas e funções compras_* (o mesmo projeto tem outra app: não mexas em mais nada). Se o conector Supabase não estiver disponível, para e diz isso no resumo. Nunca escrevas PINs, chaves ou palavras-passe. Não alteres funções nem estrutura; só dados, com as funções indicadas. Se uma decisão não for clara, não a tomes: deixa por decidir e diz no resumo.

0. Ver como correu a importação desta manhã: select faturas_em, faturas, receitas_em, receitas from compras_guara_cfg; e select ultima_em, ultimo from compras_zs_cfg. Se alguma tiver ok=false ou não for de hoje, diz no resumo.

1. Faturas pendentes: select guara_id, fornecedor, numero, data, dados from compras_guara_faturas where estado = 'pendente' order by data.
   - Se a fatura não for de produtos (serviços: desinfestação, manutenção, software, renda, contabilidade, etc.): select compras_guara_ignorar(guara_id, 'motivo curto').
   - Senão, para cada linha de dados->'linhas': se o artigo já é conhecido neste fornecedor (select * from compras__artigo_chave(compras__fornecedor('<fornecedor>'), '<desc>'), que também apanha a mesma descrição com outra pontuação, espaços, 0,70/0.70 ou "(B)" no fim), deixa a linha tal como está. Para as outras, acrescenta à linha:
     * "product_id": ANTES de pensar em produto novo, vê todas as descrições deste mesmo fornecedor (select o.alias, p.nome, o.product_id, o.pack_qty from compras_offers o join compras_products p on p.id = o.product_id where o.supplier_id = compras__fornecedor('<fornecedor>') union all select a.alias, p.nome, a.product_id, a.pack_qty from compras_offer_aliases a join compras_products p on p.id = a.product_id where a.supplier_id = compras__fornecedor('<fornecedor>')). O Guará escreve muitas vezes o mesmo artigo de outra maneira (ex.: "TEQ.J CUERVO SILVER" e "TEJ.CUERVO SILVER"; "MOSCATO PLATINO BLUE (6) 7%" sem o "0,75"; "GINGER ALE ... (24)" sem o "0,20"): se for o mesmo artigo e o mesmo tamanho, usa esse product_id e o mesmo pack_qty. Garrafas de tamanho diferente (0,70 e 1 L) são o mesmo produto mas com pack_qty diferente. Se não estiver neste fornecedor, procura um produto existente de compras_products (pelo nome, sinónimos e pelas ofertas de outros fornecedores: compras_offers.alias). Só se não houver nenhum, usa "novo_nome" (nome curto e genérico em português, como os existentes), "categoria" (uma das existentes: Bebidas, Carne, Descartáveis, Legumes e fruta, Limpeza e higiene, Mercearia, Outros, Peixe e marisco) e "base_unit" ("un", "kg" ou "L"). Nunca cries um segundo produto para um artigo que já existe (em 14/11 ficaram 7 repetidos assim e foi preciso juntá-los);
     * "pack_qty": quantas unidades de base_unit (a unidade do produto) vêm em cada embalagem da linha. Usa guara_embalagem como pista (ex.: "Água com gás — 6 L" num produto em L = 6; "Salmão — 1 kg" = 1; "C/2000" num produto em un = 2000); com unidade_fatura KG e produto ao kg, pack_qty = 1.
     * Linhas que não são produto (portes, taxas, ecovalor, serviços) ficam sem product_id e sem novo_nome (não entram).
     Não mudes "desc", "qty" nem "price". Importa com: select compras_guara_importar(guara_id, '<todas as linhas, em JSON>'::jsonb).
   - Regras confirmadas pelo dono: açúcar FRUSTOCK à caixa de 10 kg; açúcar Delta é "Açúcar em saquetas (café)", à caixa; Ebi Fry = 10 un; "Kimchi Sauce 1l" (molho, 1 L) e "Kimchi no Moto 1,2 kg" são produtos diferentes; tomate cherry ao kg; bolos da avó à unidade (só muda o sabor); Ama ebi é o produto "Ama ebi (camarão doce)".

1b. Artigos das faturas antigas (janeiro a agosto de 2026). O Guará não tem as linhas destas faturas; são lidas no documento com a IA, em segundo plano, para compras_guara_doc_fila. Pedido do dono: entra só o produto e o preço final (sem IVA e com desconto), sem faturas nem stock. Até 80 por dia, os mais vistos primeiro:
   select * from compras_antigas_por_ligar() order by vezes desc, ultima desc limit 80;
   (preco = preço final sem IVA e com desconto por cada unidade da fatura; unidade = a da fatura: CX, KG, UN, EM...)
   - Mesmo cuidado do passo 1: primeiro as descrições do mesmo fornecedor (compras__fornecedor('<fornecedor>'); se der null, o fornecedor ainda não está na app e é criado ao ligar), depois os produtos existentes e as ofertas de outros fornecedores; só então produto novo (nome curto e genérico, categoria e unidade como no passo 1). Nos documentos a FRUSTOCK aparece como "Bidfood Portugal": usa o nome do fornecedor da lista.
   - Ligar: select compras__antigas_ligar('<fornecedor>', '<descricao>', '<product_id>'::uuid ou null, '<nome novo>' ou null, '<un|kg|L>' ou null, '<categoria>' ou null, <pack_qty>);
     pack_qty como no passo 1 (quanto do produto vem em cada unidade da fatura; ex.: caixa de 6 garrafas de 1 L num produto em L = 6; artigo ao KG num produto ao kg = 1). Se o produto já tem preço mais recente nesse fornecedor, só fica a descrição; senão fica com este preço.
   - Não é produto (portes, taxas, ecovalor, serviços, equipamento): select compras__antigas_ignorar('<fornecedor>', '<descricao>', '<motivo curto>').
   - Na dúvida, não decidas (fica para o dia seguinte) e diz no resumo.
   - Para o resumo: select estado, count(*) from compras_guara_doc_fila group by 1; select pausa_ate, motivo from compras_guara_doc_estado; select count(*) from compras_antigas_por_ligar().

2. Ingredientes sem produto nas receitas que se vendem (as outras receitas do Guará, de outros menus, não interessam):
   with recursive arv(gid, depth) as (select distinct z.recipe_guara_id, 0 from compras_zs_items z where z.recipe_guara_id is not null and not z.ignorar union select i.sub_recipe_guara_id, a.depth + 1 from arv a join compras_recipes r on r.guara_id = a.gid join compras_recipe_items i on i.recipe_id = r.id where i.sub_recipe_guara_id is not null and a.depth < 8)
   select i.ingrediente, i.unidade, count(*) usos, string_agg(distinct r.nome, '; ') receitas from arv a join compras_recipes r on r.guara_id = a.gid join compras_recipe_items i on i.recipe_id = r.id where i.product_id is null and i.sub_recipe_guara_id is null and compras__norm(i.ingrediente) not in (select ingrediente from compras_ingredientes_sem_produto) group by 1, 2 order by 3 desc;
   - Se corresponde claramente a um produto que se compra (compras_products, mesma coisa e unidade compatível): select compras_ligar_ingrediente('<ingrediente>', '<product_id>').
   - Se não (feito cá, ainda não comprado, ou dúvida): insert into compras_ingredientes_sem_produto (ingrediente, nota) values (compras__norm('<ingrediente>'), '<razão curta>') on conflict (ingrediente) do nothing.
   - Não cries produtos novos para ingredientes.

3. Artigos vendidos no ZSbms sem receita nem produto:
   select z.codigo, z.descricao, (select sum(qtd) from compras_sales s where s.codigo = z.codigo and s.dia > current_date - 35) vendidos from compras_zs_items z where not z.ignorar and z.recipe_guara_id is null and z.product_id is null and not z.revisto.
   Para cada um, vê como estão os parecidos (select z.descricao, z.recipe_guara_id, r.nome, z.product_id, z.fator, z.ignorar from compras_zs_items z left join compras_recipes r on r.guara_id = z.recipe_guara_id where z.recipe_guara_id is not null or z.product_id is not null) e decide:
     * receita do Guará: recipe_guara_id = compras_recipes.guara_id, fator = receitas por cada venda (nas linhas "@" do all you can eat as doses são meias: fator 0.5, como "@1/2 Dose de maminha"; rolos do all you can eat = 0.5 do rolo, com pecas = 4; peças soltas de sushi com pecas = número de peças);
     * bebidas com receita no Guará ("Gin Tanqueray", "Crf reserva dose", "Limoncello dose", "Caipirinha"...): usa a receita, fator 1 (a meia dose tem receita própria);
     * produto vendido tal e qual (garrafas, latas, snacks): product_id, fator = quantidade do produto por venda na unidade do produto (garrafa/lata num produto em "un" = 1; garrafa de vinho de 0,75 L num produto em L = 0.75; dose de espirituosa sem receita num produto em L = 0.07, meia dose = 0.035);
     * ignorar = true para menus cujos componentes vêm em linhas próprias, taxas e linhas informativas;
     * "@Repetição N peças" = receita 'local-media-sushi' com fator N.
   Grava só as decisões claras: update compras_zs_items set recipe_guara_id = ..., product_id = ..., fator = ..., ignorar = ..., pecas = ... (só sushi do all you can eat), revisto = true, atualizado_em = now() where codigo = ...; as outras deixa como estão e põe no resumo.

4. Regista: select compras_guara_registo('correspondencia', '<JSON com: faturas_importadas, faturas_ignoradas, produtos_novos, ingredientes_ligados, ingredientes_sem_produto, artigos_zs_ligados, antigas_ligadas, antigas_ignoradas, por_decidir>'::jsonb).

5. Para o resumo, consulta também:
   a) stock baixo (até 10): select p.nome, round(s.stock,2) stock, p.unidade, round(s.consumo_dia,2) consumo_dia from compras__stock_rows() s join compras_products p on p.id = s.product_id where s.consumo_dia > 0 and s.stock < s.consumo_dia * 3 order by s.stock / nullif(s.consumo_dia, 0) limit 10;
   b) subidas de preço de 5% ou mais nos últimos 2 dias: compras_offers com prev_unit_price > 0, unit_price >= prev_unit_price * 1.05 e data >= current_date - 2, com os nomes de compras_products e compras_suppliers (até 10).

6. Relatório da manhã (é o que o dono recebe no telemóvel; escreve-o sempre, mesmo que não haja nada para fazer). Curto, em lista, com este formato:
   Relatório da manhã — dd/mm
   • Importações das 10h: vendas do ZSbms até dd/mm, faturas e receitas do Guará (ok, ou o erro).
   • Faturas novas importadas: fornecedor, nº e artigos novos com o produto e a embalagem escolhidos (ou "nenhuma").
   • Produtos novos criados.
   • Faturas antigas: lidas X de 872 (Y nas últimas 24 h: select count(*) from compras_guara_doc_fila where lida_em > now() - interval '24 hours'); artigos ligados hoje, ignorados, e quantos faltam.
   • Ingredientes ligados e artigos do ZSbms ligados.
   • Stock a acabar e subidas de preço (passo 5), só se houver.
   • Por decidir: cada coisa com a razão, para o dono rever.
```
