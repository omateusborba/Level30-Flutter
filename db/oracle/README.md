# Level30 · Smart HAS — Camada Oracle PL/SQL (Fase 6)

## Decisão arquitetural

O PostgreSQL continua sendo o banco transacional do Spring Boot. O Oracle entra como **camada de inteligência**: recebe uma réplica de usuários e desafios junto com cada evento de conclusão, e concentra indicadores, alertas e relatórios em PL/SQL.

```
App Flutter ──► Spring Boot ──► PostgreSQL        (estado operacional)
Dashboard   ──►     │
                    └─ JDBC ──► Oracle PL/SQL     (indicadores, alertas, relatórios)
```

A réplica é alimentada por evento (`pr_registrar_conclusao`), sem ETL separado. A procedure é idempotente, então reenviar o mesmo evento não duplica dados. Consistência entre os dois bancos é eventual; o Outbox Pattern fica registrado como evolução.

## Ordem de execução

| # | Script | Conteúdo |
|---|---|---|
| 0 | `00_drop.sql` | Limpeza (só objetos do projeto) |
| 1 | `01_ddl.sql` | Tabelas, constraints, índices e comentários |
| 2 | `02_carga_simulada.sql` | 13 usuários, desafios e ~75 dias de histórico |
| 3 | `03_plsql.sql` | Functions e procedures (Fase 6) |
| 4 | `06_pkg_engajamento.sql` | **Fase 7** — `PKG_L30_ENGAJAMENTO` (spec + body) |
| 5 | `07_trg_audit_conclusao.sql` | **Fase 7** — `L30_AUDIT_LOG` + trigger de auditoria |
| 6 | `08_trg_status_alerta.sql` | **Fase 7** — compound trigger do alerta de adesão |
| 7 | `09_pkg_consultas.sql` | **Fase 7** — `PKG_L30_CONSULTAS` (Dynamic SQL seguro) |
| 8 | `10_consolidacao.sql` | **Fase 7** — remove as rotinas standalone que agora vivem no package |
| 9 | `04_uso_pratico.sql` | Consultas e execuções para os prints (usa `pkg_l30_engajamento.*`; rode **depois** do 10) |
| 10 | `05_job_opcional.sql` | Agendamento diário (requer `CREATE JOB`) |
| — | `97_demo_auditoria.sql` | **Demo** — gera 1 UPDATE e 1 DELETE em `L30_COMPLETIONS` para a auditoria (só local/demo) |
| — | `98_limpa_residuo_testes.sql` | **Demo** — remove alunos de teste (`ZZ_TESTE_*`, "Aluno Teste") e seus rastros (só local/demo) |
| — | `99_smoke_test.sql` | **Fase 7** — recompila 06..10, confere `USER_ERRORS`, testa auditoria, alerta e injeção; sai com erro se algo falhar |

> Para a **demo**, use `scripts/demo-reset.sh` (substitui a `02_carga_simulada.sql`: mesmas pessoas e IDs do PostgreSQL).
>
> A numeração dos arquivos é histórica; a **ordem de execução** é a da primeira coluna. Detalhes dos objetos
> da Fase 7 em [`docs/fase7/OBJETOS_PLSQL.md`](../../docs/fase7/OBJETOS_PLSQL.md).

No SQL Developer, rode cada arquivo como script (F5). Compatível com Oracle 19c ou superior.

## Como rodar

### Local (Docker, para dev/teste da integração Java)

Na raiz do projeto, com Docker instalado:

```bash
# 1. Suba o Oracle (demora ~1-2 min na primeira vez)
ORACLE_SYS_PASSWORD=senhaSys123 ORACLE_USER=level30 ORACLE_PASSWORD=senhaApp123 \
  docker compose -f docker-compose.oracle.yml up -d

# 2. Acompanhe até o healthcheck ficar "healthy"
docker compose -f docker-compose.oracle.yml ps

# 3. Rode os scripts, nesta ordem, como o usuário da aplicação (não como SYSTEM)
for f in 00_drop 01_ddl 02_carga_simulada 03_plsql \
         06_pkg_engajamento 07_trg_audit_conclusao 08_trg_status_alerta 09_pkg_consultas 10_consolidacao \
         04_uso_pratico; do
  docker exec -i level30-oracle sqlplus -S level30/senhaApp123@//localhost/FREEPDB1 @/scripts/$f.sql
done

# 99_smoke_test.sql valida tudo (rode com `-w /scripts`); 05_job_opcional.sql exige o privilégio CREATE JOB — rode à parte e ignore
# ORA-27486 se o usuário não tiver o privilégio (comum em ambiente acadêmico):
docker exec -i level30-oracle sqlplus -S level30/senhaApp123@//localhost/FREEPDB1 @/scripts/05_job_opcional.sql
```

Troque `senhaApp123`/`senhaSys123` pelos valores reais do seu `.env` (ver `backend/.env.example`).
O comando genérico, usando as variáveis de ambiente diretamente:

```bash
docker exec -i level30-oracle sqlplus -S "$ORACLE_USER/$ORACLE_PASSWORD@//localhost/FREEPDB1" @/scripts/01_ddl.sql
```

### Oracle da FIAP (SQL Developer)

1. Conecte com as credenciais do RM fornecidas pela FIAP.
2. Abra cada arquivo de `db/oracle/` na ordem da tabela acima.
3. Rode como **script** (F5, não "executar statement" com F9) — os blocos `DECLARE`/`BEGIN...END` e
   o `/` de fim de bloco dependem disso.
4. `05_job_opcional.sql` provavelmente falha com `ORA-27486` (usuário RM não tem `CREATE JOB`) —
   é esperado e documentado; a rotina `pr_verificar_inatividade` continua acionável pelo backend
   (`@Scheduled`, ver `LEVEL30_ORACLE_INATIVIDADE_JOB`).

## DER

```mermaid
erDiagram
    L30_USERS ||--o{ L30_CHALLENGES : possui
    L30_USERS ||--o{ L30_COMPLETIONS : registra
    L30_CHALLENGES ||--o{ L30_COMPLETIONS : recebe
    L30_USERS ||--o{ L30_ALERTS : recebe
    L30_CHALLENGES |o--o{ L30_ALERTS : origina
    L30_USERS ||--o{ L30_ENGAGEMENT_REPORTS : consta
    L30_COMPLETIONS }o..o{ L30_AUDIT_LOG : "auditada por trigger (Fase 7, sem FK)"

    L30_USERS {
        VARCHAR2 id PK
        VARCHAR2 name
        VARCHAR2 email UK
        VARCHAR2 role
        NUMBER total_xp
        TIMESTAMP created_at
        TIMESTAMP synced_at
    }
    L30_CHALLENGES {
        VARCHAR2 id PK
        VARCHAR2 user_id FK
        VARCHAR2 title
        DATE start_date
        NUMBER current_day
        NUMBER streak
        VARCHAR2 status
        DATE ended_on
        TIMESTAMP last_activity_at
    }
    L30_COMPLETIONS {
        NUMBER id PK
        VARCHAR2 challenge_id FK
        VARCHAR2 user_id FK
        NUMBER day_number
        DATE completed_on
        NUMBER xp_delta
        VARCHAR2 note
    }
    L30_ALERTS {
        NUMBER id PK
        VARCHAR2 user_id FK
        VARCHAR2 challenge_id FK
        VARCHAR2 alert_type
        VARCHAR2 severity
        VARCHAR2 message
        NUMBER measured_value
        NUMBER resolved
    }
    L30_ENGAGEMENT_REPORTS {
        NUMBER id PK
        NUMBER execution_id
        VARCHAR2 user_id FK
        DATE period_start
        DATE period_end
        NUMBER active_challenges
        NUMBER completions
        NUMBER adherence_rate
        NUMBER current_streak
        VARCHAR2 engagement_band
    }
    L30_EXECUTION_LOG {
        NUMBER id PK
        VARCHAR2 routine
        VARCHAR2 status
        VARCHAR2 detail
        NUMBER rows_affected
    }
    L30_AUDIT_LOG {
        NUMBER id PK
        VARCHAR2 tabela
        VARCHAR2 operacao
        VARCHAR2 registro_id
        CLOB dados_antigos
        CLOB dados_novos
        VARCHAR2 usuario_banco
        TIMESTAMP criado_em
    }
```

## Mapa de requisitos da atividade

| Requisito do enunciado | Onde está atendido |
|---|---|
| Modelo lógico/físico Oracle | `01_ddl.sql` + DER acima |
| Implantar tabelas | `01_ddl.sql` |
| Importar dados simulados | `02_carga_simulada.sql` (perfis de comportamento) |
| Function de indicador | `fn_taxa_adesao` |
| Function de dados formatados | `fn_resumo_usuario` |
| IN, RETURN, exceções, comentários | Ambas as functions (códigos -20001 a -20003, -20099) |
| Functions integradas a consultas | `04_uso_pratico.sql`, consultas 1 a 5 |
| Procedure de alertas | `pr_verificar_inatividade` |
| Procedure de relatório resumido | `pr_gerar_relatorio_engajamento` |
| Procedure acionada pelo backend Java | `pr_registrar_conclusao` (REST → Spring → JDBC → Oracle) |
| EXCEPTION, IF, LOOP, CURSOR | Cursor FOR com parâmetro, cursor explícito OPEN/FETCH/CLOSE, WHILE LOOP na carga, IF/ELSIF nas faixas, SAVEPOINT e transação autônoma |

## Credenciais

Usuário e senha do Oracle nunca vão para o repositório. O backend lê de variáveis de ambiente (`ORACLE_URL`, `ORACLE_USER`, `ORACLE_PASSWORD`).
