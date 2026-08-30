# Rastreabilidade — Checklist de avaliação Angular (backlog seção 3.3)

Mapa de cada recurso exigido para arquivo:linha onde ele aparece. Referências
conferidas contra o código deste diretório (Angular 18 standalone).

Base URL da API e credenciais de seed: ver `README.md`.

---

## 1. Interpolação `{{ expressão }}`

| Onde | Arquivo:linha |
|---|---|
| Nome do usuário logado no cabeçalho (`{{ auth.user()?.name }}`) | `src/app/app.component.ts:22` |
| Mensagem de erro do login | `src/app/features/login/login.component.ts:49` |
| Valor e rótulo de cada card de KPI | `src/app/features/home/home.component.ts:43-44` |
| Contagem por categoria / risco | `src/app/features/home/home.component.ts:53,60,69,78` |
| Título, progresso, streak, risco de cada desafio | `src/app/features/admin/admin.component.ts:156-170` |
| `riskScore` formatado (`d.riskScore.toFixed(2)`) | `src/app/features/admin/admin.component.ts:170` |
| Total de elementos / paginação | `src/app/features/admin/admin.component.ts:187-188` |
| Colunas da tabela de usuários | `src/app/features/admin/admin.component.ts:215-220` |

## 2. Property binding `[prop]="expr"`

| Onde | Arquivo:linha |
|---|---|
| `[disabled]` no botão Entrar durante loading | `src/app/features/login/login.component.ts:55` |
| `[disabled]` nos inputs do login | `src/app/features/login/login.component.ts:32,44` |
| `[style.width.%]` / `[style.background]` nas barras de distribuição | `src/app/features/home/home.component.ts:57,74-75` |
| `[value]` nas `<option>` dos selects | `src/app/features/admin/admin.component.ts:54,118,126` |
| `[disabled]` nos botões/inputs enquanto `creating` / `loadingDesafios` | `src/app/features/admin/admin.component.ts:45,77,101,116,130,178` |
| `[ngClass]` dinâmico no badge de risco (`'risk-' + d.riskLevel`) | `src/app/features/admin/admin.component.ts:167` |
| `[style.background]` dinâmico no badge de risco | `src/app/features/admin/admin.component.ts:168` |
| `routerLink` / `routerLinkActive` na navegação | `src/app/app.component.ts:18-19` |

## 3. Event binding `(evento)="handler()"`

| Onde | Arquivo:linha |
|---|---|
| `(ngSubmit)` no formulário de login | `src/app/features/login/login.component.ts:23` |
| `(click)` no botão "Sair" | `src/app/app.component.ts:23` |
| `(click)` "Tentar de novo" nos indicadores | `src/app/features/home/home.component.ts:35` |
| `(ngSubmit)` no formulário de criar desafio | `src/app/features/admin/admin.component.ts:41` |
| `(ngModelChange)` nos dropdowns de filtro → recarrega a lista | `src/app/features/admin/admin.component.ts:116,124` |
| `(click)` nos botões "Atualizar" e "Excluir" | `src/app/features/admin/admin.component.ts:130,177` |

## 4. Two-way binding `[(ngModel)]`

| Onde | Arquivo:linha |
|---|---|
| E-mail e senha no `/login` | `src/app/features/login/login.component.ts:30,42` |
| Formulário de criar desafio — os 5 campos: título, categoria, descrição, duração, XP | `src/app/features/admin/admin.component.ts:45,53,61,73,89` |
| Dropdowns de filtro (categoria, nível de risco) em `/admin` | `src/app/features/admin/admin.component.ts:116,124` |

## 5. `*ngIf`

| Onde | Arquivo:linha |
|---|---|
| Shell autenticado vs. tela "bare" de login | `src/app/app.component.ts:11,29` |
| Erro do login | `src/app/features/login/login.component.ts:49` |
| Loading / erro / conteúdo dos indicadores | `src/app/features/home/home.component.ts:27,32,39` |
| Estado vazio das distribuições | `src/app/features/home/home.component.ts:51,66` |
| Loading / erro / vazio das tabelas de desafios e usuários | `src/app/features/admin/admin.component.ts:136,138,139,142,198,200,201,202` |
| Mensagens de validação do formulário (`hint`) | `src/app/features/admin/admin.component.ts:46,62,79,95` |
| Sucesso / erro da criação de desafio | `src/app/features/admin/admin.component.ts:36,39` |

## 6. `*ngFor`

| Onde | Arquivo:linha |
|---|---|
| Cards de KPI | `src/app/features/home/home.component.ts:42` |
| Barras por categoria e por nível de risco | `src/app/features/home/home.component.ts:52,67` |
| `<option>` de categorias e níveis de risco | `src/app/features/admin/admin.component.ts:54,118,126` |
| Linhas da tabela de desafios | `src/app/features/admin/admin.component.ts:155` |
| Linhas da tabela de usuários | `src/app/features/admin/admin.component.ts:214` |

## 7. HttpClient dentro de service injetável (nunca no componente)

| Service | Arquivo | Chamadas |
|---|---|---|
| `AuthService` | `src/app/core/services/auth.service.ts:33` | `POST /auth/login` |
| `AdminService` | `src/app/core/services/admin.service.ts:33,37,55` | `GET /admin/indicadores`, `GET /admin/desafios`, `GET /admin/usuarios` |
| `ChallengeService` | `src/app/core/services/challenge.service.ts:17,21` | `POST /challenges`, `DELETE /challenges/{id}` |
| Registro do `HttpClient` + interceptor | `src/app/app.config.ts:11` | `provideHttpClient(withInterceptors([authInterceptor]))` |
| Interceptor `Authorization: Bearer` + logout em 401 | `src/app/core/interceptors/auth.interceptor.ts:13,19` | — |

Nenhum componente importa `HttpClient`. Os componentes só injetam services e assinam `Observable`s.

## 8. Rotas `/home` e `/admin`

| Item | Arquivo:linha |
|---|---|
| Definição das rotas `login`, `home`, `admin` (lazy `loadComponent`) | `src/app/app.routes.ts:5-24` |
| Guard `adminGuard` protegendo `/home` e `/admin` | `src/app/app.routes.ts:15,21` + `src/app/core/guards/admin.guard.ts:6` |
| `<router-outlet>` no shell | `src/app/app.component.ts:26,30` |
| Links de navegação entre as rotas | `src/app/app.component.ts:18-19` |

## 9. Feedback visual de loading / erro / vazio em todas as telas

| Tela | Loading | Erro | Vazio |
|---|---|---|---|
| `/login` | spinner no botão `login.component.ts:57-59` | alerta `login.component.ts:49` | botão `[disabled]` com form inválido `login.component.ts:55` |
| `/home` | `home.component.ts:27` | `home.component.ts:32` (+ retry :35) | "Sem dados." `home.component.ts:51,66` |
| `/admin` desafios | `admin.component.ts:136` | `admin.component.ts:135` | "Nenhum desafio..." `admin.component.ts:139` |
| `/admin` usuários | `admin.component.ts:198` | `admin.component.ts:197` | "Nenhum usuário." `admin.component.ts:201` |
| `/admin` criar desafio | spinner `admin.component.ts:102-104` | `admin.component.ts:39` | sucesso `admin.component.ts:36` |

Estilos dos estados: `.state`, `.spinner`, `.alert-error`, `.alert-success`, `.hint` em `src/styles.css`.

---

## Extras de identidade visual (US-027)

| Item | Arquivo |
|---|---|
| Paleta `#080A17` / `#111328` / `#00FF9C` + semáforo de risco | `src/styles.css:3-19` |
| Fonte Poppins via Google Fonts `<link>` | `src/index.html:11-13` |
| Semáforo de risco verde/amarelo/laranja/vermelho | `src/styles.css:14-17`, usado em `home.component.ts` e `admin.component.ts` |
