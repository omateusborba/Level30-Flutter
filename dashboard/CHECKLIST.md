# Rastreabilidade — Checklist de avaliação Angular (backlog seção 3.3)

Mapa de cada recurso exigido para arquivo:linha. Conferido contra o código deste
diretório (Angular 18 standalone) após o polimento de design e o endurecimento
de segurança (Bloco 1: A2 refresh, A5 guard de papel, A7 headers, A8 ícones SVG).

Base URL da API: ver `../VISAO-GERAL.md` (credenciais só no `.env` da VM).

---

## 1. Interpolação `{{ expressão }}`

| Onde | Arquivo:linha |
|---|---|
| Nome do usuário logado no cabeçalho | `src/app/app.component.ts:22` |
| Mensagem de erro do login | `src/app/features/login/login.component.ts:47` |
| Rótulo e valor de cada KPI | `src/app/features/home/home.component.ts:58-59` |
| Card "precisa de atenção" (título, aluno, categoria, dia, %) | `src/app/features/home/home.component.ts:69-78` |
| Contagem por categoria / risco (com pipes) | `src/app/features/home/home.component.ts:88,92,101,110` |
| Título / progresso / streak / risco de cada desafio | `src/app/features/admin/admin.component.ts:167-181` |
| `riskScore` formatado como `%` | `src/app/features/admin/admin.component.ts:181` |
| Total de elementos / paginação | `src/app/features/admin/admin.component.ts:197-199` |
| Colunas da tabela de usuários | `src/app/features/admin/admin.component.ts:229-234` |

## 2. Property binding `[prop]="expr"`

| Onde | Arquivo:linha |
|---|---|
| `[disabled]` no botão Entrar / inputs do login | `src/app/features/login/login.component.ts:30,42,53` |
| `[name]` do `<app-icon>` de cada KPI + `[attr.d]` do `<path>` no ícone | `home.component.ts:56` · `src/app/shared/ui/icon.component.ts:33` |
| `[style.width.%]` / `[style.background]` nas barras de distribuição | `src/app/features/home/home.component.ts:90,101,106-107` |
| `[routerLink]` no card de atenção | `src/app/features/home/home.component.ts:67` |
| `[value]` nas `<option>` dos selects | `src/app/features/admin/admin.component.ts:59,123,131` |
| `[disabled]` nos botões/inputs enquanto `creating`/`loadingDesafios`/`deletingId` | `src/app/features/admin/admin.component.ts:50,58,66,121,129,140,183` |
| `[ngClass]` dinâmico no badge de risco | `src/app/features/admin/admin.component.ts:172` |
| `[style.background]` dinâmico no badge de risco | `src/app/features/admin/admin.component.ts:173` |
| `routerLink` / `routerLinkActive` na navegação | `src/app/app.component.ts:18-19` |

## 3. Event binding `(evento)="handler()"`

| Onde | Arquivo:linha |
|---|---|
| `(ngSubmit)` no formulário "Publicar modelo do programa" (C3) | `admin.component.ts` (form `(ngSubmit)="createChallenge()"`) |
| `(ngSubmit)` no formulário de login | `src/app/features/login/login.component.ts` (form `(ngSubmit)="submit()"`) |
| `(click)` "Sair" | `src/app/app.component.ts:24` |
| `(click)` "Tentar de novo" nos indicadores | `src/app/features/home/home.component.ts:36` |
| `(ngModelChange)` nos dropdowns de filtro → recarrega a lista | `src/app/features/admin/admin.component.ts:121,129` |
| `(click)` "Atualizar", ordenação de coluna, "Excluir", modal | `src/app/features/admin/admin.component.ts:140,158-163,185,207-208` |

## 4. Two-way binding `[(ngModel)]`

| Onde | Arquivo:linha |
|---|---|
| E-mail e senha no `/login` | `src/app/features/login/login.component.ts:28,40` |
| Formulário "Publicar modelo" (C3) — os 5 campos + tabela de modelos | `admin.component.ts` (title/category/description/totalDays/xpReward) |
| Dropdowns de filtro + campo de busca em `/admin` | `src/app/features/admin/admin.component.ts:121,129,137` |

## 5. `*ngIf`

| Onde | Contagem |
|---|---|
| `src/app/app.component.ts` (shell autenticado vs. tela bare) | 1 |
| `src/app/features/login/login.component.ts` (erro, loading) | 4 |
| `src/app/features/home/home.component.ts` (loading, erro, estado vazio, seções condicionais) | 8 |
| `src/app/features/admin/admin.component.ts` (hints de validação, loading, erros, estados vazios, modal) | 22 |

## 6. `*ngFor`

| Onde | Arquivo:linha |
|---|---|
| KPIs, card de atenção, barras de distribuição | `src/app/features/home/home.component.ts:55,67,87,99` |
| `<option>` de categoria/risco | `src/app/features/admin/admin.component.ts:59,123,131` |
| Linhas da tabela de desafios (`desafiosView`) e de usuários | `src/app/features/admin/admin.component.ts:168,229` |

## 7. `HttpClient` em service injetável

| Service | Arquivo:linha |
|---|---|
| `auth.service.ts` — `http.post` no login | `src/app/core/services/auth.service.ts` |
| `challenge.service.ts` — `http.post` / `http.delete` | `src/app/core/services/challenge.service.ts:18,22` |
| `admin.service.ts` — `http.get` indicadores / desafios / usuários | `src/app/core/services/admin.service.ts:32,45,54` |
| Registro | `src/app/app.config.ts:12` (`provideHttpClient(withInterceptors([authInterceptor]))`) |

Nenhum componente injeta `HttpClient` — todos assinam os `Observable` dos services.

## 8. Rotas `/home` e `/admin` com navegação

| Onde | Arquivo:linha |
|---|---|
| Definição das rotas (lazy `loadComponent`) + `adminGuard` | `src/app/app.routes.ts` |
| Links de navegação | `src/app/app.component.ts:18-19` |
| `<router-outlet>` | `src/app/app.component.ts` |
| Interceptor de auth (Bearer + refresh em 401) | `src/app/core/interceptors/auth.interceptor.ts` |
| Guard (autenticação + papel ADMIN, A5) | `src/app/core/guards/admin.guard.ts` |

## 9. Estilização e feedback visual (loading / sucesso / erro / vazio)

| Estado | Onde |
|---|---|
| Spinner de carregamento | `.spinner` — todas as telas (`*ngIf="loading"`) |
| Erro | `.alert-error` — login, home, admin |
| Sucesso | `.alert-success` — admin (desafio criado) |
| Estado vazio | home (`state-empty` quando não há dados), admin (busca sem resultado, filtros sem resultado, sem usuários) |
| Modal de confirmação | admin — exclusão de desafio (`.modal-backdrop`) |
| Design tokens | `src/styles.css:1-16` — mesmos valores de `lib/core/constants/app_colors.dart` |

---

## Parte B — Dashboards (mesmos padrões, mais superfície)

Os 3 painéis novos (`features/dashboards/{engajamento,risco,gamificacao}.component.ts`) e os
componentes de gráfico (`shared/charts/`) usam exatamente os mesmos recursos já mapeados acima —
`*ngIf`/`*ngFor` (estados loading/erro/vazio, listas), interpolação, property binding
(`[data]`, `[series]`, `[ngStyle]`, `[style.*]`, `[ngClass]`), event binding (`(click)` nos
seletores de período e retry), rotas lazy (`/dashboards/*` em `app.routes.ts`), `MetricasService`
concentrando o HTTP. Gráficos são **SVG/CSS próprios** — nenhuma lib externa.
