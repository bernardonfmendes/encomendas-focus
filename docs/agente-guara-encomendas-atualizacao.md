# Atualização ao texto das encomendas: os produtos já estão ligados às receitas

Isto junta-se ao texto "integrar as encomendas" que já recebeste. Vem com o ficheiro **`Encomendas - atualização (produtos, receitas e vendas).xlsx`**, que tem só as 3 folhas novas.

## Os produtos já estão ligados às receitas

- **No Guará, cada ingrediente de uma receita é um Produto do Guará** (ou uma sub-receita), ligado pelo número do produto.
  - Os produtos a encomendar são esses mesmos produtos. Não crias produtos novos para as encomendas.
  - Hoje há 645 receitas no Guará, com 3 506 ingredientes, dos quais 1 135 são sub-receitas.
- **Nas receitas, os nomes são genéricos.** Por exemplo, "Refrigerante de cola" é a Pepsi e "Vinho branco da casa" é o Herdade da Candeeira branco.
  - A folha **"Produtos e receitas"** liga 160 produtos da app ao nome que têm nas receitas do Guará.
  - Usa-a para saber que produto do Guará corresponde a cada produto do primeiro Excel.
- **Alguns produtos das receitas nunca vieram numa fatura lida.** Exemplos: sésamo branco, canela, cebola frita e sal grosso.
  - Na app não têm produto nem preço. Estão na folha **"Ingredientes sem produto"**, com as notas do dono.
  - Também se encomendam: pergunta ao dono a que fornecedor.
- **As vendas ligam-se às receitas pelos artigos do POS (ZSbms).** São 314 artigos, na folha **"Artigos do POS"**:
  - 235 ligados a uma receita, com um fator (ex.: "COMBINADO 48" = 1,5 × "Combinado 32 peças");
  - 50 ligados a um produto vendido tal e qual (garrafas, latas, snacks);
  - 29 ignorados: menus cujos componentes vêm em linhas próprias.
- **Três receitas só existem na app:** a peça média de sushi do all you can eat, o galão e a meia de leite.
- **Se o Guará já fizer a ligação das vendas às receitas** (por exemplo nos "Itens de ementa"), compara com esta folha e mostra ao dono as diferenças.
- **Assim, o mesmo produto liga tudo:** encomenda → fatura → stock → receitas → vendas.

## O que muda no texto anterior

Em **"Ganhos por estar dentro do Guará"**, no ponto **"Stock na encomenda"**:
- Os produtos, as receitas e as vendas já estão ligados.
- Falta o stock no Guará: última contagem + compras − vendas × receitas.
- É isto que permite sugerir quantidades na encomenda. Fica para uma segunda fase, se o dono quiser.

## As 3 folhas do Excel

- **"Produtos e receitas":** 186 linhas. Cada uma é um produto da app, o nome desse produto nas receitas do Guará, em quantas receitas entra e quantas dessas se venderam nos últimos 30 dias.
- **"Ingredientes sem produto":** 259 ingredientes das receitas sem produto na app, com a nota do dono quando existe. Os que entram em pratos vendidos estão primeiro.
- **"Artigos do POS":** os 314 artigos do ZSbms. Cada um tem o código, a receita do Guará (número e nome) ou o produto, o fator, as peças, se é ignorado e quantos se venderam nos últimos 30 dias.
