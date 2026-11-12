# Notas para o Claude

- O utilizador é o dono do restaurante; fala português de Portugal. Respostas curtas e práticas; perguntar antes de construir algo grande.
- `app/index.html` é a app inteira (vanilla JS). Testar com Playwright e dados simulados (intercetar `**/rest/v1/rpc/*`) antes de publicar.
- Publicar: fazer commit e push para `main` e depois criar o deployment na Vercel a partir do GitHub (equipa `team_wmcwdYOtBPWubDUrH1mCoxHL`, projeto `compras-focus`, `target: production`, `gitSource` github `bernardonfmendes/encomendas-focus` com o sha do commit; o projeto NÃO tem `rootDirectory` guardado: o pedido tem de levar sempre `projectSettings: {rootDirectory: "app", framework: null, buildCommand: null, installCommand: null, outputDirectory: null}`, senão a Vercel serve a raiz do repositório e o site dá 404). Testar primeiro com um deploy de pré-visualização (sem `target`) e só depois fazer o de produção. Depois de um rollback, o domínio fica preso ao deploy reposto: usar `request_promote` no novo deploy de produção. Depois confirmar que https://compras-focus.vercel.app serve o ficheiro igual a `app/index.html`.
- Base de dados: Supabase `cckgrpmspyurgmbgtjdu`. Alterações de estrutura com migrations; manter `supabase/schema.sql` atualizado.
  Tabelas `compras_*` só são acedidas por funções SECURITY DEFINER que recebem `p_token`; `compras__user`/`compras__chefe` validam a sessão.
- O mesmo projeto Supabase tem a app de finanças pessoais (outras tabelas). Não mexer em nada fora de `compras_*`.
- Faturas: o Guará (guara.pt) é a fonte principal; importam-se a pedido ("dá-lhe agora"), com `compras_import_invoice` (a tarefa agendada de domingo está desligada). Receitas: `compras_import_recipes` (sempre `p_completo:false`).
  Atenção: o Guará não traz o peso de artigos vendidos ao kg (ex.: salmão na Makro), por isso esses preços podem vir errados.
- Nunca pôr PINs, chaves ou palavras-passe no repositório.
