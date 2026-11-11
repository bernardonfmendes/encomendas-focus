# Notas para o Claude

- O utilizador é o dono do restaurante; fala português de Portugal. Respostas curtas e práticas; perguntar antes de construir algo grande.
- `app/index.html` é a app inteira (vanilla JS). Testar com Playwright e dados simulados (intercetar `**/rest/v1/rpc/*`) antes de publicar.
- Publicar: Vercel, equipa `team_wmcwdYOtBPWubDUrH1mCoxHL`, projeto `compras-focus`, `target: production`, ficheiros da pasta `app/`. Depois confirmar que https://compras-focus.vercel.app serve o ficheiro igual ao local.
- Base de dados: Supabase `cckgrpmspyurgmbgtjdu`. Alterações de estrutura com migrations; manter `supabase/schema.sql` atualizado.
  Tabelas `compras_*` só são acedidas por funções SECURITY DEFINER que recebem `p_token`; `compras__user`/`compras__chefe` validam a sessão.
- O mesmo projeto Supabase tem a app de finanças pessoais (outras tabelas). Não mexer em nada fora de `compras_*`.
- Faturas: o Guará (guara.pt) é a fonte principal; há uma tarefa agendada ao domingo que importa faturas novas com `compras_import_invoice`.
  Atenção: o Guará não traz o peso de artigos vendidos ao kg (ex.: salmão na Makro), por isso esses preços podem vir errados.
- Nunca pôr PINs, chaves ou palavras-passe no repositório.
