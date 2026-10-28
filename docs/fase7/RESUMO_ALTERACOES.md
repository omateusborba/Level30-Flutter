# Fase 7 — Resumo das alterações no código

Merge: PR #4 (`e8572af`). Visão geral do que mudou no repositório; os detalhes técnicos de cada objeto estão em
[`OBJETOS_PLSQL.md`](OBJETOS_PLSQL.md) e [`PIPELINE.md`](PIPELINE.md), e as divergências do plano original em
[`00_DESCOBERTA.md`](00_DESCOBERTA.md).

## 1. Banco Oracle (`db/oracle/`)

| Script | O que faz |
|---|---|
| `06_pkg_engajamento.sql` | `PKG_L30_ENGAJAMENTO`: move para o package `FN_TAXA_ADESAO`, `FN_RESUMO_USUARIO`, `PR_REGISTRAR_CONCLUSAO` e `PR_GERAR_RELATORIO_ENGAJAMENTO`. Assinaturas mantidas. Declara a meta `C_LIMITE_ADESAO` (50) e exceptions nomeadas (-20001/02/03/10/11/30/31). Validação repetida virou função privada (`FN_USUARIO_EXISTE`). O alerta de adesão baixa saiu da procedure. |
| `07_trg_audit_conclusao.sql` | Cria `L30_AUDIT_LOG` e a trigger `TRG_L30_AUDIT_CONCLUSAO` (insert/update/delete em `L30_COMPLETIONS`, valores antigos e novos em JSON, usuário de banco). |
| `08_trg_status_alerta.sql` | `TRG_L30_STATUS_ALERTA`, compound trigger: acumula os usuários afetados por linha e, no fim do comando, abre, mantém ou fecha o alerta `ADESAO_BAIXA`. Evita ORA-04091. |
| `09_pkg_consultas.sql` | `PKG_L30_CONSULTAS.FN_ENGAJAMENTO_FILTRADO`: Dynamic SQL com binds fixos para valores e whitelist (`CASE` + `DBMS_ASSERT`) para ordenação; erro ORA-20050 para valor fora da lista. |
| `10_consolidacao.sql` | Remove as rotinas standalone antigas, só se os packages e triggers estiverem válidos. |
| `99_smoke_test.sql` | Recompila tudo, exige `USER_ERRORS` vazio e testa auditoria, alerta aberto/fechado, filtros e tentativas de injeção. Sai com erro se algo falhar. |

Também alterados: `00_drop.sql` (remove packages, triggers e `L30_AUDIT_LOG`; passou a ignorar ORA-04080),
`04_uso_pratico.sql` (chama `pkg_l30_engajamento.*`) e `README.md` (nova ordem de execução e DER).

## 2. API (`backend/`)

- `OracleEngajamentoGateway` chama os packages (`withCatalogName`) e ganhou `consultarEngajamento` (function com
  `REF CURSOR`) e `listarAuditoria`. A interface `EngajamentoGateway` e o adapter desabilitado acompanham.
- Novos endpoints, só para ADMIN: `GET /admin/engajamento?inicio=&fim=&nivelMin=&adesaoMin=&ordenarPor=&direcao=` e
  `GET /admin/auditoria?limite=` (1 a 500). Os endpoints anteriores continuam iguais.
- Enums `OrdenacaoEngajamento` e `DirecaoOrdenacao` validam a ordenação no Java (400 se inválida), além da
  whitelist no PL/SQL. Records novos: `FiltroEngajamento`, `EngajamentoFiltrado`, `RegistroAuditoria`.
- `GlobalExceptionHandler`: tipo inválido em parâmetro de query (por exemplo data) responde 400 em vez de 500.
- **Correção:** a tradução de erros `ORA-20xxx` para HTTP 422 não funcionava de fato, porque o driver Oracle
  aninha o erro em um tipo que não é `SQLException`. Agora a cadeia de causas é percorrida.
- `pom.xml`: JaCoCo para cobertura.
- Contrato JSON existente, `Challenge.fromJson`, `UserProfile.fromJson` e o `RiskEngine` não foram alterados.

## 3. Testes

- `EngajamentoFiltradoValidacaoTest` (novo, sem Docker): enums e validações do controller.
- `OracleEngajamentoGatewayIT` (Testcontainers, imagem `gvenzl/oracle-free:23-slim-faststart`, perfil
  `-Poracle-it`): agora aplica os scripts 06 a 10 e cobre auditoria, alerta abrindo e fechando, consulta filtrada,
  injeção e enums. Se `ORACLE_IT_URL` estiver definido, usa esse banco em vez de subir um container (usado no CI).
- `engajamento-oracle.service.spec.ts` (novo) no dashboard.

## 4. Dashboard (`dashboard/`)

Na tela "Engajamento — camada Oracle": formulário de filtros (período, nível mínimo, adesão mínima, ordenar por,
direção) com tabela de resultado, e tabela de auditoria das conclusões. Modelos e service novos em
`engajamento-oracle.*`.

## 5. App Flutter (`lib/`, `test/`)

Correção dos 33 avisos do `flutter analyze` com `dart fix` (`const` e chaves em `if`), em 9 arquivos de telas e
widgets e em `test/risk_engine_test.dart`. Nenhuma mudança de comportamento; `RiskEngine` intocado.

## 6. CI/CD (`.github/`)

- `ci.yml`: jobs `api`, `app` e `dashboard` em paralelo. O `api` roda `mvn verify`, aplica os scripts Oracle e o
  smoke test num service container, depois os testes de integração. Publica relatórios Surefire e JaCoCo, logs e
  um resumo em `$GITHUB_STEP_SUMMARY`.
- `cd.yml`: dispara após o CI verde na `main` (ou manualmente), exige o Environment `production` com aprovação,
  builda o jar, migra o Oracle se `ORACLE_DEPLOY_ENABLED=true`, faz deploy por SSH, roda smoke test em
  `/actuator/health` e restaura o jar anterior se falhar. **Ainda não foi executado.**
- `scripts/summary-api.py`: gera o resumo de testes e cobertura.

## 7. Documentação

`docs/fase7/` (`00_DESCOBERTA`, `OBJETOS_PLSQL`, `PIPELINE` e este arquivo) e o `README.md` raiz, com badge do CI
e a seção "Fase 7".

## Verificado e não verificado

- Verificado: smoke test SQL, 65 testes unitários, 8 de integração com Oracle, 25 testes do dashboard,
  `flutter analyze` e `flutter test`, `actionlint`, CI verde e chamadas HTTP reais aos endpoints com Oracle ligado.
- Não verificado: o CD (precisa da VM e dos secrets) e o visual das telas novas no navegador.
