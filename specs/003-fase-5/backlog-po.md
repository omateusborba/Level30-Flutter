# Level30 / Smart HAS — Backlog de Produto · Fase 5

> **Papel:** Product Owner. Este documento é o *backlog priorizado e refinado* — decide **o quê** e **em que ordem**, não **como**.
> **Base:** spec de implementação da Fase 5 + [`PROJECT.md`](../../PROJECT.md).
> **Contexto:** atividade FIAP "Mobile Hybrid App e a Sociedade 5.0".
> **Data:** 2026-08-29.

---

## 1. Visão de produto

> Level30 transforma a construção de hábitos acadêmicos num jogo de RPG. Na Fase 5, ele deixa de
> ser "um app com um backend" e passa a ser **um produto com um núcleo de domínio único** (API
> Spring Boot) servindo dois clientes — o app do estudante (Flutter) e o painel de quem acompanha
> o programa (Angular) — sem que o contrato entre eles se quebre.

**Problema que a fase resolve:** hoje a regra de negócio (risco, XP, streak) está espalhada e
duplicada, o backend não é auditável no padrão exigido, e não há visão agregada para coordenação
do programa. O aluno também perde a sessão sem aviso e fica com tela vazia quando cai a rede.

**O que NÃO é problema desta fase:** a proposta de valor do app já está validada (Fases 1–4).
Não estamos testando *se* gamificação funciona — estamos amadurecendo a base.

---

## 2. OKRs da Fase 5

### Objective A — Entregar um produto coeso, evoluído e auditável (não uma reescrita)

| KR | Baseline | Meta |
|---|---|---|
| A1 · Endpoints do contrato atual respondendo do Spring Boot **sem** alterar `Challenge.fromJson` / `UserProfile.fromJson` | 0/12 | 12/12 |
| A2 · Paridade do motor de risco: mesma suíte de casos verde em Dart, TS e Java | 2/3 impl. | 3/3 impl. |
| A3 · Correções de regra de negócio da seção 2.5 da spec, cobertas por teste | 0/5 | 5/5 |
| A4 · Checklist de recursos Angular (seção 3.3) presentes e rastreáveis no código | 0/9 | 9/9 |
| A5 · Capacidades novas do app: abre offline com cache + sessão sobrevive à expiração do access token | 0/2 | 2/2 |

### Objective B — Maximizar a nota da atividade acadêmica

| KR | Meta |
|---|---|
| B1 · Todos os 7 entregáveis (seção 7 da spec) prontos | ≥ 48 h antes do prazo |
| B2 · Swagger navegável com Bearer + `mvn test` verde + `flutter test`/`flutter analyze` limpos | 100% |
| B3 · Vídeo demo no YouTube (não listado) | ≤ 5 min, app rodando |
| B4 · Slides (≤ 10) com nome, RM e foto de cada integrante | link do vídeo no doc **e** nos slides |

---

## 3. Impact map (resumido)

```
Goal: API única, contrato congelado, evolução técnica demonstrável (Fase 5)
│
├── Estudante (usa o app)
│   ├── Impacto: não é interrompido por rede instável nem por sessão expirada
│   └── Entregas: E3 (cache offline, refresh token, tratamento de 409)
│
├── Coordenador do programa (novo ator — usa o dashboard)
│   ├── Impacto: enxerga adesão, risco de abandono e progresso de forma agregada
│   └── Entregas: E2 (dashboard) + endpoints /admin/** em E1
│
├── Avaliador FIAP / Leroy Merlin
│   ├── Impacto: consegue auditar arquitetura, regras e stack no padrão exigido
│   └── Entregas: E1 (Spring Boot em camadas + Swagger) + E4 (doc, slides, vídeo)
│
└── Time de desenvolvimento (você)
    ├── Impacto: regra de negócio deixa de ser copiada à mão em 3 lugares sem rede de segurança
    └── Entregas: E1 (RiskEngine.java + testes portados) + E3 (camada de repositório testável)
```

---

## 4. Épicos

| ID | Épico | Objetivo | Depende de |
|---|---|---|---|
| **E1** | API Spring Boot (núcleo de domínio) | Fonte única de verdade: auth, users, challenges, risco, gateway de IA, endpoints admin | — |
| **E2** | Dashboard Angular | Visão agregada do programa para o coordenador; cumpre o checklist de avaliação | E1 (`/admin/**`, auth) |
| **E3** | Maturidade do app Flutter | Camadas testáveis, resiliência offline, sessão contínua, sincronia com as novas regras | E1 (contrato + `409` + refresh) |
| **E4** | Entregáveis acadêmicos | PDF de documentação, slides, vídeo, repositório liberado | E1–E3 funcionais para a demo |

---

## 5. Backlog priorizado

Prioridade = **MoSCoW** (para a release da Fase 5) + **Valor × Esforço**.
`M` Must · `S` Should · `C` Could · `W` Won't (this time). Esforço em P/M/G.

### Onda 1 — Fundação do backend

| ID | Story | Épico | MoSCoW | Valor | Esforço |
|---|---|---|---|---|---|
| US-001 | Scaffold Spring Boot + PostgreSQL + Flyway + entidades/repositories | E1 | M | Alto | M |
| US-002 | `RiskEngine.java` com a suíte de testes portada do Dart | E1 | M | Alto | P |
| US-003 | Autenticação: signup/login, BCrypt, JWT HS256, roles | E1 | M | Alto | M |
| US-005 | CRUD de desafios com validação e *ownership* (404, não 403) | E1 | M | Alto | M |
| US-014 | CORS restrito à origem do Angular + `JWT_SECRET` por env | E1 | M | Médio | P |

### Onda 2 — Regras de negócio, IA e admin

| ID | Story | Épico | MoSCoW | Valor | Esforço |
|---|---|---|---|---|---|
| US-006 | Completar dia: rejeitar segundo `complete` no mesmo dia com `409` (fuso `America/Sao_Paulo`) | E1 | M | Alto | P |
| US-007 | Completar dia: reset de streak após ≥ 2 dias de inatividade | E1 | M | Alto | P |
| US-008 | Completar dia: `xpDelta` + `total_xp` numa única transação, com divisão inteira | E1 | M | Alto | P |
| US-004 | Refresh token (access 1 h / refresh 30 d) + `POST /auth/refresh` | E1 | M | Alto | M |
| US-009 | `AiGatewayService` → Worker: recomendação com **fallback** local | E1 | M | Médio | M |
| US-010 | `AiGatewayService` → Worker: chat com `systemPrompt` montado no Spring | E1 | S | Médio | M |
| US-015 | Proteger o Worker com `X-Service-Token` compartilhado | E1 | S | Médio | P |
| US-011 | Endpoints `/admin/usuarios`, `/admin/desafios`, `/admin/indicadores` | E1 | M | Alto | M |

### Onda 3 — Web, mobile e entrega

| ID | Story | Épico | MoSCoW | Valor | Esforço |
|---|---|---|---|---|---|
| US-012 | Swagger em `/swagger-ui.html` com `@Tag`/`@Operation` + Bearer | E1 | M | Alto | P |
| US-013 | `GlobalExceptionHandler` com contrato de erro único | E1 | M | Médio | P |
| US-016 | Seed de dados de demonstração (usuários, desafios, cenários de risco) | E1 | M | Alto | P |
| US-020 | Angular: scaffold, `authInterceptor`, `adminGuard`, services HTTP | E2 | M | Alto | M |
| US-021 | Tela `/login` (e-mail/senha com `[(ngModel)]`) | E2 | M | Médio | P |
| US-022 | Tela `/home`: KPIs + distribuição por categoria e por risco | E2 | M | Alto | M |
| US-023 | Tela `/admin`: tabela de desafios com `*ngFor` + filtros | E2 | M | Alto | M |
| US-024 | Formulário funcional de criação de desafio (`[(ngModel)]` em todos os campos) | E2 | M | Alto | P |
| US-025 | Exclusão de desafio com confirmação | E2 | S | Médio | P |
| US-026 | Tabela de usuários (XP, nível, nº de desafios) | E2 | S | Médio | P |
| US-027 | Identidade visual compartilhada com o app (paleta + Poppins) | E2 | S | Baixo | P |
| US-028 | Rastreabilidade do checklist de avaliação Angular (seção 3.3) | E2 | M | Alto | P |
| US-030 | Camada de repositório no Flutter (`ChallengeRepository`, `UserRepository`) | E3 | S | Alto | M |
| US-031 | Nenhuma tela chama `ApiClient` direto (mover `_RecommendationCard`) | E3 | S | Médio | P |
| US-032 | Cache offline de desafios + `isStale` + banner "dados salvos localmente" | E3 | S | Alto | M |
| US-033 | Refresh token no cliente: `401` → tenta refresh 1×, repete a requisição | E3 | M | Alto | M |
| US-034 | Tratar `409` em `completeDay` + UI tolerante a streak que diminui | E3 | M | Médio | P |
| US-035 | Extrair `AppBottomNav` + `Challenge.toJson()` | E3 | C | Baixo | P |
| US-036 | `app_config.dart` → API Spring Boot + ampliar testes (fronteiras + provider) | E3 | M | Médio | P |
| US-040 | Documentação **PDF**: justificativa da stack, roadmap tecnológico, backend, dashboard | E4 | M | Alto | M |
| US-041 | Slides **PDF** (≤ 10) com nome/RM/foto de cada integrante | E4 | M | Alto | P |
| US-042 | Vídeo YouTube não listado (≤ 5 min) com o app rodando | E4 | M | Alto | P |
| US-043 | Repositório GitHub com acesso liberado + READMEs atualizados | E4 | M | Médio | P |

### Won't have (this time) — explicitamente fora de escopo

- Migração para React Native (contradiz a narrativa da Parte 1).
- Troca de `provider` por Riverpod/BLoC.
- Avatar em R2/object storage (segue como data URI com limite de 400 KB).
- Passkeys/WebAuthn, MFA, notificações push server-side.
- Internacionalização / multi-idioma.
- Migração dos hashes PBKDF2 legados → base nova com BCrypt + seed (decisão registrada em US-003).
- Tempo real no dashboard (WebSocket); os indicadores são sob demanda (pull).

---

## 6. User stories detalhadas (as de maior risco)

### [US-002] Motor de risco em Java com paridade garantida

**Como** desenvolvedor do time
**Quero** um `RiskEngine.java` idêntico às versões Dart e TypeScript, com os mesmos testes
**Para que** o badge de risco no app, o texto da IA e os números do dashboard nunca divirjam

**Contexto:** hoje a fórmula existe em `risk_engine.dart` e `risk.ts`, copiada à mão. A Fase 5
adiciona uma terceira cópia. Sem teste compartilhado, a divergência é questão de tempo.

```gherkin
Scenario: Streak zero resulta em risco médio ou maior
  Given um desafio com streak = 0 e currentDay = 5
  When o RiskEngine avalia o desafio
  Then o riskScore é maior que 0.25

Scenario: Progresso completo resulta em risco baixo
  Given um desafio com streak = 10, currentDay = 30, totalDays = 30, atividade hoje
  When o RiskEngine avalia o desafio
  Then o riskLevel é LOW

Scenario: Desafio abandonado é crítico
  Given um desafio com streak = 0, currentDay = 1 e última atividade há 10 dias
  When o RiskEngine avalia o desafio
  Then o riskScore é maior que 0.5

Scenario: Dia de marco sempre celebra
  Given um desafio com currentDay em {7, 14, 21, 30}
  When o RiskEngine determina a ação sugerida
  Then a ação é CELEBRATE_MILESTONE independentemente do nível de risco

Scenario: Score sempre normalizado
  Given qualquer combinação de currentDay de 0 a 30 e streak de 0 a 30
  When o RiskEngine avalia o desafio
  Then o riskScore está em [0.0, 1.0]
```

**Critérios adicionais**
- `RiskEngineTest.java` cobre exatamente os mesmos casos de `test/risk_engine_test.dart`.
- Enums `RiskLevel` e `SuggestedAction` expõem os mesmos nomes de domínio das outras camadas.
- Documento de referência (na doc PDF) mostra a fórmula única e aponta os 3 arquivos.

**DoD:** `mvn test` verde · fórmula conferida lado a lado com `risk.ts` no PR.

---

### [US-003] Autenticação com JWT e papéis

**Como** usuário do Level30 (estudante ou coordenador)
**Quero** criar conta e entrar com e-mail e senha
**Para que** meus dados fiquem protegidos e o acesso administrativo seja restrito

**Contexto:** o app **não pode** perceber a troca de backend — o shape de `{ token, user }` e o
`user` de `UserProfile.fromJson` continuam iguais. Decisão registrada: **base nova**, usuários
recriados com BCrypt + seed; sem migração dos hashes PBKDF2 legados.

```gherkin
Scenario: Cadastro bem-sucedido
  Given um e-mail ainda não cadastrado e uma senha com pelo menos 8 caracteres
  When faço POST /auth/signup com nome, e-mail e senha
  Then recebo 201 com { token, refreshToken, user }
  And user tem { id, name, email, totalXp: 0, avatar: null }
  And a senha é persistida com hash BCrypt (nunca em texto puro)

Scenario: E-mail duplicado
  Given um e-mail já cadastrado
  When faço POST /auth/signup com esse e-mail
  Then recebo 409 com { status, mensagem, detalhes, timestamp }

Scenario: Login inválido
  Given credenciais que não conferem
  When faço POST /auth/login
  Then recebo 401
  And a mensagem não revela se foi o e-mail ou a senha que falhou

Scenario: Acesso sem token
  Given uma requisição a GET /me sem header Authorization
  Then recebo 401

Scenario: Usuário comum tentando rota de admin
  Given um token válido de um usuário com role USER
  When faço GET /admin/indicadores
  Then recebo 403

Scenario: E-mail normalizado
  Given o cadastro com "  Joao@Exemplo.COM  "
  When o cadastro é processado
  Then o e-mail persistido é "joao@exemplo.com"
```

**DoD:** `AuthControllerIT` com H2 cobrindo os cenários · `SessionCreationPolicy.STATELESS` ·
`JWT_SECRET` só por variável de ambiente · README documenta `openssl rand -hex 32`.

---

### [US-006] · [US-007] · [US-008] Completar dia — regras corrigidas no servidor

**Como** estudante que marca o dia como feito
**Quero** que o servidor conte os dias, o streak e o XP de forma correta e à prova de repetição
**Para que** meu progresso seja confiável e não seja possível inflar XP repetindo o botão

**Contexto:** hoje a trava de "dia já feito" só existe no app; o backend sempre incrementa o
streak; o XP é recalculado mas a divergência de arredondamento entre plataformas é possível.

```gherkin
Scenario: Primeiro complete do dia
  Given um desafio meu com currentDay = 4, totalDays = 30, última atividade ontem
  When faço POST /challenges/{id}/complete
  Then recebo 200 com { challenge, xpDelta, totalXp }
  And challenge.currentDay = 5
  And challenge.streak aumentou em 1
  And xpDelta = earnedXp(5,30,reward) - earnedXp(4,30,reward), com divisão inteira
  And users.total_xp foi somado de xpDelta na mesma transação

Scenario: Segundo complete no mesmo dia (fuso Brasil)
  Given que já completei esse desafio hoje (America/Sao_Paulo)
  When faço POST /challenges/{id}/complete de novo
  Then recebo 409 com mensagem "Você já concluiu este desafio hoje."
  And nenhum XP é somado

Scenario: Retomada após 2+ dias parado
  Given um desafio meu com streak = 6 e última atividade há 3 dias
  When faço POST /challenges/{id}/complete
  Then challenge.streak = 1 (reiniciado, não 7)

Scenario: Retomada no dia seguinte
  Given um desafio meu com streak = 6 e última atividade ontem
  When faço POST /challenges/{id}/complete
  Then challenge.streak = 7

Scenario: Desafio já concluído
  Given um desafio meu com currentDay = totalDays
  When faço POST /challenges/{id}/complete
  Then recebo 400 "Desafio já concluído."

Scenario: Desafio de outro usuário
  Given um desafio que não é meu
  When faço POST /challenges/{id}/complete
  Then recebo 404 (não 403)
```

**DoD:** `ChallengeServiceTest` cobre os 6 cenários · anотação `@Transactional` no método ·
`earnedXp` = `(currentDay * xpReward) / totalDays` em `long`/inteiro, idêntico ao getter Dart.

---

### [US-009] Recomendação por IA com fallback

**Como** estudante abrindo o detalhe de um desafio
**Quero** uma dica curta e contextual para hoje
**Para que** eu saiba o próximo passo mesmo quando a IA está indisponível

```gherkin
Scenario: IA responde
  Given o Worker de IA disponível
  When faço GET /challenges/{id}/recommendation
  Then recebo { message, riskScore, riskLevel, aiGenerated: true }
  And riskScore/riskLevel vêm do RiskEngine.java (não da IA)

Scenario: IA indisponível
  Given o Worker retorna erro ou resposta vazia dentro de 15 s
  When faço GET /challenges/{id}/recommendation
  Then recebo 200 com { message: <mensagem padrão do RiskEngine>, aiGenerated: false }
  And o app exibe o selo "Sugestão padrão"

Scenario: Timeout
  Given o Worker demora mais de 15 s
  Then o Spring aborta e cai no fallback (não pendura a requisição)
```

**DoD:** contrato de resposta idêntico ao Worker atual · timeout configurável em `application.yml`.

---

### [US-011] Endpoints administrativos

**Como** coordenador do programa
**Quero** ver usuários, desafios e indicadores agregados
**Para que** eu identifique quem está em risco de abandono e acompanhe a adesão

```gherkin
Scenario: Indicadores agregados
  Given que sou ADMIN autenticado
  When faço GET /admin/indicadores
  Then recebo { totalUsuarios, totalDesafios, desafiosConcluidos, desafiosEmRisco,
                xpMedioPorUsuario, melhorStreak, porCategoria[], porNivelDeRisco[] }
  And "desafiosEmRisco" conta desafios com riskLevel HIGH ou CRITICAL pelo RiskEngine

Scenario: Lista paginada de desafios com filtro
  Given que sou ADMIN
  When faço GET /admin/desafios?riskLevel=critical&category=study&page=0&size=20
  Then recebo uma Page com só desafios de estudo em risco crítico

Scenario: Lista de usuários
  Given que sou ADMIN
  When faço GET /admin/usuarios?page=0
  Then cada item traz id, nome, e-mail, totalXp, nível e quantidade de desafios

Scenario: Não-admin
  Given um token de role USER
  When acesso qualquer /admin/**
  Then recebo 403
```

**DoD:** `@PreAuthorize("hasRole('ADMIN')")` · agregações via query (não em memória) para o volume
do seed · nível de risco calculado com a mesma engine.

---

### [US-024] Formulário funcional de criação de desafio (Angular)

**Como** coordenador testando o dashboard
**Quero** criar um desafio pelo painel com um formulário de verdade
**Para que** o requisito de `[(ngModel)]` e binding bidirecional seja cumprido e demonstrável

```gherkin
Scenario: Criação válida
  Given que estou em /admin autenticado como ADMIN
  When preencho título (≥ 3), categoria, descrição, duração (7–90) e XP (100–1000)
  And clico em "Criar desafio"
  Then é feito POST /challenges e a tabela recarrega com o novo item no topo
  And vejo feedback visual de sucesso

Scenario: Validação no cliente
  Given o campo título com 2 caracteres
  Then o botão "Criar" fica [disabled]
  And uma mensagem *ngIf explica o motivo

Scenario: Erro do servidor
  Given o servidor retorna 400
  Then a mensagem de erro do contrato { mensagem } aparece sem quebrar a tela
```

**Critérios de rastreabilidade (checklist seção 3.3)**
- `[(ngModel)]` nos 5 campos · `(ngSubmit)` no form · `[disabled]` no botão · `*ngIf` nos erros.
- Chamada HTTP **dentro do service** injetável, nunca no componente.

---

### [US-032] Cache offline de desafios

**Como** estudante numa conexão instável
**Quero** abrir o app e ver meus desafios mesmo sem internet
**Para que** eu não perca o contexto do meu progresso

**Contexto:** hoje `ChallengeProvider.refresh()` zera a lista em erro de rede — offline vira tela
vazia. A decisão anterior de "honestidade" (não mostrar dado velho como novo) permanece, mas
sinalizada.

```gherkin
Scenario: Refresh com sucesso
  Given conexão disponível
  When o app chama refresh()
  Then a lista vem da API e é gravada no cache local
  And isStale = false

Scenario: Refresh sem rede, com cache
  Given falha de rede e um cache local salvo
  When o app chama refresh()
  Then a lista exibida vem do cache
  And isStale = true
  And a Home mostra um banner discreto "Exibindo dados salvos localmente"

Scenario: Refresh sem rede, sem cache
  Given falha de rede e nenhum cache
  Then a tela vazia atual é mantida (com CTA de criar desafio)

Scenario: Reconexão
  Given que estava em modo stale
  When a conexão volta e um novo refresh tem sucesso
  Then o banner some e isStale = false
```

**DoD:** cache em `shared_preferences` ou `hive` · teste de provider com repositório fake cobrindo
os 4 cenários · nenhuma ação de escrita (completar/criar/excluir) é permitida offline sem feedback.

---

### [US-033] Sessão contínua com refresh token

**Como** estudante que usa o app todo dia
**Quero** continuar logado sem precisar digitar a senha de novo a cada expiração
**Para que** o hábito diário não seja interrompido

```gherkin
Scenario: Access token expirado, refresh válido
  Given meu access token expirou mas o refresh token é válido
  When qualquer requisição recebe 401
  Then o ApiClient chama POST /auth/refresh uma vez
  And repete a requisição original com o novo access token
  And eu não percebo nada

Scenario: Refresh também inválido
  Given access e refresh tokens expirados
  When a tentativa de refresh falha
  Then onUnauthorized dispara: sessão limpa e volto para /login

Scenario: Uma tentativa só
  Given um 401 persistente mesmo após refresh
  Then o ApiClient não entra em loop de refresh (máximo 1 tentativa por requisição)
```

**DoD:** `refreshToken` em `flutter_secure_storage` · lógica no `ApiClient` (não espalhada nos
providers) · teste cobrindo os 3 cenários.

---

## 7. Roadmap — Now / Next / Later

```
NOW  (Onda 1 — fundação)              NEXT (Onda 2 — regras, IA, admin)     LATER (Onda 3 — web, mobile, entrega)
───────────────────────────────      ─────────────────────────────────    ──────────────────────────────────────
• US-001 scaffold + PostgreSQL       • US-006/007/008 regras de completar  • US-012/013/016 Swagger, erros, seed
• US-002 RiskEngine.java + testes     • US-004 refresh token                • US-020..028 dashboard Angular completo
• US-003 auth + JWT + roles          • US-009/010 gateway de IA + fallback  • US-030..036 maturidade do app Flutter
• US-005 CRUD + ownership            • US-015 Worker protegido              • US-040..043 doc PDF, slides, vídeo, repo
• US-014 CORS + segredo por env      • US-011 endpoints /admin/**
```

**Mapa para os 10 passos de execução da spec:** passos 1–3 = Onda 1 · passos 4–6 = Onda 2 ·
passos 7–10 = Onda 3.

---

## 8. Critérios de aceite da release (Sprint Review da Fase 5)

**Backend (E1)**
- [ ] `mvn test` verde, incluindo `RiskEngineTest` portado e `ChallengeServiceTest`.
- [ ] Swagger em `/swagger-ui.html` navegável, com autenticação Bearer.
- [ ] App Flutter funciona **sem alterar** `Challenge.fromJson` / `UserProfile.fromJson`.
- [ ] Completar o mesmo dia duas vezes → `409`.
- [ ] Streak reinicia após 2 dias de inatividade.
- [ ] `USER` recebe `403` em `/admin/**`; requisição sem token → `401`.
- [ ] `JWT_SECRET` fora do código e do `application.yml` versionado.

**Dashboard (E2)**
- [ ] Os 9 itens do checklist da seção 3.3 presentes e localizáveis no código.
- [ ] Consome a mesma API do mobile; nenhum endpoint web além de `/admin/**`.
- [ ] Loading, sucesso e erro tratados visualmente em todas as telas.

**App (E3)**
- [ ] Nenhuma tela chama `ApiClient` diretamente.
- [ ] App abre offline exibindo cache com banner de aviso.
- [ ] Sessão sobrevive à expiração do access token via refresh.
- [ ] `flutter analyze` sem warnings · `flutter test` verde.

**Acadêmico (E4)**
- [ ] ZIP com: PDF de documentação, código/link do repo liberado, slides PDF (≤ 10), link do vídeo.
- [ ] Link do vídeo no documento **e** nos slides.
- [ ] Slides abrem com nome, RM e foto de cada integrante.

---

## 9. Riscos e mitigação (registro do PO)

| # | Risco | Impacto | Mitigação | Dono |
|---|---|---|---|---|
| R1 | Enum de categoria serializado em maiúsculo quebra o parse do Dart silenciosamente | Alto | US-005 tem cenário de contrato; teste de integração compara o JSON byte a byte com um payload do Worker | Dev |
| R2 | `earnedXp` diverge por arredondamento entre Java e Dart | Alto | US-008 exige divisão inteira `long`; teste com valores que não dividem exато (ex.: 300/30, 250/90) | Dev |
| R3 | Trava de dia duplicado em UTC conta o dia errado à noite no Brasil | Médio | US-006 fixa `America/Sao_Paulo` no critério de aceite | Dev |
| R4 | Espelhamento triplo do risco desalinha badge × IA × dashboard | Alto | US-002 congela a suíte de testes como contrato; PR checklist obriga conferência lado a lado | PO/Dev |
| R5 | Workers AI só roda no runtime Cloudflare — tentativa de chamar direto do Spring falha | Médio | Arquitetura mantém o Worker como gateway (US-009/010); racional documentado no PDF (US-040) | Arquiteto |
| R6 | Entrega acadêmica comprime no fim e o vídeo/slides ficam fracos | Alto | US-040–043 entram na Onda 3 com meta de −48 h (KR B1); seed (US-016) pronto antes da gravação | PO |
| R7 | Escopo do dashboard cresce além do checklist e atrasa o mobile | Médio | Won't-have explícito na seção 5; US-025/026/027 são `Should`, cortáveis | PO |
| R8 | Migração de senhas legadas consome tempo sem valor para a demo | Baixo | Decisão registrada: base nova + seed (US-003); PBKDF2 legado é Won't-have | PO |

---

## 10. Próximo passo

Este backlog define **o quê** e **a ordem**. A execução (**o como**) começa pela Onda 1, US-001 →
US-002. Recomendação: abrir o refinamento técnico de cada story com o time (Tech Lead / Arquiteto)
antes de iniciar cada onda, validando estimativa e quebra em tarefas.

O PO aceita cada story contra os critérios de aceite em Gherkin acima — não antes.
