# Tarefa agendada: relatório do fim do dia

Corre todos os dias às 22:57 (Lisboa), numa sessão nova do Claude na nuvem, e manda uma notificação ao telemóvel.
Precisa do conector Supabase (juntar na página das tarefas no claude.ai; a tarefa foi criada sem ele).
Só lê: chama `compras_relatorio_dia()` e escreve o relatório. Texto da tarefa "Relatório do fim do dia (faturas lidas)":

```
Relatório do fim do dia da app de compras do restaurante Focus Sushi & Steak, para o dono ler no telemóvel. Responde em português de Portugal, curto e em lista.

Regras: usa só o conector Supabase (ferramentas mcp__Supabase__*, carrega-as com ToolSearch), projeto cckgrpmspyurgmbgtjdu. Só lês: não alteras nada nem chamas outras funções além das indicadas. Se o conector Supabase não estiver disponível, diz só isso: "Falta juntar o conector Supabase a esta tarefa (página das tarefas no claude.ai)". Nunca escrevas PINs, chaves ou palavras-passe.

1. Corre: select compras_relatorio_dia();
2. Escreve o relatório com este formato (números do JSON; datas e horas em hora de Lisboa, formato dd/mm e hh:mm):

Relatório do fim do dia — dd/mm
• Faturas antigas (jan–ago) lidas hoje: N (por fornecedor: ...). Total lidas: X de 872; faltam Y. Se lidas_no_dia > 0, previsão ao ritmo de hoje: ~Y ÷ N dias. Se lidas_no_dia_sem_bater > 0: "N lidas com a soma a não bater certo (ficam marcadas)". Se com_erro > 0 ou sem_documento > 0, diz quantas.
• Leitura automática: a correr / em pausa até hh:mm (motivo: limite diário da Gemini, Gemini sobrecarregada...) / parada (se leitura_automatica_ligada for false e ainda faltam faturas, ou se nenhuma foi lida hoje sem haver pausa: diz claramente que parou). Se faltarem 0, diz que acabou.
• Faturas novas do Guará hoje: recebidas_no_dia (importadas: fornecedor, nº e total; pendentes à espera de correspondência: pendentes_agora).
• Artigos das faturas antigas ligados hoje a produtos: ligados_no_dia (ignorados: ignorados_no_dia); faltam ligar: faltam_ligar.
• Agente da manhã: se agente_da_manha.correu_em for de hoje, resume numa linha o resultado (faturas importadas, produtos novos, ingredientes e artigos do ZSbms ligados, o que ficou por decidir); se não correu hoje, diz que não correu.
• Importações automáticas desta manhã: se faturas_ok ou receitas_ok não forem true, ou não forem de hoje, avisa.

Nada mais: sem explicações técnicas.
```
