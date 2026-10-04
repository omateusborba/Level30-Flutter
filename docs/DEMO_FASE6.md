# Fase 6 — Roteiro de demonstração (camada Oracle)

> Pré-requisito: Oracle local rodando com `LEVEL30_ORACLE_ENABLED=true` — ver
> ["Como ativar"](../README.md#como-ativar) no README e [`db/oracle/README.md`](../db/oracle/README.md).
> Sem Oracle ativo, os passos 2–4 mostram o 503 "Camada Oracle desabilitada neste ambiente" em
> vez dos dados — também é uma demonstração válida do fallback gracioso.

## 1. Concluir um dia no app

1. Abra o app Flutter (`flutter run --dart-define=API_BASE_URL=http://localhost:8080`), logado
   com um usuário que tenha um desafio ativo.
2. Na Home, toque no desafio → **Concluir hoje**.
3. O app responde normalmente (XP, streak, conquistas) — a réplica no Oracle acontece depois,
   fora do caminho crítico; o aluno não espera por ela.

## 2. Mostrar o log "Conclusão replicada no Oracle"

No terminal onde o backend está rodando (`mvn spring-boot:run`), procure a linha emitida pelo
`EngajamentoEventListener` logo após o passo 1:

```
INFO ... c.l.a.service.EngajamentoEventListener : Conclusão replicada no Oracle: desafio=<uuid> dia=<N> alertas=<n>
```

Ela roda numa thread `oracle-*` (pool dedicado, `oracleExecutor`) — visível no prefixo de thread
do log. Se o Oracle estiver desligado ou fora do ar, aparece um `WARN` no lugar, e nada mais
quebra.

## 3. Consultar `L30_COMPLETIONS` e `L30_ALERTS`

Conecte no Oracle (SQL Developer, ou `sqlplus` dentro do container local) e confira a réplica:

```sql
-- A conclusão do passo 1 deve aparecer aqui
SELECT challenge_id, user_id, day_number, completed_on, xp_delta
  FROM l30_completions
 ORDER BY created_at DESC
 FETCH FIRST 5 ROWS ONLY;

-- Log de execução da procedure (auditoria, grava mesmo se o resto falhar)
SELECT routine, status, detail, executed_at
  FROM l30_execution_log
 ORDER BY executed_at DESC
 FETCH FIRST 5 ROWS ONLY;

-- Alertas abertos (inatividade, adesão baixa, streak reiniciado)
SELECT alert_type, severity, message, created_at
  FROM l30_alerts
 WHERE resolved = 0
 ORDER BY created_at DESC;
```

Reenvie a mesma conclusão (toque de novo em "Concluir hoje" não é possível no mesmo dia, mas
re-chamar a procedure manualmente ou repetir a requisição HTTP) para mostrar que
`l30_completions` **não duplica** — a `UNIQUE (challenge_id, completed_on)` segura isso.

## 4. Gerar o relatório no dashboard

1. Abra o dashboard (`npm start` em `dashboard/`), logado como ADMIN.
2. Menu superior → **Oracle**.
3. Confira o período (padrão: últimos 30 dias) e clique em **Gerar relatório**.
4. Mostre:
   - os 5 cards de faixa (ALTO / MODERADO / EM_RISCO / CRITICO / SEM_DESAFIO);
   - a tabela por aluno (desafios ativos, conclusões, adesão %, streak, faixa);
   - a lista de **Alertas abertos**, e o botão **Verificar inatividade agora** (roda
     `pr_verificar_inatividade` sob demanda, fora do agendamento diário).
5. Para mostrar o fallback: pare o backend, suba de novo sem `LEVEL30_ORACLE_ENABLED` (ou com
   `false`) e recarregue a página — aparece o estado "Camada Oracle desabilitada neste
   ambiente", sem erro genérico.
