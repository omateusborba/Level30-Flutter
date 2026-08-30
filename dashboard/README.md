# Level30 — Dashboard do Coordenador (Angular)

Painel administrativo web do projeto Level30 (FIAP — "Mobile Hybrid App e a
Sociedade 5.0", Fase 5). Consome a **mesma API Spring Boot** do app Flutter,
apenas os endpoints `/auth/**` e `/admin/**` + `POST`/`DELETE` de `/challenges`.

Angular 18 · standalone components (sem NgModule) · sem libs de UI/chart.

## Pré-requisitos

- Node 20+ (testado com Node 24) e npm 10+ (testado com npm 11).
- **Backend rodando em `http://localhost:8080`.** Sem ele o login e todas as
  telas mostram estado de erro. Para subir:

  ```bash
  cd ../backend
  JAVA_HOME=/opt/homebrew/opt/openjdk@21 mvn spring-boot:run
  ```

  O backend precisa permitir CORS da origem `http://localhost:4200`.

## Instalação

```bash
npm install
```

## Rodar em desenvolvimento

```bash
npm start
```

Abre em `http://localhost:4200`. A URL da API fica em
`src/environments/environment.ts` (`apiBaseUrl`).

## Build de produção

```bash
npm run build
```

Saída em `dist/dashboard/`. O build precisa compilar sem erros (critério de pronto).

## Credenciais de seed (ambiente dev do backend)

| Papel | E-mail | Senha |
|---|---|---|
| ADMIN | `admin@level30.app` | `admin1234` |
| USER  | `ana@level30.app` / `bruno@level30.app` / `carla@level30.app` | `estudante1` |

Use a conta **ADMIN** — os endpoints `/admin/**` retornam `403` para `USER`.
Contas `USER` conseguem logar mas as telas do painel ficarão em erro/403.

## Rotas

| Rota | Descrição | Protegida |
|---|---|---|
| `/login` | e-mail + senha (`[(ngModel)]`), `POST /auth/login`, guarda o token no `localStorage` | não |
| `/home` | KPIs de `GET /admin/indicadores` + distribuição por categoria e por nível de risco | `adminGuard` |
| `/admin` | tabela de desafios (`GET /admin/desafios`) com filtros, formulário de criação (`POST /challenges`), exclusão com confirmação (`DELETE /challenges/{id}`), tabela de usuários (`GET /admin/usuarios`) | `adminGuard` |

## Arquitetura

```
src/app/
  app.config.ts          provideHttpClient(withInterceptors([authInterceptor])) + provideRouter
  app.routes.ts          rotas /login /home /admin (lazy loadComponent) + adminGuard
  app.component.ts        shell: topbar, navegação, <router-outlet>
  core/
    models/              User, Challenge, AdminChallenge, AdminUser, Indicadores, Page<T>, ApiError...
    services/            auth.service.ts · admin.service.ts · challenge.service.ts  (todo HttpClient aqui)
    interceptors/        auth.interceptor.ts  (Authorization: Bearer + logout em 401)
    guards/              admin.guard.ts       (bloqueia rotas sem sessão)
    http-error.util.ts   extrai { mensagem } do contrato de erro
  features/
    login/               tela de login
    home/                indicadores (KPIs + barras CSS)
    admin/               desafios + criação + exclusão + usuários
```

Nenhum componente injeta `HttpClient` — toda chamada HTTP vive num service.

## Rastreabilidade

`CHECKLIST.md` mapeia cada item do checklist de avaliação Angular
(interpolação, property binding, event binding, two-way binding, `*ngIf`,
`*ngFor`, HttpClient em service, rotas `/home` e `/admin`, feedback visual)
para `arquivo:linha`.

## Identidade visual

Mesma paleta do app Flutter (`PROJECT.md` seção 9): fundo `#080A17`, surface
`#111328`, acento `#00FF9C`, fonte Poppins (Google Fonts via `<link>` no
`index.html`), tema dark. Semáforo de risco: `low` verde `#22C55E`, `medium`
amarelo `#EAB308`, `high` laranja `#F97316`, `critical` vermelho `#EF4444`.
