# Fase 6 — Auditoria (Fase 0)

> Levantamento somente leitura, feito em 2026-10-03, antes de qualquer alteração de código
> para a integração Oracle PL/SQL. Nenhum arquivo de produção foi tocado para gerar este
> relatório.

---

## Parte 1 — O que já existe desde a Fase 5

| Item | Estado | Onde |
|---|---|---|
| **Histórico de conclusões** (tabela/entidade por dia) | ✅ Existe | `backend/src/main/resources/db/migration/V2__challenge_completions.sql` (tabela) · `domain/model/ChallengeCompletion.java` (entidade) · `repository/ChallengeCompletionRepository.java` · exposto em `GET /challenges/{id}/historico` (`ChallengeService.historico`, linha 127) e `GET /me/atividade` (`ChallengeService.atividade`, linha 135) |
| **Rate limit no login** | ✅ Existe | `security/AuthRateLimiter.java` + `security/AuthRateLimitFilter.java` (rate limit por IP) · `service/LoginAttemptService.java` (lockout progressivo por conta: 5 falhas → bloqueio de 1/5/15/60 min, `ContaBloqueadaException` → 429 com `Retry-After`) |
| **Refresh token em cookie httpOnly** | ❌ Não existe | `AuthController.refresh`/`logout` recebem/devolvem o refresh token no **corpo JSON** (`RefreshRequest`, `LogoutRequest`, `AuthResponse`), não em cookie. Nenhuma ocorrência de `ResponseCookie`/`HttpOnly` no backend. O Flutter guarda o refresh token em `flutter_secure_storage`; o Angular, em `localStorage` via `auth.service.ts`. |
| **MFA do admin** | ❌ Não existe | Nenhuma ocorrência de `mfa`/`totp` no backend. Login de ADMIN é e-mail/senha como qualquer usuário, diferenciado só pela claim `role` no JWT. |
| **Design tokens unificados Flutter ↔ Angular** | ✅ Existe | `lib/core/constants/app_colors.dart` e `dashboard/src/styles.css` têm os **mesmos 12 valores hex** (`#080a17`, `#111328`, `#171a33`, `#232744`, `#00ff9c`, `#052e1e`, `#ffffff`, `#8a90b8`, `#22c55e`, `#eab308`, `#f97316`, `#ef4444`) e a mesma fonte (Poppins). `app_colors.dart` documenta isso no cabeçalho. |
| **Correções de layout P0 do Flutter** (tiles do mapa, status bar, FAB) | ✅ Tiles investigado e resolvido · ⚠️ status bar / FAB sem backlog formal encontrado | — |

**Tiles do mapa — investigado e resolvido (2026-10-03).** `git log -S "cartocdn"` / `-S "tile.openstreetmap"` em `lib/` apontam para um único commit, `39921b3` — *"design(flutter): mapa — troca tiles CartoDB (exigiam chave) por OpenStreetMap"*, mensagem: *"OSM padrão não precisa de chave. Dark map aplicado localmente com ColorFilter de inversão de luminância + atribuição OSM visível."* Conclusão: **não é regressão** — foi uma troca deliberada, e o look dark continua (confirmado: `map_screen.dart` ainda envolve o `TileLayer` em `ColorFiltered` com `ColorFilter.matrix` de inversão). `userAgentPackageName: 'com.level30.level30flutter'` já está declarado no `TileLayer`, conforme a política de uso de tiles do OSM. Única pendência era o `README.md` desatualizado ("Tiles dark CartoDB") — **corrigido** em `714ae51` (`docs(readme): corrige descrição dos tiles do mapa (OSM, não CartoDB)`). Nenhuma mudança em `map_screen.dart`.

**Status bar / FAB:** não encontrei onde esse backlog foi registrado (não está em `VISAO-GERAL.md`/`PROJECT.md`/`specs/`), então não dá pra confirmar "feito" contra um critério formal — ficam fora desta fase por não terem relação com a integração Oracle. O que o código mostra hoje, para referência futura:
- **Status bar:** nenhuma ocorrência de `SystemChrome`/`AnnotatedRegion` em `lib/` — sem tratamento explícito (usa o padrão do Material/SO).
- **FAB:** só há um `FloatingActionButton.extended` no projeto, em `home_screen.dart:368` ("Novo desafio"). Não encontrei sobreposição com outro FAB nem código morto de um FAB antigo.

### Escopo definido da Parte 1 (decisão do usuário, 2026-10-03)

Refresh token em cookie httpOnly e MFA do admin **não entram nesta fase** — ficam registrados
como próximas evoluções (ver seção ao final). As melhorias da Parte 1 desta entrega são:

1. Histórico de conclusões (já existente, ver tabela acima)
2. Rate limit com lockout progressivo (já existente, ver tabela acima)
3. Tokens de design unificados Flutter ↔ Angular (já existente, ver tabela acima)
4. Refatoração Ports & Adapters (`EngajamentoGateway` + adaptadores Oracle/desabilitado) — Fase 2
5. Eventos de domínio publicados após commit (`DesafioConcluidoEvent`, `@TransactionalEventListener(phase = AFTER_COMMIT)`) — Fase 2
6. Painel de engajamento no dashboard, alimentado pelas procedures/functions Oracle — Fase 4

---

## Parte 2 — Mapeamento para o evento Oracle

**Fluxo de conclusão do dia:**
`ChallengeController.complete` (`controller/ChallengeController.java:58-64`, `POST /challenges/{id}/complete`)
→ `ChallengeService.completeDay(UUID userId, UUID challengeId, String note)` (`service/ChallengeService.java:84-125`)
→ é **`@Transactional`** (linha 84, sem `readOnly`) — ponto certo para publicar o evento `AFTER_COMMIT`.

Dentro desse método, cada campo que a procedure `PR_REGISTRAR_CONCLUSAO` precisa já está disponível como variável local ou acessível por getter, **antes do `return` da linha 123**:

| Campo do evento | De onde sai | Expressão |
|---|---|---|
| `userId` | `User` carregado via `c.getUser()` | `user.getId()` |
| `userName` | `User.name` | `user.getName()` |
| `totalXp` (após) | `User.totalXp`, já incrementado na linha 112 | `user.getTotalXp()` |
| `challengeId` | `Challenge` | `c.getId()` |
| `title` | `Challenge.title` | `c.getTitle()` |
| data de início do desafio | `Challenge.createdAt` é `Instant` (linha 59 da entidade) — precisa converter, igual já se faz para `lastActivityAt` na linha 96 | `LocalDate.ofInstant(c.getCreatedAt(), ZONE)` |
| `dayNumber` (após) | variável local `nextDay` (linha 104), já setado em `c.setCurrentDay(nextDay)` | `nextDay` ou `c.getCurrentDay()` |
| `streak` (após) | setado na linha 106 | `c.getStreak()` |
| data da conclusão (America/Sao_Paulo) | variável local `hoje` (linha 93), já calculada com `ZONE = ZoneId.of("America/Sao_Paulo")` (linha 32) | `hoje` |
| `xpDelta` | variável local, já calculado (linha 109) | `xpDelta` |

Ou seja: **nenhum campo precisa de uma consulta extra** — dá para montar o `DesafioConcluidoEvent` com o que já existe no escopo do método, logo antes do `return`, e publicar via `ApplicationEventPublisher` injetado no `ChallengeService`.

Um detalhe que a Fase 2 do plano precisa decidir: a assinatura atual é `completeDay(userId, challengeId, note)` e não recebe `ApplicationEventPublisher` nem o gateway — é só injetar o publisher no construtor do `ChallengeService` (mesmo padrão dos outros colaboradores: `risk`, `achievements`, etc.).

---

## Parte 3 — Riscos

| Risco do enunciado | Situação hoje |
|---|---|
| `JdbcTemplate` autoconfigurado em uso em algum lugar | **Não há nenhum uso de `JdbcTemplate` no projeto.** Toda a persistência é via Spring Data JPA (`*Repository extends JpaRepository`). Ou seja, não existe conflito de bean hoje — mas também significa que declarar o primeiro `JdbcTemplate`/`DataSource` qualificado (Fase 2.2) é terreno novo, não uma migração de algo existente. |
| Beans de `DataSource` já declarados | **Nenhum.** Não há `@Bean DataSource` nem `DataSourceProperties` em `config/`. O datasource do Postgres/H2 é 100% autoconfigurado pelo Spring Boot a partir de `application.yml` (`spring.datasource.*`). Confirma o que o plano já assume: ao criar o primeiro bean `DataSource` manual (para o Oracle), é obrigatório declarar também o `DataSource` primário do Postgres explicitamente com `@Primary`, senão a autoconfiguração do datasource principal desliga e a aplicação não sobe. |
| `@EnableAsync`/`@EnableScheduling` | **`@EnableScheduling` já está ativo** em `Level30ApiApplication.java` (nível de aplicação). Dois jobs `@Scheduled` já rodam: `RefreshTokenCleanup.purge()` às 03:15 e `RiskMaterializationService` às 00:05 (`cron = "0 5 0 * * *"`). O cron proposto para `verificarInatividade` (`0 0 6 * * *`, 06:00) não colide com nenhum dos dois. **`@EnableAsync` não existe ainda** — precisa ser adicionado (Fase 2.5), junto com o `ThreadPoolTaskExecutor` `oracleExecutor`. |

**Riscos adicionais que encontrei e não estavam no enunciado:**

1. **`db/oracle/` ainda não existe no repositório** — ver bloqueio abaixo.
2. **Testcontainers não é dependência do projeto hoje** (`backend/pom.xml` não tem `org.testcontainers`) e **o `pom.xml` não tem nenhum `<profiles>`** declarado. O profile Maven `oracle-it` da Fase 3 e a dependência de Testcontainers são 100% novos, não uma extensão de algo que já existe.
3. **Nenhum teste de contexto hoje testa "feature desligada via property"** — o padrão `@TestPropertySource(properties = "level30.oracle.enabled=false")` da Fase 3 também é uma técnica nova neste código, mas não acho que seja um obstáculo, só um ponto de atenção.
4. Contagem de testes atual para referência de baseline: **11 arquivos de teste no backend**, **4 no Flutter**.

---

## Próximas evoluções (fora do escopo desta fase)

- Refresh token em cookie httpOnly (hoje vai no corpo JSON; ver Parte 1)
- MFA (TOTP) para contas ADMIN

---

## Bloqueio da Fase 0 — resolvido

`db/oracle/` foi adicionado à raiz do projeto em 2026-10-03 (6 scripts + `README.md`). Lidos
integralmente antes de qualquer código Java: as assinaturas de `pr_registrar_conclusao` (10 IN +
1 OUT, mesma ordem do plano), `pr_verificar_inatividade` e `pr_gerar_relatorio_engajamento` batem
exatamente com o que o adapter Java chama; os códigos de erro ficam todos em `-20001`..`-20099`
(`RAISE_APPLICATION_ERROR`); `pr_registrar_conclusao` é idempotente (`DUP_VAL_ON_INDEX` na
`UNIQUE (challenge_id, completed_on)` → ignora e retorna, sem lançar erro). Nenhum script foi
alterado (regra 6).

---

## Versão final (Fase 5 — Documentação)

### Melhorias da Parte 1 — valor agregado

| Melhoria | Já existia / Fase 6 | Valor agregado |
|---|---|---|
| Histórico de conclusões | Já existia (Fase 5, F1) | Base de dados que a Fase 6 passou a **replicar no Oracle** evento a evento — o histórico que já existia no Postgres ganhou uma segunda leitura (indicadores PL/SQL) sem duplicar lógica de negócio |
| Rate limit com lockout progressivo | Já existia (Bloco 1 de segurança) | Mantido intocado; mencionado aqui só porque fazia parte do escopo de auditoria pedido |
| Tokens de design unificados Flutter ↔ Angular | Já existia (Fase 5) | O painel novo (`/dashboards/oracle`) herda os tokens automaticamente — nenhuma cor nova foi inventada, reaproveita `--risk-low/medium/high/critical` e `--text-dim` para as 5 faixas de engajamento |
| **Refatoração Ports & Adapters** | Nova (Fase 6) | `EngajamentoGateway` isola o domínio do Oracle: trocar o Oracle por outra fonte de indicadores no futuro não toca `ChallengeService` nem o controller |
| **Eventos de domínio após commit** | Nova (Fase 6) | `DesafioConcluidoEvent` + `@TransactionalEventListener(AFTER_COMMIT)` — a conclusão do dia nunca espera o Oracle, e nunca falha por causa dele |
| **Painel de engajamento (dashboard)** | Nova (Fase 6) | Primeira tela do admin alimentada por PL/SQL — faixas de engajamento, alertas, verificação de inatividade sob demanda |

### Padrões aplicados

- **Ports & Adapters (Hexagonal):** `com.level30.api.gateway.EngajamentoGateway` é a porta; `OracleEngajamentoGateway` (ativo) e `EngajamentoDesabilitadoGateway` (padrão) são os dois adapters, selecionados por `@ConditionalOnProperty(level30.oracle.enabled)`. `ChallengeService` e `AdminEngajamentoController` dependem só da interface.
- **Eventos de domínio / outbox simplificado:** `DesafioConcluidoEvent` é publicado dentro da transação do Postgres mas só processado `AFTER_COMMIT` — o Postgres continua sendo a fonte de verdade (regra 4), o Oracle é alimentado depois, de forma assíncrona (`@Async("oracleExecutor")`) e com falha isolada (try/catch que só loga).
- **Idempotência ponta a ponta:** a `UNIQUE (challenge_id, completed_on)` do Oracle (regra do PL/SQL, não alterada) + o fato de o evento carregar o estado final (não um delta cego) tornam reentrega segura — reenviar a mesma conclusão não duplica nem corrompe o replay.
- **Tradução de erro por camada:** exceções técnicas do JDBC/Oracle (`SQLException`) nunca vazam para o controller — o gateway traduz para `RegraNegocioException` (422, erro de negócio do PL/SQL) ou `CamadaOracleIndisponivelException` (503, infraestrutura), ambas no mesmo contrato `ErroResponse` do resto da API.
- **Feature flag por configuração, não por código morto:** `level30.oracle.enabled` troca o bean inteiro (via Spring Conditional), não um `if` espalhado pelo código de produção.

### Arquivos alterados/criados por fase

| Fase | O quê |
|---|---|
| 1 | `db/oracle/*` (scripts, fornecidos pelo usuário) · `docker-compose.oracle.yml` · `backend/.env.example` · `db/oracle/README.md` (seção "Como rodar") |
| 2 | `backend/pom.xml` (ojdbc11) · `application.yml` (`level30.oracle.*`) · `config/{DataSourceConfig,OracleConfig,AsyncConfig,OracleInatividadeScheduler}.java` · `domain/event/DesafioConcluidoEvent.java` · `domain/engajamento/*.java` · `gateway/*.java` · `controller/AdminEngajamentoController.java` · `dto/{request/RelatorioEngajamentoRequest,response/InatividadeVerificacaoResponse}.java` · `exception/CamadaOracleIndisponivelException.java` (+ handler em `GlobalExceptionHandler`) · `service/{ChallengeService (evento), EngajamentoEventListener}.java` |
| 3 | `backend/pom.xml` (testcontainers, profile `oracle-it`) · `test/.../gateway/{OracleEngajamentoGatewayTest,EngajamentoGatewayContextTest,OracleEngajamentoGatewayIT}.java` · `test/.../service/EngajamentoEventListenerTest.java` |
| 4 | `dashboard/src/app/{app.routes.ts,app.component.ts}` · `core/models/engajamento-oracle.model.ts` · `core/services/engajamento-oracle.service.ts` · `features/dashboards/oracle-engajamento.component.ts` · `shared/pipes/rotulos.pipe.ts` (nova pipe) |
| 5 | este arquivo · `README.md` (seção "Camada Oracle") · `docs/DEMO_FASE6.md` |

### Correções pós-revisão (antes do push)

1. **Log enganoso com Oracle desligado.** `EngajamentoEventListener` logava "Conclusão replicada
   no Oracle ... alertas=0" mesmo sem nenhuma replicação real — o `EngajamentoDesabilitadoGateway`
   é um no-op silencioso, então o `info()` de sucesso não significava sucesso nenhum. Corrigido
   tornando o listener condicional: `@ConditionalOnProperty(level30.oracle.enabled=true)` — com a
   camada desligada, o bean **nem existe**, o evento é publicado e não tem ninguém ouvindo, e não
   há log nenhum. Verificado ao vivo (backend real, H2, Oracle desligado): completei um dia via
   HTTP e não apareceu nenhuma linha de replicação no log. `EngajamentoGatewayContextTest` ganhou
   um segundo teste confirmando que `context.getBean(EngajamentoEventListener.class)` lança
   `NoSuchBeanDefinitionException` nesse cenário.
2. **`OracleEngajamentoGatewayIT` não rodava `02_carga_simulada.sql`** e seu parser de script
   tinha um bug real: classificava blocos PL/SQL por palavra-chave (`DECLARE`/`BEGIN`/`CREATE OR
   REPLACE`), e esse heurístico **errava** justamente no único bloco `DECLARE` dos 3 scripts — o
   de `02_carga_simulada.sql`, que começa com linhas de comentário e `SET SERVEROUTPUT ON` antes
   do `DECLARE`. O heurístico não reconhecia o bloco como PL/SQL e tentaria fatiá-lo por `;`,
   quebrando a carga simulada inteira. Encontrado só agora porque a validação anterior (sem
   Docker) tinha checado `01_ddl.sql` e `03_plsql.sql`, mas não `02_carga_simulada.sql`. Corrigido
   com uma lógica posicional, sem inspecionar conteúdo: tudo antes do último delimitador `/` é um
   bloco PL/SQL inteiro (é exatamente o que esse delimitador significa no SQL*Plus); só o que
   sobra depois do último `/` é SQL simples, fatiado por `;`. `SET SERVEROUTPUT ON` é removido
   antes de tudo (diretiva do cliente SQL*Plus, inválida via JDBC). Revalidado (ainda sem Docker,
   com um script Python equivalente) contra os 3 arquivos: `01_ddl.sql` → 0 blocos PL/SQL + 27
   statements simples; `02_carga_simulada.sql` → 1 bloco PL/SQL + 1 statement simples;
   `03_plsql.sql` → 6 blocos PL/SQL + 1 statement simples. O `@BeforeAll` do IT agora roda
   `01_ddl.sql` → `02_carga_simulada.sql` → `03_plsql.sql`, nessa ordem.

### Pendência conhecida

`OracleEngajamentoGatewayIT` (Testcontainers) **não foi executado** nesta sessão — não havia
Docker disponível no ambiente onde a Fase 6 foi implementada. Rode `mvn verify -Poracle-it`
localmente (com Docker) antes de confiar nele em CI. Tudo o mais foi executado e verificado:
`mvn test` 61/61 (backend), `ng build` + `ng test` 22/22 (dashboard).

### Correção adicional — parser do script extraído e testado de verdade

A revisão anterior (seção acima) descrevia a regra do parser como "tudo antes do último `/` é
**um** bloco PL/SQL inteiro" — prosa ambígua que o código já não fazia (o loop já executava cada
bloco separadamente), mas que também nunca tinha sido verificada por um teste que realmente roda.
Toda a "validação" até aqui era um script Python externo, não um teste no `mvn test`.

Corrigido isso de vez:

- A lógica de divisão saiu do `OracleEngajamentoGatewayIT` para `OracleScriptParser`
  (`backend/src/test/.../gateway/OracleScriptParser.java`), uma classe só com essa
  responsabilidade, sem depender de Docker/Oracle para ser exercitada.
- `OracleScriptParserTest` (novo, **sem** `@Tag("oracle")` — roda no `mvn test` padrão) lê os 3
  arquivos reais de `db/oracle/` e confirma exatamente o que o enunciado pediu:
  - `01_ddl.sql` → 27 statements, nenhum PL/SQL (6 `CREATE TABLE`, 1 `CREATE SEQUENCE`)
  - `02_carga_simulada.sql` → 2 statements (1 bloco `DECLARE`…`END;` + 1 `SELECT`), nenhum
    começando com `SET` e nenhum com `SERVEROUTPUT` sobrando
  - `03_plsql.sql` → 7 statements: 6 blocos `CREATE OR REPLACE`, cada um terminando exatamente em
    `END <nome_da_rotina>;` (`pr_log_execucao`, `fn_taxa_adesao`, `fn_resumo_usuario`,
    `pr_registrar_conclusao`, `pr_verificar_inatividade`, `pr_gerar_relatorio_engajamento`, nessa
    ordem) + 1 `SELECT` final
- Diretivas SQL*Plus descartadas por palavra-chave explícita (`SET SERVEROUTPUT`, `SET ECHO`,
  `SET FEEDBACK`, ... `SPOOL`, `PROMPT`) — **não** um `^SET\b` genérico, porque os scripts têm
  `UPDATE ... SET coluna = valor` de verdade (`pr_registrar_conclusao`, linha ~272; a carga
  simulada, linha ~160) que um regex genérico apagaria.
- `OracleEngajamentoGatewayIT` agora só chama `OracleScriptParser.dividirEmStatements(...)` e
  executa o resultado — não tem mais lógica de parsing própria.

`mvn test`: **61/61** (58 anteriores + 3 do `OracleScriptParserTest`), confirmado rodando de
verdade. O `OracleEngajamentoGatewayIT` continua sem executar nesta sessão (sem Docker), mas
agora a parte que mais importava validar — o parser — tem cobertura automatizada real, não só
uma checagem manual externa ao projeto.
