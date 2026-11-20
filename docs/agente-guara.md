# Para o agente do Guará: compras, encomendas, stock e vendas do Focus Sushi & Steak

**De:** o agente que construiu e mantém a app "Compras" do restaurante (20/11/2026).
**Para:** ti, que vais trabalhar dentro do Guará, com acesso direto às faturas, linhas, receitas e restantes dados do Guará.

**O que o dono quer:** que as funções da app "Compras" passem a viver dentro do Guará: **encomendas aos fornecedores, stock, contagens, saídas de stock pelas vendas, preços certos e CMV**. Este texto explica o que a app faz hoje e as regras que foram acertadas com o dono ao longo de semanas. A descrição completa, ecrã a ecrã (visual, botões, mensagens), está no anexo `especificacao-app.md`.

---

## 0. Antes de construir

1. **Vê primeiro o que o Guará já faz de raiz:** stock e inventário, encomendas a fornecedores, ligação às vendas do POS (ZSbms, da ZoneSoft), CMV. O dono acha que as vendas já chegam ao Guará: confirma. Depois diz-lhe, curto, o que já existe, o que falta e como propões fazer, e **pergunta antes de construir algo grande**.
2. **A app atual continua a funcionar até a tua versão estar pronta** e o dono dizer para a desligar. A equipa encomenda por ela todos os dias: não pode haver um dia sem encomendas.
3. **Como falar com o dono:** português de Portugal, respostas curtas e práticas, sem termos técnicos. Ele usa sobretudo o telemóvel.

---

## 1. O restaurante e quem usa

- **Sítios:** Cozinha, Sushi, Bar e Take away. O Armazém só existe na contagem.
- **Perfis:**
  - **Colaborador:** encomenda, vê os seus pedidos, vê e conta o stock.
  - **Chefe:** tudo isso, mais confirmar, editar, rejeitar e enviar encomendas; gerir produtos, fornecedores e equipa; fechar contagens.
  - **Dono:** é chefe e tem ainda o back office (preços, CMV, nomes dos produtos e da encomenda).
- **Uso:** tudo no telemóvel, botões grandes, modo claro e escuro, e funciona sem rede com os últimos dados guardados.
- **Categorias:** Peixe e marisco, Carne, Legumes e fruta, Mercearia, Bebidas, Limpeza e higiene, Descartáveis, Outros.
- **Unidades base:** `un`, `kg`, `L`.

---

## 2. Encomendas (tem de funcionar exatamente assim)

**Fluxo:**
1. O colaborador escolhe o sítio, procura o produto, carrega em "+" e envia ao chefe.
2. Cria-se **uma encomenda por fornecedor**. Se já houver uma em aberto desse fornecedor, os produtos juntam-se a ela.
3. O chefe recebe uma notificação ("Nova encomenda por confirmar") e então:
   - confirma, muda quantidades ou rejeita (com motivo, que o colaborador vê);
   - pode pôr data de entrega;
   - as encomendas feitas pelo chefe ficam logo aprovadas.
4. **Envio ao fornecedor por WhatsApp,** numa mensagem já escrita: abre a conversa do número do fornecedor, ou partilha no grupo de WhatsApp quando o fornecedor recebe por grupo. Depois o chefe marca a encomenda como "enviada".
5. **Estados:** por confirmar → aprovada → enviada, ou rejeitada. O colaborador pode cancelar a sua enquanto está por confirmar. Há também "Repetir esta encomenda".

**Mensagem ao fornecedor** (as quantidades de vários sítios somam-se por produto):
```
Boa tarde! Encomenda do Focus Sushi & Steak:
- 2 × Shoyu Yamasa 18l [18 L] (ref. 123)
- 1,5 kg SALMAO 5/6
- 10 un Abacate

Nif: 515750115
Entrega: sexta-feira, 20 de novembro
Nota: entregar antes das 11h

Obrigado.
```
- **Saudação** conforme a hora: Bom dia (5h–12h), Boa tarde (12h–19h), Boa noite.
- **Granel:** "1,5 kg Descrição".
- **Embalagem:** "2 × Descrição [tamanho]", com "(ref. X)" quando há referência.
- **Nome na encomenda** (por produto e fornecedor, definido pelo dono): quando existe, vai só esse nome, sem embalagem nem referência.
- **Formas de encomenda** (por produto e fornecedor, definidas pelo dono; ex.: banana em kg ou un):
  - quem encomenda escolhe a forma ao lado da quantidade;
  - uma forma diferente da original vai **sem preço** e só muda a encomenda; faturas, preços e stock continuam na unidade do produto;
  - linhas de formas diferentes não se juntam;
  - não se usa peso aproximado;
  - o Continente fica como está.
- **Texto extra por fornecedor:** vai em todas as mensagens a esse fornecedor, antes da entrega e da nota. A Keta Foods leva "Nif: 515750115". Não uses o campo NIF do fornecedor para isto: é por ele que se reconhecem as faturas.

**Mínimo de entrega** por fornecedor (sem IVA): conta também o que já está pedido e em aberto a esse fornecedor, e aparece com uma barra de progresso.

**Na lista de produtos, cada produto mostra:**
- o preço do fornecedor mais barato por unidade (ex.: "83,00 € emb. 20 kg · Kiku · 4,15 €/kg");
- a variação face à fatura anterior, quando é de 3% ou mais;
- os outros fornecedores e os seus preços;
- o stock e o ritmo ("gasta ~8 kg/semana · para 7 dias faltam ~4,8 kg").

---

## 3. Stock

**Fórmula:** stock = última contagem (ou 0 na data de início) + compras das faturas − consumo das vendas.

**Consumo:** vendas do POS × ingredientes das receitas, com sub-receitas. Duas correções:
- `receita_fator` converte a unidade da receita para a do produto;
- as receitas marcadas como **acompanhamento** não contam duas vezes.

O consumo por dia é a média das últimas 4 semanas com vendas.

**Hora da contagem:**
- Um produto contado conta a partir da **hora** em que foi contado.
- As vendas desse dia entram se foi contado antes das 17h.
- As faturas desse dia entram se foi contado antes das 10h.
- Houve um erro aqui: contava desde o dia em que a contagem foi aberta e não desde a hora de cada produto.

**Contagem** (pedido do dono, 19/11):
- **É uma lista só**, sem sítios, com pesquisa e por categoria.
- Cada quantidade escrita **soma-se** ao que já está contado: 10 águas na cozinha + 10 no armazém = 20. Aceita "5+3".
- "↶" tira a última soma. Grava sozinho. "—" quer dizer "não contado".
- **Forma de contar:**
  - bebidas em garrafas, barris, latas ou embalagens, com o volume do nome ou da embalagem: gin em garrafas de 0,7 L, cerveja em barris de 50 L, leite em pacotes de 1 L;
  - o resto na unidade do produto (kg, un).
- Aceita decimais: uma garrafa aberta a meio conta 1,5. A app mostra o total ("1,5 garrafas = 1,05 L").
- O chefe fecha a contagem: os contados passam a valer o que se contou e os outros ficam com o valor calculado. Depois mostram-se as diferenças (contado − esperado).
- Recomendação ao dono: contar tudo de uma vez, incluindo o armazém, de manhã antes de abrir ou à noite depois de fechar. A primeira contagem (17–18/11) foi só do restaurante, sem o armazém. Esses stocks estão abaixo do real, por isso falta uma contagem completa.

**Ritmo e "a acabar":**
- Calcula-se quanto entra por semana (faturas das últimas 4 semanas) e quanto se gasta por dia.
- Cada fornecedor tem "entregas por semana", escrito pelo chefe; se estiver vazio, estima-se pelas faturas.
- **"A acabar"** = o stock não chega até à próxima entrega + 1 dia. Assim, o que vem todos os dias não dá alarme cedo demais, e o que vem uma vez por semana avisa a tempo.
- Nas bebidas mostra-se também o equivalente em garrafas e barris.

---

## 4. Saídas pelas vendas (POS ZSbms)

**De onde vêm as vendas:**
- Se o Guará já recebe as vendas do ZSbms, usa-as. Confirma que tens, **por dia e por artigo**: quantidade, valor sem IVA, preço de tabela (PVP) e taxa de IVA, sem os documentos anulados e com as notas de crédito a subtrair.
- Se não tiver, a app atual lê-as sozinha todos os dias, num servidor e só em leitura. Mantém essa leitura até o Guará as ter.
- **Nunca gravar nada no ZSbms.**

**Regras de leitura:**
- Entram os documentos FT, FA, FS e NC; os anulados ficam de fora e as NC subtraem.
- As **linhas de composição interna** (ex.: "ARROZ SUSHI" dentro de um uramaki) ficam de fora.
- Os **cabeçalhos de menu** entram com a quantidade vendida:
  - uns ignoram-se, porque os componentes vêm em linhas próprias;
  - outros têm receita própria (ex.: "SEQUENCIA ALMOÇO").

**Ligação artigo do POS → receita do Guará ou produto.** É o que transforma vendas em saídas de stock:
- Cada artigo liga-se a uma receita com um **fator** (ex.: "COMBINADO 48" = 1,5 × "Combinado 32 peças"), ou a um produto vendido tal e qual (garrafa, lata, snack), ou é ignorado.
- **All you can eat:**
  - contam as linhas com "@";
  - as doses são meias (fator 0,5, como "@1/2 Dose de maminha");
  - os rolos valem 4 peças;
  - "@Repetição N peças" = N × a peça média, recalculada a cada importação.
- **Espirituosas sem receita:** dose = 0,07 L e meia dose = 0,035 L.
- **Feijão preto:** os artigos 474 e 475 vão para a receita "Feijão preto Dose" (200 g de "Feijão preparação").
- **Frutos secos:** o tabuleiro tem 12 amendoins + 6 cajus e é o produto "Frutos secos (tabuleiro)"; cada saqueta vendida gasta 1/18.
- **Batatas da Genialis:**
  - Ruffles Sal = Ruffles Original 45 g;
  - Doritos Tex Mex e Bits BBQ = Doritos (saco);
  - Cheetos Futebolas e Sticks = Cheetos (saco);
  - Lays Forno à tira de 6.

Há uma tarefa diária que liga os artigos novos do POS e os ingredientes das receitas que ainda não têm produto. Só liga o que é claro; o resto fica para o dono decidir.

---

## 5. Preços certos das faturas

Aqui tens vantagem: estás dentro do Guará e podes corrigir na origem. Estas são as regras que a app aplica hoje às linhas que o Guará extrai:

**Regras gerais:**
- Preço por unidade = preço da embalagem ÷ quantidade por embalagem, **sempre sem IVA**.
- **Preço da linha:** o "pago" quando há desconto na linha; senão, o de tabela.
- **Desconto no fim da fatura** (ex.: Sumol Compal):
  - reparte-se (total sem IVA − vasilhame) pelos produtos;
  - exceção: quando a soma das linhas bate com o total **com IVA** (talho, Continente), porque as linhas já vêm com IVA;
  - nas faturas da Sumol sobram sempre 15–30 € sem linha (uma taxa), que não se repartem.

**Desconto habitual por artigo:**
- A FRUSTOCK (que é a **Bidfood Portugal, SA**) faz 20% na fruta e legumes, ~15% nos embalados, e alguns artigos não têm desconto.
- A Sumol tem preço de contrato, ~30–65% da tabela.
- O desconto aprende-se nas faturas que mostram o "pago" (pelo menos 2 faturas nos últimos 180 dias).
- Sem "pago", o preço é tabela × desconto habitual.
- Um "pago" absurdamente baixo também se corrige assim: o Guará já leu valores ~5× abaixo na FRUSTOCK.
- O preço corrigido fica marcado como estimado, com o motivo.

**IEC (imposto sobre o álcool) da Garcias:**
- Desde 19/10 o IEC vem numa coluna à parte e o Guará lê o preço sem IEC.
- Nas bebidas espirituosas (15% vol. ou mais), soma-se litros × grau × 16,0265 € (taxa de 2026 por litro de álcool puro).
- **Atualizar a taxa quando mudar no Orçamento do Estado.**

**Casos especiais:**
- **Notas de crédito** (total negativo ou número a começar por NC): tiram stock e não contam para preços.
- **Linhas a 0 €** (ofertas): entram no stock sem mexer no preço.
- **Vasilhame e depósitos** ("Vasilhame grade Pepsi 24×0,30 L", "Vasilhame barril Damm 50 L", "Depósito SDR"…):
  - são produtos da categoria Bebidas e entram nas encomendas;
  - nunca levam desconto;
  - as notas de crédito de vasilhame (ZCD da Sumol) tiram stock.

**Reconhecer o artigo:**
- Cada artigo é reconhecido por fornecedor + descrição da fatura e tem **produto e embalagem fixos**; a embalagem que vem na linha é ignorada.
- As outras descrições do mesmo artigo (gralhas, "0,70"/"0.70", "(B)" no fim, "TEQ.J"/"TEJ.") ficam como descrições alternativas.
- Tamanhos diferentes (0,70 L e 1 L) são o mesmo produto, com embalagens diferentes.
- **Nunca criar um segundo produto para um artigo que já existe.** A 14/11 ficaram 7 repetidos e foi preciso juntá-los.
- Juntar dois produtos leva tudo: preços, histórico, descrições, nome na encomenda e ligação às receitas.

**Limitações conhecidas do Guará:**
- Não traz o código do artigo do fornecedor.
- Não traz o **peso** dos artigos vendidos ao kg (ex.: salmão da Makro: "SALMAO (SAL) NORUEGA" = 6,4 kg). Esses preços podem vir errados.
- Há faturas da FRUSTOCK só com parte das linhas extraídas.

**Faturas de janeiro a agosto de 2026:**
- No Guará estão como "Linhas: Inativa" (sem linhas). A app está a lê-las do documento com a IA (Gemini, gratuita), uma a uma, para tirar só o produto e o preço final, sem faturas nem stock.
- São 872 faturas de fornecedores; ficam de fora a CAF e os serviços.
- **Se no Guará conseguires ativar a extração das linhas dessas faturas, é melhor e mais rápido.** Diz ao dono.

---

## 6. CMV

- **CMV = custo ÷ preço de venda sem IVA.**
- **Custo:**
  - é o custo da receita no Guará;
  - se faltar, ou for 0 ou negativo, usa-se o das faturas (receita × últimos preços);
  - artigos ligados a um produto: último preço × fator;
  - quando o custo do Guará difere mais de 20% do das faturas, mostra-se os dois.
  - Problema conhecido: o Guará usa preços de tabela. A Pepsi da Sumol custa 1,38 € no Guará e 0,55 € nas faturas, o que afeta ~45 pratos. Dentro do Guará, o ideal é o custo das receitas usar os preços reais das faturas.
- **PVP:** o preço de tabela do POS mais vendido no período (só linhas pagas), com o IVA da própria linha (13% comida, 23% algumas bebidas, 6% água).
- **CMV global:** custo de tudo o que se vendeu ÷ vendas sem IVA. As peças do all you can eat, vendidas a 0 €, contam no custo.
- **CMV do all you can eat:** custo das linhas "@" ÷ vendas dos menus "ALL YOU CAN EAT".
- **Valores de referência** (últimos 30 dias até 19/11): CMV global ~23%, all you can eat ~34%.
- O dono quer ver também:
  - por prato: CMV, vendidos, vendas e custo total, com vermelho acima de 35%;
  - os artigos sem custo;
  - os pratos afetados quando um ingrediente muda de preço.
- **Relatório de preços do dono:**
  - vista por defeito: "um produto por linha" (preço no início e no fim do período, nº de mudanças, quanto se pagou a mais ou a menos). A Meta, por exemplo, alterna 14,90/15,90 €/kg de fatura para fatura;
  - vista "todas as mudanças";
  - gráfico em que se toca num ponto e se vê data, preço e fornecedor;
  - exportar para Excel.

---

## 7. O que corre sozinho hoje (para manter ou substituir)

| Hora (Lisboa) | O quê |
|---|---|
| 10:10 e 11:10 | Vendas do POS do dia anterior |
| 10:30 | Faturas novas do Guará (com as regras de preço da secção 5) |
| 10:35 | Receitas do Guará novas ou alteradas |
| 10:47 | Tarefa de correspondência e **"Relatório da manhã"** para o telemóvel do dono |
| 22:57 | **"Relatório do fim do dia"**: faturas antigas lidas, faturas novas, artigos ligados, o que a tarefa da manhã fez |
| a cada minuto | Leitura das faturas antigas (jan–ago), até acabar |

O dono quer **sempre** os dois relatórios diários (manhã e fim do dia) no telemóvel. Mantém-nos.

---

## 8. Decisões já tomadas com o dono (não voltar a perguntar)

**Produtos e embalagens:**
- Açúcar da FRUSTOCK à caixa de 10 kg. O açúcar da Delta é outro produto, "Açúcar em saquetas (café)", à caixa.
- Ebi Fry = 10 un.
- "Kimchi Sauce 1l" (molho, 1 L) e "Kimchi no Moto 1,2 kg" são produtos diferentes.
- Tomate cherry ao kg.
- Bolos da avó à unidade (só muda o sabor).
- Frize natural à grade de 24.
- Água Serra da Estrela 1 L de vidro à grade de 12.
- "Ruffles ketchup" é batata, não é molho.

**Fornecedores:**
- **Continente + Makro = um só fornecedor, "Bernardo Mendes"** (é o dono que vai comprar).
- "Genialis, Lda" = "Genialis".
- Pão brioche: FRUSTOCK/Bidfood (e Continente).
- Bolo do caco: Panicaco.
- Papel de arroz: Kiku.
- Mateus, Papa Figos e Famous Grouse são da Garcias. O Mateus já tem preço: 2,94 €/garrafa, de uma fatura de 27/08. O Papa Figos e o Famous Grouse ainda não têm custo.

**Faturas que entram:**
- W4U (vinho da casa Herdade da Candeeira).
- NB Machado (talheres, material de sala).
- Abreu & Pedra (limpeza, tudo).
- Notas de crédito (coisas que vieram por engano ou a mais).
- Carnes da Meta para o staff: "Coser e guisar", "Espetadas de peru", "Bife para assar".

**Fica de fora:**
- O equipamento da Makro.
- A pedra de afiar da Keta.
- O "material de casa" da Chengchunsheng.
- O queijo flamengo do Continente (vem sem peso).
- A CAF (não é comida do restaurante).
- Serviços (desinfestação, software, renda, contabilidade…).

**Outras decisões:**
- **Contagem sem sítios e com somas** (ver secção 3).
- **Formas de encomenda por fornecedor**, sem peso aproximado.
- **Sem custos extra de IA:** o dono não quer pagar outra API para ler documentos. Usa-se a Gemini gratuita, com pausas quando acaba o limite.

---

## 9. Dados a trazer da app atual

Tudo está numa base de dados Postgres (Supabase), em tabelas com o prefixo `compras_`. O dono pode pedir uma exportação (CSV ou JSON). Vale a pena trazer:

- **Produtos:** nome, categoria, unidade, sítios, forma de contar (`contar_em`/`contar_fator`), `receita_fator`.
- **Fornecedores:**
  - nome, NIF, WhatsApp, recebe por número ou grupo;
  - dias de encomenda e entrega, mínimo, entregas por semana, texto extra da mensagem;
  - e os outros nomes com que aparecem nas faturas.
- **Ofertas** (produto × fornecedor): descrição da fatura, referência, embalagem, preço atual e anterior com datas, nome na encomenda, formas de encomenda.
- **Descrições alternativas** (fornecedor + descrição → produto e embalagem). É o que evita produtos repetidos.
- **Histórico de preços** e **linhas de compra** (para o stock).
- **Ligações:**
  - artigo do POS → receita ou produto, com fator, peças e ignorar;
  - ingrediente das receitas → produto;
  - nomes antigos dos produtos, para as receitas não perderem a ligação.
- **Contagens** (a última fechada é a base do stock) e **encomendas** (histórico).
- **Equipa:** nomes, perfis e sítios. Os PINs não se trazem; dão-se acessos novos.
- **Faturas antigas lidas** (jan–ago), com o preço final por artigo.

---

## 10. Limites e segurança

- **Credenciais** (Guará, ZSbms, IA, notificações) nunca no código, no chat ou no navegador: só como segredos do servidor.
- **ZSbms: só leitura.** Nunca gravar nada no POS.
- A mesma base de dados do Supabase tem **outra app do dono (finanças pessoais)**: não mexer em nada que não seja das tabelas `compras_`.
- **Desligar a app atual só quando o dono disser.** Nessa altura é preciso desligar também:
  - as tarefas agendadas (correspondência das 10:47 e relatório das 22:57);
  - as leituras automáticas no servidor (vendas, faturas, receitas e faturas antigas).

---

## 11. Em aberto

- **Custo das receitas no Guará com preços de tabela** em vez dos reais (ver CMV). O dono disse que ia corrigir no Guará.
- **Artigos diferentes no mesmo produto**, com preços que saltam. Falta o dono decidir se se separam:
  - Wasabi: Kona 1 kg (em pó) / Aragiri 300 g (picado);
  - Vinagre de arroz: Uchibori / Shiragiku;
  - Pano sintético em rolo / pano solto;
  - Ebi 3L, 4L e 5L;
  - Pauzinhos.
- **Ebi fry 2L:** o consumo calculado (~75 por dia) parece demasiado alto. Confirmar as receitas: tempura de camarão 5, hot poke 4, combinado do chefe 2,3.
- **Entregas por semana** de cada fornecedor por preencher. Estimativa pelas faturas: Conquista Salgada ~3×, Meta 2×, Kiku ~2×, FRUSTOCK/Sumol/Brasão Rosa ~1×, Delta/Garcias/Genialis de 2 em 2 semanas.
- **Contagem completa** (com armazém) por fazer.
- **Pingo Doce:** está como fornecedor à parte; falta o dono dizer se junta ao "Bernardo Mendes".
- **Papa Figos e Famous Grouse** sem custo: esperar pelas faturas antigas da Garcias, ou pôr o preço à mão.
