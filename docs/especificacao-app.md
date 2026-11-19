# Compras Focus: especificação completa da app

Documento para um agente (ou programador) que precise de perceber, manter ou refazer a app de compras do restaurante **Focus Sushi & Steak** com o **mesmo visual, as mesmas funções e a mesma forma de usar**. Descreve a app tal como está a 18/11/2026.

> Não há aqui PINs, chaves nem palavras-passe. As credenciais do Guará e do ZSbms vivem só como segredos no servidor (funções do Supabase) e nunca devem ir para o código, para o repositório nem para o navegador.

---

## 1. A ideia

A equipa da cozinha, do sushi, do bar e do take away faz as encomendas aos fornecedores pelo telemóvel. O chefe confirma e envia ao fornecedor por WhatsApp numa mensagem já escrita. As faturas entram sozinhas (lidas do Guará) e mantêm os preços certos. As vendas entram sozinhas (lidas do ZSbms) e, com as receitas do Guará, a app calcula o stock e o CMV. O dono tem um back office para corrigir nomes, ver subidas e descidas de preço e acompanhar o CMV.

Objetivos que guiam todas as decisões:

- **Encomendar depressa e sem erros:** procurar, tocar em "+", enviar. O colaborador não precisa de saber preços nem fornecedores de cor.
- **O chefe controla o que sai:** nada vai para o fornecedor sem confirmação do chefe.
- **Preços reais:** o preço de cada produto vem das faturas, por unidade (€/kg, €/L, €/un), sem IVA e com os descontos que o restaurante tem de facto.
- **Saber quanto há e quanto se gasta:** stock = compras − consumo das vendas, acertado com uma contagem mensal.
- **Saber se os pratos dão dinheiro:** CMV por prato e global.
- **Sem PC ligado:** as leituras do Guará e do ZSbms correm no servidor, a horas certas.

Língua: **português de Portugal**, frases curtas e diretas, tratamento por "você" implícito (ex.: "Entre com o seu nome", "Escolha produtos"). Moeda em euros com formato pt-PT (`1 234,56 €`), datas `dd/mm/aa`.

---

## 2. Quem usa e o que pode fazer

| Perfil | O que vê e faz |
|---|---|
| **Colaborador** | Encomendar, Carrinho, Pedidos (só os seus; não vê os telefones dos fornecedores), Stock (ver e contar). Os pedidos ficam "por confirmar" até o chefe decidir. Pode cancelar um pedido seu ainda por confirmar. Muda o próprio PIN. |
| **Chefe** | Tudo o do colaborador, mais: confirmar, editar, rejeitar e enviar encomendas; as suas encomendas ficam logo aprovadas; separadores **Faturas** e **Gestão**; editar produtos e preços; fechar a contagem de stock. |
| **Dono** | É um chefe marcado nas definições (`dono_id`). Vê uma **casa** na barra de cima que leva ao **back office** (`/backoffice`). Só ele entra no back office. |

Entrada: **nome + PIN de 6 números** (dado pelo chefe). Cada pessoa tem um **sítio** por defeito: Cozinha, Sushi, Bar ou Take away.

---

## 3. Visual

### 3.1 Princípios

- **Telemóvel primeiro** (a maioria usa no iPhone/Android, instalada como app). Largura máxima do conteúdo 860 px; margem lateral 16 px (respeita a zona segura do iPhone).
- **Sem zoom** (viewport fixo, `touch-action: manipulation`, campos com 16 px para o iPhone não ampliar).
- Botões e alvos de toque com **pelo menos 40–42 px** de altura.
- **Modo claro e escuro** automáticos (segue o telemóvel).
- Visual calmo: fundo creme, cartões brancos com borda fina, um laranja-tijolo como cor de ação e um verde-nori como segunda cor.
- Números com algarismos tabulares (alinham em colunas).

### 3.2 Cores (tokens)

| Token | Claro | Escuro | Uso |
|---|---|---|---|
| `--bg` | `#F5F3F0` | `#101513` | fundo da página |
| `--surface` | `#FFFFFF` | `#19201E` | cartões, barras |
| `--surface-2` | `#FAF8F6` | `#151B19` | cabeçalhos de tabela, caixas da mensagem |
| `--ink` | `#17201E` | `#ECEFED` | texto |
| `--muted` | `#5D6865` | `#9BA7A3` | texto secundário |
| `--line` | `#E3DFDA` | `#2B3532` | bordas e divisórias |
| `--accent` | `#BE4A2F` | `#F08B6D` | ação principal, separador ativo |
| `--on-accent` | `#FFFFFF` | `#1C0F0A` | texto sobre o accent |
| `--nori` | `#1F3B34` | `#A3CDBF` | segunda cor (chips ativos, cor da app, `theme-color`) |
| `--nori-soft` | `#E3EDE9` | `#1E2E29` | fundos suaves (produto no carrinho, etiquetas de sítio) |
| `--good` / `--good-soft` | `#2E7A4E` / `#E2F2E8` | `#6CC690` / `#18301F` | descidas de preço, ok, enviada |
| `--warn` / `--warn-soft` | `#9A6200` / `#FBF0D9` | `#E5B24E` / `#33280F` | avisos, por confirmar, stock a acabar |
| `--bad` / `--bad-soft` | `#B3261E` / `#FBE4E2` | `#F2877E` / `#3A1C1A` | subidas de preço, rejeitada, stock negativo |

Raio dos cartões `12px` (`--r`); botões `10px`; chips em pílula (`999px`).

### 3.3 Letra

- Títulos: **Bricolage Grotesque** 600/700 (Google Fonts).
- Texto: **Figtree** 400/500/600/700.
- Base 15 px, linha 1,45. Títulos de ecrã ~20 px; nome do restaurante na barra 18 px.

### 3.4 Componentes

- **Barra de cima** fixa (fundo `surface`, borda em baixo): nome do restaurante à esquerda; à direita o nome da pessoa, a **casa** (só o dono), o **sino** das notificações (fica cor accent quando ativas), "PIN" e "Sair" como links.
- **Barra de baixo** fixa com 4–6 separadores com ícone por cima do texto (11 px): Encomendar (lupa), Carrinho (carrinho), Pedidos (prancheta com visto), Stock (caixa), Faturas (talão) e Gestão (controlos), estes dois só para o chefe. O ativo fica cor accent. Contadores em pílula accent: artigos no carrinho, pedidos em aberto ou por confirmar, faturas lidas por rever.
- **Seletor de sítio** (segmentado, 4 colunas): Cozinha · Sushi · Bar · Take away; o ativo com fundo accent; um pequeno contador verde-nori mostra quantos artigos há no carrinho para cada sítio.
- **Chips de categoria** numa fila com deslize horizontal; o ativo com fundo nori.
- **Lista de produtos** num cartão contínuo com divisórias; cada linha tem um ícone da categoria num quadrado `nori-soft` de 40 px.
- **Stepper** de quantidade: `−` · campo editável · unidade (ou seletor da forma) · `+`, com uma pequena animação "pop" quando se adiciona.
- **Botão "+"** redondo de 40 px para pôr no carrinho.
- **Cartões de grupo** (carrinho e pedidos): cabeçalho com fornecedor e total, lista de linhas e rodapé com total, mínimo de entrega e botões.
- **Barra de progresso** do mínimo de entrega (amarela até chegar ao mínimo, verde quando chega).
- **Etiquetas de estado**: Por confirmar (amarelo), Aprovada (nori), Enviada (verde), Rejeitada (vermelho).
- **Etiquetas de preço**: `↑12%` em vermelho suave e `↓5%` em verde suave.
- **Folha de baixo** (bottom sheet) para escolher o fornecedor.
- **Toast** escuro em baixo, ao centro, com 4 s (6 s com "Desfazer").
- **Confirmação em dois toques** nas ações perigosas: o botão passa a dizer "Confirmar: apagar…" e só o segundo toque apaga.
- **Estados vazios** num cartão com título e uma frase do que fazer a seguir.
- **Faixa sem rede**: "Sem ligação à internet. A mostrar os últimos dados guardados."

Ícones das categorias: Peixe e marisco 🐟 · Carne 🥩 · Legumes e fruta 🥬 · Mercearia 🥫 · Bebidas 🥤 · Limpeza e higiene 🧽 · Descartáveis 📦 · Outros 🛒.

---

## 4. A app da equipa (`/`)

App de página única, instalável (PWA) com o nome "Compras". Navegação por âncoras: `#encomendar`, `#carrinho`, `#pedidos`, `#stock`, `#faturas`, `#gestao`.

### 4.1 Entrar

Ecrã simples ao centro: título "Compras", a frase "Entre com o seu nome e o PIN de 6 números que o chefe lhe deu.", os campos Nome e PIN (teclado numérico, pontos grandes e espaçados) e o botão "Entrar".

- O nome não distingue maiúsculas. Nome ou PIN errados dão "Nome ou PIN errados."
- **5 tentativas erradas bloqueiam 15 minutos** ("Demasiadas tentativas. Espere 15 minutos ou peça ao chefe para repor o PIN.").
- A sessão dura **60 dias** no aparelho. Se expirar, volta ao login com "A sessão terminou. Entre outra vez."
- "PIN" na barra abre o ecrã **Mudar PIN** (atual + novo, 6 números).

### 4.2 Encomendar

Topo fixo com:
1. O **seletor de sítio**: para onde é a encomenda. Lembra-se da última escolha.
2. A **procura** ("Procurar produto"), com sugestões das procuras recentes.
3. O botão **Fornecedores**, que abre uma folha com "Todos os fornecedores" e a lista com o nº de produtos de cada um. Com um escolhido, o botão fica accent e mostra o nome curto.

Depois:
- **Chips de categoria** ("Todas" + as que existem).
- **"Mais pedidos"**: até 5 produtos pedidos em 2 ou mais encomendas (não rejeitadas) do sítio. Só aparece sem procura e sem categoria.
- **"Todos os produtos"** do sítio. Um produto sem sítios marcados aparece em todos. Ao encomendar um produto para um sítio novo, esse sítio passa a ficar marcado no produto.
- Fundo: "Não encontra? Ver todos os produtos (N)" (mostra os de todos os sítios, com a etiqueta "outro sítio"). O chefe tem também "+ Novo produto".

**Procura:** procura em nome, categoria, descrições das faturas e nome do fornecedor, sem acentos e com todas as palavras. Se não houver nada, tenta "parecidos" (1 letra trocada em palavras de 4–5 letras, 2 em 6 ou mais) e avisa "Resultados parecidos com …".

**Cada produto** mostra:
- Ícone, **nome**, ✎ para o chefe editar.
- **Stock** (se houver dados): "Stock 3,2 kg · gasta ~8 kg/semana · para 7 dias faltam ~4,8 kg"; "acabou" a vermelho quando ≤ 0; amarelo quando dá para menos de 3 dias.
- **Preço do fornecedor mais barato** (por unidade): embalagem → "**83,00 €** emb. 20 kg · Kiku · 4,15 €/kg"; a granel → "**8,30 €/kg** · Conquista Salgada". Depois a etiqueta de variação (↑/↓ quando mudou 3% ou mais face à fatura anterior), "mín. 150 €" se o fornecedor tem mínimo e "pede-se em **kg ou un**" se o dono definiu formas de encomenda.
- Botão **+** (ou o stepper, se já está no carrinho; a linha fica com fundo `nori-soft`).
- "Mais 2 fornecedores (desde 7,90 €/kg)", que abre os outros fornecedores, cada um com o seu preço e o seu "+".

**Quantidades:** passo de 1 (embalagens ou unidades) ou 0,5 (kg ou L a granel); o campo também aceita escrever. Quando o dono definiu **formas de encomenda** para esse produto nesse fornecedor (ex.: banana em kg ou un; abacate em un), aparece um seletor no stepper. Uma forma diferente da original só muda a encomenda: a linha fica **sem preço** ("em un · sem preço") e as faturas, preços e stock continuam na unidade do produto.

**Editar produto (chefe):** nome, categoria, unidade (un, kg, L), em que sítios aparece, e por fornecedor: nome no fornecedor, referência, quantidade por embalagem e preço da embalagem sem IVA ("Agora: 4,15 € / kg · desde 03/11/26"); também acrescentar ou retirar fornecedores e apagar o produto.

### 4.3 Carrinho

- Guardado no aparelho (sobrevive a fechar a app). Cada linha é produto + fornecedor + sítio.
- **Agrupado por fornecedor**, com o total de cada grupo. Cada linha mostra o nome (com a etiqueta do sítio quando o carrinho tem vários sítios), a embalagem e o preço, o stepper e o total da linha ("—" se for numa forma sem preço).
- **Mínimo de entrega** por fornecedor, com barra de progresso. Conta também o que já está pedido e em aberto a esse fornecedor ("+ 120,00 € já pedidos a este fornecedor"; "Mínimo de entrega 150,00 € · faltam 30,00 €" ou "✓ Mínimo de entrega atingido").
- "+ Nota para o fornecedor" (ex.: "entregar antes das 11h"), "Esvaziar carrinho" (com "Desfazer") e "Valores sem IVA".
- Barra fixa em baixo com o total e o botão: **"Enviar ao chefe"** (colaborador) ou **"Criar encomendas"** (chefe).
- Ao enviar, cria **uma encomenda por fornecedor**. Se já existir uma encomenda em aberto desse fornecedor, os produtos **juntam-se a ela** ("Produtos juntados à encomenda aberta do fornecedor"). As do chefe ficam logo aprovadas. O colaborador gera uma notificação para os chefes.

### 4.4 Pedidos

O colaborador vê só os seus pedidos ("Os meus pedidos"); o chefe vê todos (até aos últimos 200). Resumo para o chefe: três caixas (**Por confirmar**, **Por enviar**, **Enviadas hoje**) e o valor em aberto sem IVA. Secções: Por confirmar (para o colaborador, "À espera do chefe") · Aprovadas, por enviar · Enviadas (fechada, últimas 40) · Rejeitadas.

**Cada encomenda** é um cartão que abre e fecha. O cabeçalho mostra o fornecedor, os sítios, "Pedido por Ana · 17/11 18:42", "aprovado por …" e o motivo, se foi rejeitada. Aberto:
- As linhas com quantidade e total. O chefe pode mudar quantidades nas por confirmar e nas aprovadas; quantidade 0 retira o produto. Nas aprovadas é preciso "Guardar alterações" (ou "Desfazer").
- Total sem IVA, barra do mínimo e a nota.
- **Por confirmar (chefe):** "+ Data de entrega"; **"Confirmar e enviar"** (botão principal); "Só confirmar"; "Rejeitar" (pede o motivo, com pelo menos 3 letras, que o colaborador vê).
- **Aprovada (chefe):** "Ver mensagem" e:
  - fornecedor por **número**: botão **WhatsApp**, que abre a conversa com a mensagem já escrita, e "Copiar";
  - fornecedor por **grupo**: "Partilhar no grupo" (partilha do telemóvel) e "Copiar";
  - sem número: campo para guardar o número e "Copiar mensagem";
  - depois: **"Já enviei · marcar como enviada"**.
- **Colaborador:** "Cancelar pedido" num pedido seu por confirmar.
- **Todos:** "↻ Repetir esta encomenda" (põe as mesmas linhas no carrinho). O chefe também pode "Apagar encomenda".

**Mensagem ao fornecedor** (soma os sítios por produto):
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
- Saudação conforme a hora: Bom dia (5h–12h), Boa tarde (12h–19h), Boa noite.
- Granel: "1,5 kg Descrição". Embalagem: "2 × Descrição [18 L]" e "(ref. X)" se houver referência.
- Se o dono definiu um **nome na encomenda** para esse fornecedor, vai só esse nome, sem embalagem nem referência.
- Pedido numa forma escolhida: "10 un Abacate".
- **Texto extra do fornecedor** (Gestão › Fornecedores), em todas as mensagens a esse fornecedor, antes da entrega e da nota. Ex.: a Keta Foods recebe "Nif: 515750115".

**Notificações:** quando um colaborador envia, os chefes recebem "Nova encomenda por confirmar · Ana fez um pedido · 3 por confirmar" (no máximo um aviso a cada 30 s). Quando o chefe confirma ou rejeita, o autor recebe o aviso. O número de pedidos por confirmar aparece no ícone da app (chefe). A lista atualiza a cada 30 s e o catálogo a cada 5 min, enquanto a app está aberta.

### 4.5 Stock

- Frase do topo: "Faturas que entraram menos o que se gastou nas vendas (receitas do Guará). Vendas até 17/11/26."
- **Stock = última contagem (ou 0 na data de início) + compras das faturas − consumo** (vendas do ZSbms × ingredientes das receitas). Consumo por dia = média das últimas 4 semanas com vendas.
- Um produto contado conta a partir do momento da contagem: as vendas desse dia entram se foi contado antes das 17h, as faturas desse dia se foi contado antes das 10h.
- **Ritmo:** quanto entra por semana (faturas das últimas 4 semanas) e quantas vezes por semana entrega o fornecedor da última compra ("Entregas por semana" em Gestão › Fornecedores; vazio = estimado pelas faturas).
- Procura e filtros: **Todos** (por categoria), **A acabar** (o stock não chega até à próxima entrega + 1 dia, ou acabou) e **Sem vendas**.
- Cada linha mostra nome, "gasta ~1,2 L/dia · entra ~6 L/semana · vem ~1×/semana · contado 18/11/26", a quantidade (vermelho se negativa, amarelo se a acabar) e, para bebidas, o equivalente em garrafas/barris ("≈ 3,5 garrafas").
- O chefe vê também "N artigos vendidos no ZSbms ainda não têm receita, por isso não descontam stock."

**Contagem (mensal):**
- Qualquer pessoa pode **"Começar contagem"** e contar. Conta-se **por sítio** (Cozinha, Sushi, Bar, Take away e **Armazém**; o Armazém mostra todos os produtos), produto a produto, por categoria, e grava sozinho; o vazio quer dizer "não contado".
- Cada produto conta-se na sua **forma de contar**: bebidas em garrafas, barris, latas ou embalagens com o volume do nome ou da embalagem ("em garrafas de 0,7 L", "em barris de 50 L"), o resto na unidade do produto (kg, un). Aceita decimais (garrafa aberta a meio = 1,5) e mostra o total ("= 1,05 L").
- Recomendação: contar tudo de uma vez, incluindo o armazém, de manhã antes de abrir ou à noite depois de fechar.
- O chefe pode corrigir o nome de um produto durante a contagem (✎).
- O chefe **fecha a contagem**: o stock de cada produto contado passa a ser a soma contada nos sítios, e os não contados ficam com o valor calculado. O chefe também pode apagar a contagem.
- Depois aparece "Última contagem: 01/11/26 · Ver diferenças", com o contado menos o esperado (negativo = faltou: quebras, porções maiores, vendas sem receita).

### 4.6 Faturas (chefe)

Três abas (segmentado): **Preços** · **Ler faturas (N)** · **Histórico**.

- **Preços:**
  - Duas caixas clicáveis: "▲ N preços subiram" e "▼ N preços desceram" (variações de 3% ou mais face à fatura anterior do mesmo fornecedor).
  - Lista de produtos com "4,02 € (06/10) → **4,15 €** (27/10) / kg" e a variação em destaque.
  - "**Onde é mais barato**": produtos comprados a mais de um fornecedor, comparados por €/kg, €/L ou €/un ("✓ Kiku · mais barato", "Makro · +12%").
- **Ler faturas:** fotografias (até 5 páginas) ou PDF (até 8 MB). As fotos são melhoradas no telemóvel antes de enviar: máximo 1600 px, cinzento, contraste esticado, JPEG.
  - A leitura corre **em segundo plano**: pode-se fotografar a fatura seguinte logo a seguir.
  - A lista "Por rever" mostra a miniatura e o estado: A ler…, pronta (fornecedor, nº, data, linhas, total) ou erro com instruções.
  - "Introduzir à mão" abre o mesmo ecrã de revisão vazio.
- **Rever fatura:**
  - Cabeçalho: fornecedor (reconhecido por NIF ou nome; senão "Novo fornecedor"), NIF, nº, data e total com IVA.
  - Cada linha tem: descrição, "Incluir" (portes, transporte, ecovalor, taxas, fretes e descontos financeiros vêm desmarcados), produto (existente ou novo, com nome e categoria), quantidade, preço unitário sem IVA, quantidade por embalagem e unidade base.
  - Em baixo de cada linha: o preço por unidade calculado e um aviso se subiu ou desceu 10% ou mais, ou "Preço muito diferente do habitual… confirme o peso, a embalagem e a unidade" (dobro ou metade, e pede confirmação ao guardar).
  - "Guardar fatura e atualizar preços".
- **Histórico:** tabela com data, fornecedor, nº, linhas e total com IVA.

> Hoje quase todas as faturas entram **sozinhas a partir do Guará** (ver 6.1). A leitura por foto fica para faturas que não passam pelo Guará.

### 4.7 Gestão (chefe)

- **Restaurante:** nome, que aparece nas mensagens.
- **Equipa:** nome, perfil (colaborador/chefe), sítio e novo PIN opcional; desativar ou reativar; "Adicionar pessoa" com "Gerar PIN" (6 números ao acaso). Ninguém pode tirar a si próprio o acesso de chefe.
- **Fornecedores:** nome, WhatsApp, dias de encomenda/entrega (texto livre), NIF, mínimo de entrega (€ sem IVA), "Encomendas por" (número ou grupo de WhatsApp), "Texto extra na mensagem" (ex.: "Nif: 515750115") e "Entregas por semana" (para o aviso "a acabar").
- O Continente e a Makro são um só fornecedor, "Bernardo Mendes" (é o dono que vai comprar): as faturas com esses nomes entram nele.
- **Produtos:** procura (ou "sem preço"), corrigir nome, categoria e unidade, **"Juntar com"** (dois produtos que são o mesmo passam a um só, com os preços de todos os fornecedores, as descrições das faturas, o nome na encomenda e a ligação às receitas) e apagar.

### 4.8 Sem rede, instalação e notificações

- O service worker guarda os ficheiros do site (rede primeiro, cópia como reserva). Os últimos dados (catálogo, pedidos, stock) ficam guardados e são mostrados sem rede, com a faixa de aviso.
- **`/instalar`**: página que explica, passo a passo, como instalar no iPhone (Partilhar › Adicionar ao ecrã inicial) e no Android, com um QR para abrir no telemóvel a partir do computador.
- **Notificações push** (Web Push com chaves VAPID): ativam-se no sino. No iPhone só funcionam com a app instalada no ecrã principal. Ao ativar, chega um aviso de teste. Tocar na notificação abre os Pedidos.

---

## 5. Back office do dono (`/backoffice`)

Página própria, mais larga (para computador, mas funciona no telemóvel). Usa o mesmo login da app; se a app já tiver a sessão do dono no mesmo navegador, aproveita-a. Qualquer outra pessoa recebe "só para o dono". Barra de cima: "Back office · nome do restaurante", o nome, "App" e "Sair". Separadores: **Produtos · Preços · CMV**.

### 5.1 Produtos

Só se mudam nomes e formas de encomenda. Tabela com procura e filtros por fornecedor, categoria e "nome na encomenda ainda por escrever". Para cada produto e cada fornecedor:
- **Nome do produto**, o que a equipa vê. Edita-se na própria célula (Enter grava, Esc desfaz). O nome antigo fica guardado para as receitas não perderem a ligação.
- **Descrição da fatura**: só leitura, nunca se muda, porque é por ela que as faturas são reconhecidas.
- **Nome na encomenda**: o que vai na mensagem ao fornecedor. Mostra a pré-visualização "Na mensagem: 2 × …".
- **Forma de encomenda**: lista de caixas de seleção (como está, un, caixa, molho, cuvete, saco e outras que o dono criar com "+ Nova forma…"). A primeira é a de defeito, e tem de ficar pelo menos uma.
- Preço atual por unidade e a data.

### 5.2 Preços

Duas vistas:
- **"Um produto por linha"** (por defeito): preço no início e no fim do período, variação, nº de mudanças (com o mínimo e o máximo), **"No período"** (quanto se pagou a mais ou a menos face ao preço do início), **"Impacto/mês"** (diferença × compra média mensal dos últimos 3 meses) e o nº de pratos que usam o produto.
- **"Todas as mudanças"**: cada fatura em que o preço mudou, com o antes e o agora, a variação, o impacto nessa compra e o impacto por mês.

Filtros: período (7, 30 ou 90 dias, este mês, mês passado, datas à escolha), fornecedor, categoria, só subidas ou descidas, variação mínima, incluir ou não preços estimados. KPIs no topo (subiram, desceram, efeito no mês, no período). Ordenar por coluna. **Exportar para Excel** (CSV com `;`, vírgula decimal e BOM). Preços estimados marcados com "≈ estimado".

**Detalhe do produto** (gaveta da direita, ao tocar numa linha):
- KPIs: último preço, anterior do mesmo fornecedor e variação.
- **Gráfico** da evolução do preço: uma linha por fornecedor; pontos ocos quando o preço é estimado. **Tocar numa zona do gráfico mostra uma etiqueta** com a data, o preço por unidade e o fornecedor (nome curto) do ponto mais perto, com uma linha guia tracejada e um anel no ponto. Com o rato, a etiqueta segue o cursor; com o teclado, as setas passam de ponto em ponto.
- **Pratos afetados:** prato, quanto usa do produto, custo (Guará), PVP (ZSbms), **CMV**, vendidos nos últimos 30 dias e **efeito** da última mudança de preço no custo do prato.
- Faturas: data, fornecedor, nº, preço por unidade e quantidade.

### 5.3 CMV

- **CMV = custo ÷ preço de venda sem IVA.**
- **Custo** = custo da receita no Guará. Se o Guará não o tiver, ou der 0 ou negativo, usa-se o das faturas (receita × últimos preços) e marca-se "pelas faturas". Artigos ligados diretamente a um produto: último preço × fator. Quando o custo do Guará difere mais de 20% do das faturas, aparece por baixo "faturas: x €".
- **PVP** = o preço de tabela no ZSbms mais vendido no período (só linhas pagas), com o IVA da própria linha (13% comida, 23% algumas bebidas, 6% água).
- **KPIs:**
  - **CMV global** = custo de tudo o que se vendeu ÷ vendas sem IVA. As peças do all you can eat, vendidas a 0 €, contam no custo.
  - **All you can eat** = custo das linhas com @ ÷ vendas dos menus "ALL YOU CAN EAT".
  - **Vendas sem IVA** (e com IVA, e dias com vendas).
  - **Artigos sem custo.**
- **Tabela** por artigo do ZSbms, com a receita ou produto ligado, o fator, a categoria, vendidos, custo, PVP com IVA, CMV (vermelho acima de 35%), vendas sem IVA e custo total. Os menus aparecem como "os componentes contam à parte" e as peças do all you can eat como "all you can eat".
- Filtros: procura, período, categoria e "Mostrar" (tudo, CMV acima de 35%, sem custo, all you can eat). Ordenar por vendidos, CMV, vendas ou custo total. Exportar para Excel.

---

## 6. O que corre sozinho no servidor (sem PC)

### 6.1 Faturas do Guará (guara.pt), todos os dias às 10:30 de Lisboa

O Guará é a plataforma onde as faturas dos fornecedores são digitalizadas e correspondidas. A função **só lê** (pedidos GET, com o login guardado como segredo):
1. Lê as 10 primeiras páginas da lista de faturas (só as "Linhas: Concluído", emitidas desde 1/11) e as linhas de cada uma: descrição, quantidade, unidade, preço da embalagem (tabela e "pago" quando há desconto na linha), a correspondência e a embalagem que o Guará atribuiu. **O Guará não mostra o código do artigo do fornecedor**: a identificação é feita pela descrição.
2. **Preço certo de cada linha:**
   - Usa o "pago" quando existe; senão o de tabela.
   - **Desconto no fim da fatura** (ex.: Sumol Compal): reparte-se (total sem IVA − vasilhame) pelos produtos, exceto quando as linhas já vêm com IVA (talho, Continente).
   - **Desconto habitual por artigo** (FRUSTOCK: fruta e legumes 20%, embalados ~15%; Sumol: preço de contrato, ~30–65% da tabela): aprende-se nas faturas com "pago" (pelo menos 2 faturas, últimos 180 dias). Quando falta o "pago", o preço é tabela × desconto habitual. Um "pago" absurdamente baixo também é corrigido assim. O preço fica marcado como **estimado**, com o motivo.
3. Cada fatura fica:
   - **importada**, se todos os artigos já são conhecidos nesse fornecedor;
   - **pendente**, se há artigos novos (resolvidos pela tarefa de correspondência, ver 6.4);
   - **ignorada**, se só tem serviços ou vasilhame;
   - **já existia**, se a fatura já estava na app.
4. **Notas de crédito** (total negativo ou nº a começar por NC) entram com quantidade negativa (tiram stock) e não contam para preços.
5. **Linhas a 0 €** (ofertas) entram no stock sem mexer no preço.
6. O **vasilhame e os depósitos** são produtos (entram nas encomendas), categoria Bebidas, sem desconto.

### 6.2 Receitas do Guará, todos os dias às 10:35

Lê as receitas mexidas há menos tempo (6 páginas) e abre cada uma: nome, rendimento, PVP, IVA, custo total da receita no Guará e ingredientes (com sub-receitas). Grava só as novas ou alteradas e nunca apaga.

### 6.3 Vendas do ZSbms (POS), às 10:10 e às 11:10 UTC

**Só lê** (nunca grava no ZSbms). Para cada dia, desde o último com vendas até hoje:
1. Lista os documentos FT, FA, FS e NC e abre cada um.
2. Soma por dia e artigo: quantidade, total com IVA, **valor sem IVA**, **preço de tabela** (o mais vendido no dia) e **IVA**.
3. Os anulados ficam de fora e as NC subtraem. As linhas de composição interna do ZSbms (ex.: "ARROZ SUSHI" dentro de um uramaki) ficam de fora. Os cabeçalhos de menu entram com a quantidade vendida.

**Artigos do ZSbms → receitas:** cada artigo liga-se a uma receita do Guará (com um fator, ex.: "COMBINADO 48" = 1,5 × "Combinado 32 peças") ou a um produto (ex.: Água 1,5 L), ou é **ignorado** quando os componentes vêm em linhas próprias (menus, all you can eat).

No all you can eat contam as linhas com @: os rolos valem 4 peças e "@Repetição N peças" vale N × a peça média, recalculada a cada importação.

### 6.4 Tarefa diária de correspondência (às 10:47)

Um agente agendado trata do que ficou por decidir:
- artigos novos das faturas pendentes: liga-os ao produto e à embalagem certos, ou ignora-os;
- ingredientes das receitas que se vendem e que ainda não têm produto;
- artigos do ZSbms sem receita.

O texto da tarefa está em `docs/tarefa-correspondencia.md`.

---

## 7. Regras de negócio importantes

1. **Preço por unidade** = preço da embalagem ÷ quantidade por embalagem, sempre **sem IVA**. Unidades base: `un`, `kg`, `L`.
2. **Reconhecer um artigo da fatura:**
   - Fornecedor + descrição exata da fatura (a "oferta"). Cada oferta tem produto e embalagem fixos; a embalagem que vem na linha é ignorada, exceto quando o chefe escolhe o produto à mão.
   - Outras descrições do mesmo artigo (gralhas, tamanhos como "Ebi Fry 2L/3L") ficam numa tabela de **descrições alternativas** (fornecedor + descrição em minúsculas → produto e embalagem).
   - Para mudar a leitura de um artigo corrige-se a oferta (a embalagem), nunca a descrição.
3. **Histórico de preços:** cada fatura grava o preço por unidade de cada produto e fornecedor. As variações comparam com a fatura anterior do mesmo fornecedor.
4. **Encomendas:**
   - Uma por fornecedor; as linhas guardam o nome, a descrição, a referência, a embalagem, o preço da embalagem, a unidade, o sítio e a forma.
   - Linhas com uma forma diferente da original ficam sem preço e não se juntam a linhas de outras formas.
   - Estados: `pendente` → `aprovada` → `enviada`, ou `rejeitada` (com motivo); o colaborador pode cancelar a sua enquanto pendente.
5. **Mínimo de entrega** por fornecedor, sem IVA, contando o que já está em aberto.
6. **Stock** e **consumo** como em 4.5:
   - O `receita_fator` do produto converte a unidade da receita na do produto.
   - As receitas marcadas como acompanhamento não contam duas vezes.
7. **CMV** como em 5.3.
8. **Juntar produtos** leva tudo: ofertas, histórico, linhas de compra, descrições, nome na encomenda e ligação às receitas.

---

## 8. Dados (base de dados)

Tabelas principais (Postgres; prefixo `compras_`):

| Tabela | Para quê |
|---|---|
| `users` | nome, hash do PIN, perfil, ativo, tentativas falhadas, bloqueado até, sítio |
| `sessions` | hash do token, utilizador, validade (60 dias) |
| `settings` | nome do restaurante, início do stock, dono |
| `suppliers` | nome, NIF, telefone, dias, mínimo, via (número/grupo), texto extra da mensagem |
| `products` | nome, categoria, unidade, sítios, `receita_fator` |
| `offers` | produto × fornecedor: descrição da fatura (`alias`), referência, embalagem, preço da embalagem, preço por unidade (atual e anterior, com datas), nome na encomenda, formas de encomenda |
| `offer_aliases` | descrições alternativas → produto e embalagem |
| `formas_encomenda` | formas disponíveis (un, caixa, molho, cuvete, saco…) |
| `orders` | fornecedor, linhas (JSON), nota, estado, entrega, quem criou, quem aprovou, quando enviou, motivo |
| `invoices` | fornecedor, nº, data, total, linhas (JSON com o preço lido, o estimado e o motivo) |
| `invoice_drafts` | faturas fotografadas em leitura, prontas ou com erro |
| `price_history` | preço por unidade por produto, fornecedor, data e fatura |
| `purchase_lines` | quantidades compradas (para o stock) |
| `stock_counts` / `stock_count_lines` | contagens (abertas ou fechadas) e linhas por sítio |
| `recipes` / `recipe_items` / `recipe_aliases` | receitas do Guará, ingredientes (produto ou sub-receita), nomes antigos |
| `sales` | vendas por dia e artigo: quantidade, total, valor sem IVA, preço de tabela, IVA |
| `zs_items` | artigo do ZSbms → receita ou produto, fator, ignorar, peças |
| `guara_faturas` / `guara_cfg` | faturas lidas do Guará e o estado de cada execução |
| `push` / `push_cfg` | subscrições de notificações e chaves VAPID |
| `zs_cfg` | chave interna da função das vendas e resultado da última execução |

**Acesso:** as tabelas não se leem diretamente do navegador. Tudo passa por funções no servidor (RPC) que recebem o token da sessão e validam o perfil (utilizador, chefe ou dono). Principais:
- **Sessão:** `login`, `logout`, `me`, `change_pin`.
- **Catálogo e encomendas:** `catalog`, `submit_order`, `orders`, `order_decide`, `order_items`, `cancel_order`.
- **Stock:** `stock`, `count_start`, `count_set`, `count_get`, `count_close`, `count_cancel`.
- **Faturas:** `save_invoice`, `invoices_list`, `drafts_list`, `draft_delete`.
- **Gestão:** `save_product`, `product_create`, `delete_product`, `offer_save`, `offer_delete`, `merge_products`, `save_supplier`, `users_list`, `user_save`, `set_settings`.
- **Notificações:** `push_save`, `push_delete`.
- **Back office:** `bo_entrar`, `bo_produtos`, `bo_nome_produto`, `bo_nome_encomenda`, `bo_formas`, `bo_formas_oferta`, `bo_precos`, `bo_precos_resumo`, `bo_produto`, `bo_pratos`.

---

## 9. Segurança

- PIN de 6 números guardado só como hash (bcrypt). 5 erros bloqueiam 15 minutos e cada erro espera ~0,4 s.
- Token de sessão aleatório (32 bytes); na base fica só o hash. A sessão dura 60 dias e o logout apaga-a.
- Credenciais do Guará, do ZSbms e da IA de leitura de faturas: **só como segredos das funções no servidor**. Nunca no código, no repositório ou no navegador.
- **Guará e ZSbms: só leitura.** Nunca gravar nada nesses sistemas.
- O mesmo projeto de base de dados tem outra app (finanças pessoais): **não mexer em nada fora das tabelas `compras_`**.

---

## 10. Como está construída hoje (referência)

- **Frontend:** HTML + CSS + JavaScript simples, sem framework nem build. `app/index.html` (a app), `app/backoffice.html`, `app/instalar.html`, `sw.js` (offline e push), `manifest.webmanifest`, ícones. Alojado na **Vercel** como site estático (`/backoffice` e `/instalar` sem `.html`).
- **Backend:** **Supabase** (Postgres com funções `SECURITY DEFINER`, `pg_cron` para os horários e `pg_net` para chamar as funções) e **Edge Functions** em Deno:
  - `compras-guara`: faturas e receitas do Guará;
  - `compras-zs-vendas`: vendas do ZSbms;
  - `compras-ler-fatura`: leitura de fotos e PDFs com o Gemini, em fila;
  - `compras-push`: notificações Web Push.
- **Esquema completo** da base de dados em `supabase/schema.sql`; notas técnicas detalhadas em `CLAUDE.md`.
- **Testes:** Playwright com dados simulados (intercetar `**/rest/v1/rpc/*`), no computador e no telemóvel, em modo claro e escuro, antes de publicar.

---

## 11. Pontos em aberto (conhecidos a 18/11/2026)

- **Custos do Guará diferentes das faturas** em cerca de 45 pratos: o Guará usa preços de tabela (ex.: Pepsi Max 1,38 € no Guará contra 0,55 € nas faturas da Sumol). O dono vai corrigir no Guará.
- **Artigos diferentes ligados ao mesmo produto**, com preços que saltam:
  - Wasabi Kona 1 kg / Aragiri 300 g;
  - Vinagre de arroz Uchibori / Shiragiku;
  - Pano sintético em rolo;
  - Ebi 3L/4L/5L;
  - Pauzinhos.

  Ainda por decidir se ficam produtos separados.
- O Guará não traz o **peso** dos artigos vendidos ao kg (ex.: salmão na Makro): esses preços podem vir errados.
- 16 artigos vendidos sem custo (batatas fritas de pacote, frutos secos, Mateus, meia dose de whisky).
