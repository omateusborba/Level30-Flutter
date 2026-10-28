# Fase 7 — Correções antes da gravação

Diagnóstico (causa raiz) primeiro, correção depois, item a item. Branch `fase7-correcoes`.

## Item 1 — Dois bancos com populações diferentes

**Como os dados chegam ao Oracle hoje**

- Existe *dual-write* para conclusões reais: `ChallengeService.completeDay` publica `DesafioConcluidoEvent` e o
  `EngajamentoEventListener` (AFTER_COMMIT, assíncrono) chama `PR_REGISTRAR_CONCLUSAO`. Os IDs (UUID) são os mesmos
  nos dois bancos, porque o evento leva `userId`/`challengeId` do PostgreSQL.
- **Esse caminho nunca roda para dados de seed.** O `DataSeeder` grava direto no PostgreSQL (sem evento), e a base
  Oracle da demo vinha de `02_carga_simulada.sql`, que gera 13 alunos com UUIDs aleatórios e nomes próprios
  (Carla *Mendes*, Diego Rocha...). São duas populações sem relação.

**Causa raiz:** não existia um seed único; cada banco tinha o seu, com pessoas, IDs e históricos diferentes.
O `DataSeeder` também criava desafios com `currentDay` preenchido e **nenhuma** conclusão, então o painel de
Engajamento (que lê `challenge_completions`) ficava zerado enquanto a auditoria Oracle mostrava conclusões de hoje
(vindas dos testes de integração).

## Item 2 — Risco do dashboard diverge do app

- O app calcula o risco **no aparelho** com o `RiskEngine` Dart. O dashboard lê `challenges.risk_score/risk_level`,
  materializados pelo back-end (`RiskMaterializationService`), e `risk_snapshots`.
- O back-end já materializa em `create`, em `completeDay` e no job diário (00:05). O que falhava era o **seed**:
  `DataSeeder` não tem `@Order`, então roda por último, **depois** do `CompletionBackfill` (20) e do `RiskBackfill`
  (30), que viam o banco vazio e não faziam nada. Os desafios seedados ficaram com o default da coluna
  (`risk_score = 0`, `LOW`, `risk_updated_at = null`), e o snapshot do dia, com todos em `low`.
- Reproduzido em banco limpo: `/admin/desafios` devolve `riskScore 0.0 / low` para os 6 desafios, enquanto o
  `RiskEngine` Java dá 0,88 (crítico) para a "Corrida matinal". Os inputs do Java e do Dart são idênticos.

**Causa raiz:** dado seedado sem passar pelo caminho que materializa o risco (e backfills executados antes do seed).
Não há divergência de fórmula.

## Item 3 — XP, nível e conquistas

- Testei o fluxo real (cadastro, criar desafio, concluir dia): `xpDelta 10`, `totalXp 10`, conquista
  `primeiro_passo` desbloqueada. **O código de crédito funciona.**
- O seed criava usuários com `totalXp = 0`, desafios com `currentDay` avançado e nenhuma linha em
  `challenge_completions`/`user_achievements`. O "30 XP ganho" do detalhe é `Challenge.earnedXp` (calculado do
  progresso), não do saldo do usuário. O Oracle mostrava 620 XP porque a carga da Fase 6 calcula XP por outra regra.

**Causa raiz:** seed que injeta estado final sem creditar XP/conquistas; e duas fontes de XP (PostgreSQL e a
fórmula própria da carga Oracle). A fonte de verdade passa a ser o PostgreSQL: `users.total_xp` = soma de
`challenge_completions.xp_delta`, e o Oracle recebe esse valor no evento (`p_total_xp`), sem recalcular.

## Item 4 — Resíduo de testes no Oracle

**Causa raiz:** `OracleEngajamentoGatewayIT` grava usuários "Aluno Teste"/"Aluno Fase7" com `registrarConclusao`
(que faz commit via o gateway) e nunca remove. O `99_smoke_test.sql` já limpava os seus dados, mas rodou no mesmo
banco da demo.

## Item 5 — Detalhes

| # | Causa raiz |
|---|---|
| 5.1 | A ser confirmada no componente (barras só com trilho). |
| 5.2 | A ser confirmada no CSS do login (cor do texto/estado do botão). |
| 5.3 | A lista da Home não reserva espaço para o FAB. |
| 5.4 | A coluna DADOS imprime o JSON inteiro em uma linha. |
| 5.5 | `AiGatewayService.fallbackMessage` e `SuggestedAction.SUGGEST_REPLAN` (back-end) escrevem "Recomecar e vencer"; o app e o Worker usam o texto acentuado. |
| 5.6 | `app.ai.worker-url` vazio (`AI_WORKER_URL` não definida): `gatewayConfigured()` é falso e a recomendação cai no fallback **sem nenhum log**. |

(As linhas 5.1 e 5.2 são completadas abaixo quando os componentes forem inspecionados.)
