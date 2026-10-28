# Evidências da Fase 7

Gerado em 2026-10-28 com Oracle Free 23 (Docker), API Spring Boot com a camada Oracle ligada e o dashboard Angular
em modo de desenvolvimento, logado como admin. Os dados de "Aluno Teste" e "Aluno Fase7" vêm dos testes de integração.

## Testes (`testes/`)

| Arquivo | Resultado |
|---|---|
| `api-unitarios.log` | 65 testes, 0 falhas |
| `api-integracao-oracle.log` | 8 testes de integração com Oracle, 0 falhas |
| `oracle-aplicacao-scripts.log` | scripts 00 a 10 aplicados sem erro ORA/PLS |
| `oracle-smoke-test.log` | 18 checagens OK, `USER_ERRORS` vazio, injeção barrada com ORA-20050 |
| `dashboard-karma.log` | 25 testes, todos passaram |
| `flutter-analyze.log` / `flutter-test.log` | sem avisos / 17 testes passaram |
| `actionlint.log` | workflows sem problemas |

## Telas do dashboard (`telas/`)

| Arquivo | Tela |
|---|---|
| `01-login.png` | Login |
| `02-home.png` | Visão geral |
| `03-dashboard-engajamento.png` | Engajamento (métricas do Postgres) |
| `04-dashboard-risco.png` | Risco |
| `05-dashboard-gamificacao.png` | Gamificação |
| `06-admin.png` | Administração |
| `07-oracle-completa.png`, `07a-oracle-topo.png` | Engajamento, camada Oracle (página inteira e topo) |
| `08-oracle-filtros-aplicados.png` | Consulta filtrada: nível ≥ 2, adesão ≥ 50, ordenada por nome ASC |
| `09-oracle-auditoria.png` | Tabela de auditoria de conclusões (`L30_AUDIT_LOG`) |

## Telas do app (`telas-mobile/`)

Capturas do app Flutter em viewport de celular (390×844, 2x), usuária de demonstração. Detalhes de como foram geradas
e a lista das 7 telas em [`telas-mobile/README.md`](telas-mobile/README.md).
