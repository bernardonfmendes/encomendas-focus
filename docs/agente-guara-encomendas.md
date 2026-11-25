# Para o agente do Guará: integrar as encomendas do Focus Sushi & Steak

**O pedido do dono:** que a equipa passe a fazer as encomendas aos fornecedores **dentro do Guará**, como hoje faz na app "Compras", sem perder nenhuma das regras.

Vai com este texto o ficheiro **`Encomendas - dados para o Guará.xlsx`**, tal como estão hoje na app. Tem os fornecedores, os produtos de cada fornecedor, as formas de encomenda, a ligação dos produtos às receitas do Guará e a ligação dos artigos do POS às receitas.

---

## 1. O que o Guará já tem e o que falta

**Já existe no Guará** (visto a 24/11/2026):
- **Fornecedores:** por categorias (CMV, RH, Despesas), com NIF.
- **Produtos / Embalagens:** cada produto com preço por unidade e data.
- **Faturas:** cada linha liga a um produto e a uma embalagem ("Embalagens").
- **Receitas** e **Itens de ementa**.
- **Vendas por SAF-T.**
- **Equipa** e **Funções**.

**Falta:** um módulo de **Encomendas**, e no fornecedor os dados para encomendar (WhatsApp, mínimo, dias).

**Antes de construir:** diz ao dono, curto, como propões fazer e onde fica no Guará. Pergunta antes de avançar com algo grande. A app atual continua a funcionar até ele dizer para a desligar.

---

## 2. Onde liga aos dados do Guará

Usa o que o Guará já tem; não cries um catálogo à parte.

| Na encomenda | No Guará |
|---|---|
| Produto a encomendar | **Produtos / Embalagens** |
| Fornecedor | **Fornecedores** |
| Que produtos cada fornecedor vende, em que embalagem e a que preço | as **linhas das faturas** já ligadas a produto e embalagem; o último preço por unidade, **sem IVA e com desconto** |
| Quem pode fazer o quê | **Equipa** e **Funções** |

**A acrescentar no fornecedor:**
- WhatsApp: número, ou "grupo de WhatsApp" quando a encomenda vai para um grupo (é o caso da Sumol Compal);
- mínimo de entrega (€ sem IVA);
- dias de encomenda e de entrega (texto livre);
- entregas por semana;
- **texto extra**, que vai em todas as mensagens a esse fornecedor (a Keta Foods leva "Nif: 515750115"). Não uses o NIF do fornecedor para isto: o NIF serve para reconhecer as faturas.

**A acrescentar em cada produto × fornecedor:**
- **Nome na encomenda:** o nome que o fornecedor entende. Quando existe, a mensagem leva só esse nome, sem embalagem nem referência.
- **Referência**, quando houver.
- **Formas de encomenda:** lista ordenada, em que a 1.ª é a de defeito. Exemplos: banana em kg ou em un; abacate em un. As formas que existem hoje são un, caixa, molho, cuvete, saco, pacote, manga, gramas, embalagem, pack, rolo e fardo. O dono pode criar mais.

**A acrescentar em cada produto:**
- **Sítios** onde aparece: Cozinha, Sushi, Bar e Take away. Um produto sem sítios aparece em todos.
- Cada pessoa tem o seu sítio por defeito.

---

## 3. Os produtos já estão ligados às receitas

- **No Guará, cada ingrediente de uma receita é um Produto do Guará** (ou uma sub-receita), ligado pelo número do produto.
  - Os produtos a encomendar são esses mesmos produtos. Não crias produtos novos para as encomendas.
  - Hoje há 645 receitas no Guará, com 3 506 ingredientes, dos quais 1 135 são sub-receitas.
- **Nas receitas, os nomes são genéricos.** Por exemplo, "Refrigerante de cola" é a Pepsi e "Vinho branco da casa" é o Herdade da Candeeira branco.
  - A folha **"Produtos e receitas"** do Excel liga 160 produtos da app ao nome que têm nas receitas do Guará.
  - Usa-a para saber que produto do Guará corresponde a cada produto do Excel.
- **Alguns produtos das receitas nunca vieram numa fatura lida.** Exemplos: sésamo branco, canela, cebola frita e sal grosso.
  - Na app não têm produto nem preço. Estão na folha **"Ingredientes sem produto"**, com as notas do dono.
  - Também se encomendam: pergunta ao dono a que fornecedor.
- **As vendas ligam-se às receitas pelos artigos do POS (ZSbms).** São 314 artigos, na folha **"Artigos do POS"**:
  - 235 ligados a uma receita, com um fator (ex.: "COMBINADO 48" = 1,5 × "Combinado 32 peças");
  - 50 ligados a um produto vendido tal e qual (garrafas, latas, snacks);
  - 29 ignorados: menus cujos componentes vêm em linhas próprias.
- **Três receitas só existem na app:** a peça média de sushi do all you can eat, o galão e a meia de leite.
- **Se o Guará já fizer a ligação das vendas às receitas** (por exemplo nos "Itens de ementa"), compara com esta folha e mostra ao dono as diferenças.
- **Assim, o mesmo produto liga tudo:** encomenda → fatura → stock → receitas → vendas. É isto que permite, numa segunda fase, sugerir quantidades na encomenda (ver secção 8).

---

## 4. Quem faz o quê

| Perfil | Pode |
|---|---|
| **Colaborador** | Escolher produtos, enviar ao chefe, ver só os seus pedidos e cancelar um pedido seu que ainda esteja por confirmar. Não vê os telefones dos fornecedores. |
| **Chefe** | Confirmar, mudar quantidades, rejeitar (com motivo) e enviar. As encomendas que ele faz ficam logo aprovadas. Edita produtos, fornecedores, nomes na encomenda e formas. |
| **Dono** | Tudo o que o chefe pode. |

---

## 5. Como funciona (igual à app de hoje)

**Encomendar** (no telemóvel):
- **Topo:**
  - escolha do sítio (lembra-se da última escolha);
  - procura por nome, descrição da fatura ou fornecedor, sem acentos e tolerante a gralhas;
  - filtro por fornecedor;
  - filtro por categoria.
- **"Mais pedidos"** do sítio: até 5 produtos pedidos em 2 ou mais encomendas.
- **Cada produto mostra:**
  - o preço do fornecedor mais barato por unidade (ex.: "83,00 € emb. 20 kg · Kiku · 4,15 €/kg");
  - a variação face à fatura anterior, quando é de 3% ou mais;
  - "mín. 150 €" se o fornecedor tiver mínimo;
  - os outros fornecedores, com o preço de cada um.
- **Botão "+"** que passa a − / quantidade / +:
  - passo de 1 para embalagens e unidades, 0,5 para kg ou L a granel;
  - aceita escrever a quantidade;
  - ao lado, a escolha da forma quando o produto tem formas.

**Carrinho** (fica guardado no telemóvel):
- **Organização:**
  - agrupado por fornecedor, com o total de cada um;
  - cada linha é produto + fornecedor + sítio.
- **Mínimo de entrega:**
  - barra de progresso que conta também o que já está pedido e em aberto a esse fornecedor;
  - mostra "faltam 30,00 €" ou "✓ mínimo atingido".
- **Extras:**
  - nota para o fornecedor;
  - "Esvaziar carrinho" com "Desfazer".
- **Enviar:**
  - o botão diz **"Enviar ao chefe"** (colaborador) ou **"Criar encomendas"** (chefe);
  - cria **uma encomenda por fornecedor**;
  - se já houver uma em aberto desse fornecedor, os produtos **juntam-se a ela**.

**Pedidos:**
- **Estados:** por confirmar → aprovada → enviada, ou rejeitada (com o motivo, que o colaborador vê).
- **O chefe vê:**
  - três caixas no topo: por confirmar, por enviar, enviadas hoje;
  - o valor em aberto.
- **Encomenda por confirmar:**
  - mudar quantidades (0 retira o produto);
  - pôr data de entrega;
  - **"Confirmar e enviar"**, "Só confirmar" ou "Rejeitar".
- **Encomenda aprovada:**
  - **WhatsApp** abre a conversa com a mensagem já escrita (ou "Partilhar no grupo");
  - "Copiar";
  - "Já enviei · marcar como enviada".
- **Também:** "Repetir esta encomenda" (põe as mesmas linhas no carrinho) e, para o chefe, apagar.

**Notificações:**
- Quando um colaborador envia, os chefes recebem "Nova encomenda por confirmar", no máximo uma a cada 30 s.
- Quando o chefe confirma ou rejeita, quem pediu recebe o aviso.

---

## 6. Mensagem ao fornecedor

As quantidades de vários sítios somam-se por produto. Exemplo:

```
Boa tarde! Encomenda do Focus Sushi & Steak:
- 2 × Shoyu Yamasa 18l [18 L] (ref. 123)
- 1,5 kg SALMAO 5/6
- 10 un Abacate
- 3 × Coca-Cola lata

Nif: 515750115
Entrega: sexta-feira, 20 de novembro
Nota: entregar antes das 11h

Obrigado.
```
- **Saudação:** Bom dia (5h–12h), Boa tarde (12h–19h), Boa noite.
- **A granel:** "1,5 kg Descrição".
- **Embalagem:** "2 × Descrição [tamanho]" e "(ref. X)" se houver referência.
- **Com nome na encomenda:** só o nome ("3 × Coca-Cola lata").
- **Forma escolhida:** "10 un Abacate".
- **Ordem das linhas finais:** texto extra do fornecedor, depois "Entrega:" (se houver data), depois "Nota:" (se houver).

---

## 7. Regras que não se podem perder

1. **Preços sempre sem IVA** e por unidade: preço da embalagem ÷ quantidade da embalagem.
2. **Uma forma diferente da original** só muda a encomenda: a linha vai **sem preço**, não se junta a linhas de outra forma e não mexe em faturas, preços nem stock. Não se usa peso aproximado.
3. **Mínimo de entrega** conta o que já está em aberto a esse fornecedor.
4. **Uma encomenda por fornecedor;** se já há uma em aberto, junta-se a ela.
5. **Nada vai para o fornecedor sem o chefe:** as encomendas do colaborador ficam por confirmar.
6. Cada linha guarda o que se viu no momento: nome, descrição, referência, embalagem, preço, unidade, sítio e forma. Se o preço mudar depois, a encomenda antiga não muda.
7. **Fornecedores especiais:**
   - **"Bernardo Mendes"** = Continente + Makro: é o dono que vai comprar, por isso não há envio por WhatsApp. Fica só como lista de compras.
   - **Sumol Compal:** encomenda por grupo de WhatsApp.
   - **Keta Foods:** "Nif: 515750115" em todas as mensagens.
8. **O vasilhame e os depósitos** (grades, barris) também se encomendam.

---

## 8. Ganhos por estar dentro do Guará (propõe ao dono)

- **Conferir a encomenda com a fatura:** quando a fatura do fornecedor entra, comparar com o que foi enviado (faltou, veio a mais, preço diferente do previsto) e avisar o chefe.
- **Preço sempre atualizado** a partir das faturas, sem passo intermédio.
- **Stock na encomenda:** a app atual mostra, em cada produto, "Stock 3,2 kg · gasta ~8 kg/semana · para 7 dias faltam ~4,8 kg" e avisa quando não chega até à próxima entrega. Os produtos, as receitas e as vendas já estão ligados (secção 3). Falta o stock no Guará: última contagem + compras − vendas × receitas. Fica para uma segunda fase, se o dono quiser.

---

## 9. Como usar o Excel

- **Folha "Fornecedores":** 35 fornecedores, com NIF, WhatsApp, por número ou grupo, mínimo, dias, entregas por semana, texto extra e outros nomes nas faturas. A maioria ainda não tem WhatsApp nem mínimo: pede ao dono.
- **Folha "Produtos e fornecedores":** 382 linhas (319 produtos). Para cada produto e fornecedor tem:
  - categoria, unidade e sítios;
  - **descrição da fatura**, que serve para ligar ao produto/embalagem do Guará pelas linhas das faturas;
  - referência e embalagem;
  - preço da embalagem e por unidade, com a data;
  - nome na encomenda e formas de encomenda ("(como está)" = a forma original);
  - outras descrições com que o artigo já apareceu nas faturas.
- **Folha "Formas de encomenda":** as 12 formas criadas.
- **Folha "Produtos e receitas":** 186 linhas. Cada uma é um produto da app, o nome desse produto nas receitas do Guará, em quantas receitas entra e quantas dessas se venderam nos últimos 30 dias.
- **Folha "Ingredientes sem produto":** 259 ingredientes das receitas sem produto na app, com a nota do dono quando existe. Os que entram em pratos vendidos estão primeiro.
- **Folha "Artigos do POS":** os 314 artigos do ZSbms. Cada um tem o código, a receita do Guará (número e nome) ou o produto, o fator, as peças, se é ignorado e quantos se venderam nos últimos 30 dias.
- Os nomes dos produtos foram escolhidos pelo dono. Quando forem diferentes dos do Guará, mostra-lhe os dois e pergunta qual fica.

---

## 10. Antes de pôr a equipa a usar (testes)

Testa no telemóvel, com dados reais:
1. Um colaborador do Sushi encomenda 2 produtos de 2 fornecedores: ficam 2 encomendas por confirmar, e o chefe recebe a notificação.
2. O chefe confirma e envia: o WhatsApp abre com a mensagem certa (saudação, linhas, texto extra da Keta, entrega, nota).
3. Um produto com formas (banana em kg ou un): pedido em un, sai "10 un Banana" sem preço.
4. Um produto com nome na encomenda: sai só esse nome.
5. Um segundo pedido ao mesmo fornecedor, ainda em aberto, junta-se à encomenda existente.
6. Mínimo de 100 € na Garcias: a barra conta o que já está pedido.
7. Sumol Compal: abre a partilha para o grupo, e não um número.
8. Rejeitar com motivo: o colaborador vê o motivo.
9. Repetir uma encomenda: as linhas voltam ao carrinho.

Quando estiver tudo certo, diz ao dono, para ele decidir quando a equipa muda e quando se desliga a encomenda na app antiga.
