# Fase 7 — Descoberta (Fase 0)

Levantamento feito antes de qualquer alteração. Nada bloqueou as fases seguintes; as divergências
em relação ao prompt estão na seção final e foram resolvidas como descrito.

## Estrutura

| Parte | Pasta | Observação |
|---|---|---|
| App Flutter | `lib/`, `test/`, `pubspec.yaml` | `flutter analyze` / `flutter test` |
| API Spring Boot | `backend/` | **Maven**, **Java 21**, Spring Boot 3.5.5 |
| Dashboard Angular | `dashboard/` | `npm test` = Karma/ChromeHeadlessCI; build prod já usado no CI |
| Scripts Oracle (Fase 6) | `db/oracle/` | `00_drop` … `05_job_opcional`, mais `README.md` |
| Deploy | `deploy/` | `docker-compose.yml` (postgres + api + cloudflared), `Dockerfile.runtime` só copia o jar |
| Oracle local | `docker-compose.oracle.yml` | `gvenzl/oracle-free:23-slim-faststart` |

## Tabelas e colunas Oracle reais (Fase 6)

| Papel no prompt | Nome real | Colunas relevantes |
|---|---|---|
| usuários | `l30_users` | `id VARCHAR2(36)`, `name`, `email`, `role` (USER/ADMIN), `total_xp` |
| desafios | `l30_challenges` | `id`, `user_id`, `title`, `start_date`, `current_day`, `streak`, `status` (ATIVO/CONCLUIDO/ABANDONADO), `ended_on`, `last_activity_at` |
| conclusões | `l30_completions` | `id` (identity), `challenge_id`, `user_id`, `day_number`, `completed_on`, `xp_delta` |
| alertas | `l30_alerts` | `id`, `user_id`, `challenge_id`, `alert_type` (INATIVIDADE/ADESAO_BAIXA/STREAK_REINICIADO), `severity`, `message`, `measured_value`, `resolved NUMBER(1)`, `created_at`, `resolved_at` |
| `RELATORIO_ENGAJAMENTO` | `l30_engagement_reports` | `execution_id`, `user_id`, `period_start/end`, `adherence_rate`, `engagement_band`… |
| log | `l30_execution_log` | `routine`, `status`, `detail`, `rows_affected` |

Rotinas standalone atuais (`03_plsql.sql`): `pr_log_execucao`, `fn_taxa_adesao`, `fn_resumo_usuario`,
`pr_registrar_conclusao`, `pr_verificar_inatividade`, `pr_gerar_relatorio_engajamento`.
Faixa de adesão usada na Fase 6: **50 %** (`c_limite_adesao`).

## Como a API fala com o Oracle hoje

- Segundo datasource Hikari em `OracleConfig` (`oracleDataSource` + `oracleJdbcTemplate`), ativo só com
  `level30.oracle.enabled=true` (`application.yml`, env `LEVEL30_ORACLE_ENABLED`, `ORACLE_URL/USER/PASSWORD`).
- Porta `EngajamentoGateway`; adapters `OracleEngajamentoGateway` (usa `SimpleJdbcCall` com
  `withoutProcedureColumnMetaDataAccess`) e `EngajamentoDesabilitadoGateway` (padrão; prod).
- **Sem Flyway no Oracle.** O Flyway da API só migra o PostgreSQL. Os scripts Oracle são aplicados na mão
  (SQL Developer / sqlplus). Nos testes, `OracleScriptParser` divide o script e roda via JDBC.
- Controller `AdminEngajamentoController` em `/admin/engajamento/**`, `ROLE_ADMIN`.
- Teste de integração existente: `OracleEngajamentoGatewayIT` (`@Tag("oracle")`, perfil Maven `oracle-it`),
  nunca foi executado (a nota na própria classe diz que não havia Docker).
- Actuator já está no pom; `application-prod.yml` expõe só `health`; `SecurityConfig` libera `/actuator/health`.

## CI/CD existente

- `.github/workflows/ci.yml` (jobs `backend`, `flutter`, `dashboard`) e `secret-scan.yml` (gitleaks).
- Não há `cd.yml`, nem script de deploy versionado (`deploy/ship.sh` é citado no `Dockerfile.runtime` mas não existe).
  O deploy atual é manual: build do jar no Mac, `scp`, `docker compose up -d --build` na VM.
- **Em produção o Oracle está desligado** (a VM roda só Postgres). O passo de migração Oracle do CD precisa ser opcional.

## Divergências do prompt e decisões

| # | Prompt supõe | Repositório | Decisão |
|---|---|---|---|
| 1 | `FN_TAXA_ADESAO(p_user_id, p_dias)` | `(p_user_id, p_inicio DATE, p_fim DATE)` com defaults (30 dias) | Mantida a assinatura real. A trigger chama `FN_TAXA_ADESAO(user_id)` (janela padrão de 30 dias). |
| 2 | `PR_REGISTRAR_CONCLUSAO(p_user_id, p_challenge_id)` | 11 parâmetros (usuário, desafio, dia, streak, XP…, OUT `p_alertas_gerados`) | Mantida a assinatura real (contrato com o Java). |
| 3 | `E_DESAFIO_INEXISTENTE` | A procedure faz *upsert* do desafio (MERGE); nunca existe "desafio inexistente" | Não criada: seria código morto. Criadas exceptions para os códigos que existem de fato (-20001/02/03/10/11/30/31). |
| 4 | Alertas com colunas de status/data a adicionar via `ALTER` | Já existem `resolved` (0/1) e `resolved_at` | Nenhum `ALTER`. "ABERTO/RESOLVIDO" = `resolved = 0/1`. |
| 5 | Alerta de adesão baixa dentro de `PR_REGISTRAR_CONCLUSAO` | Existe (passo 5 + `c_limite_adesao`) | Removido da procedure; passa à trigger composta. Alertas `INATIVIDADE` e `STREAK_REINICIADO` continuam na procedure (fora do escopo pedido). |
| 6 | Endpoints `/api/engajamento` e `/api/auditoria` | A API não usa prefixo `/api`; admin vive em `/admin/**` com `ROLE_ADMIN` | `GET /admin/engajamento` e `GET /admin/auditoria`, restritos a ADMIN (auditoria expõe dados de usuários). |
| 7 | "Atualize o `00_drop.sql`" para pacotes/triggers | `00_drop.sql` dropa só rotinas standalone | Atualizado (packages, triggers, `l30_audit_log`). |
| 8 | Flyway no Oracle, se já existir | Não existe | Usado `docker cp`/`sqlplus` no CI. No CD, SQLcl/sqlplus condicionado a `vars.ORACLE_DEPLOY_ENABLED`. |
| 9 | Testcontainers "pela API" | O gateway é a fronteira do Oracle; sem Oracle a API devolve 503 | Testes de integração exercitam `OracleEngajamentoGateway` (a mesma classe que a API usa) contra Oracle real. |
| 10 | `gvenzl/oracle-free:23-slim-faststart` | O IT atual usa `slim-faststart` (sem 23) | Alinhado a `23-slim-faststart`. |
| 11 | JaCoCo / Failsafe | Não configurados; os ITs rodam pelo Surefire com `-Poracle-it` | JaCoCo adicionado; mantido o perfil `oracle-it` existente. |
| 12 | Docker local | Docker Desktop estava parado nesta sessão | Ver o relatório final para o que foi ou não executado. |

Dependências entre scripts: `04_uso_pratico.sql` chama as rotinas pelo nome antigo; será atualizado para
`pkg_l30_engajamento.*` e deve rodar **depois** dos scripts novos (ordem em `db/oracle/README.md`).
