# Encomendas Focus

App de compras do **Focus Sushi & Steak**: os colaboradores escolhem produtos e fornecedores (com preços das últimas faturas), o chefe confirma e envia a encomenda por WhatsApp.

- **App:** https://compras-focus.vercel.app
- **Página:** um único ficheiro, `app/index.html` (HTML + CSS + JavaScript, sem build).
- **Dados:** Supabase, projeto "financas" (`cckgrpmspyurgmbgtjdu`), tabelas `compras_*`.
- **Notificações (push):** função `supabase/functions/compras-push` (web-push). Chaves de envio geradas na primeira utilização e guardadas em `compras_push_cfg`.
- **Leitura de faturas:** função `supabase/functions/compras-ler-fatura` (Gemini, chave no segredo `GEMINI_API_KEY`).
- **Alojamento:** Vercel, projeto `compras-focus`.

## Estrutura

```
app/                      o que é publicado na Vercel
  index.html              a app toda
  manifest.webmanifest    para instalar no telemóvel
  icon.svg, icon-192.png
  vercel.json             cabeçalhos
supabase/
  schema.sql              tabelas e funções (cópia de referência da base de dados)
  functions/compras-ler-fatura/index.ts
```

## Como funciona (resumo)

- Login com nome + PIN de 6 números. Perfis: `colaborador` e `chefe`.
- Todo o acesso aos dados passa por funções `compras_*` no Supabase (RPC), que validam o token de sessão.
  As tabelas têm RLS ativo sem políticas, por isso não se lêem diretamente.
- Sítios: Cozinha, Sushi, Bar, Take away. Cada linha de encomenda guarda o sítio; ao fornecedor vai o total somado.
- Uma encomenda aberta por fornecedor: pedidos novos juntam-se à que ainda não foi enviada.
- Produtos ao kg/L sem embalagem andam de 0,5 em 0,5; produtos com embalagem contam em embalagens.

## Trabalhar no Claude Code

```
git clone https://github.com/bernardonfmendes/encomendas-focus
cd encomendas-focus
claude mcp add --transport http supabase https://mcp.supabase.com/mcp
claude mcp add --transport http vercel https://mcp.vercel.com
claude
```

Depois é só pedir, por exemplo: "acrescenta X à app e publica".
