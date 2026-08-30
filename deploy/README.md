# deploy/ — Opção C (JAR fora da Cloudflare, de graça)

API Spring Boot + Postgres numa VM **Oracle Cloud Always Free**, exposta por **Cloudflare Tunnel**.
Dashboard no **Cloudflare Pages**, Worker de IA na **Cloudflare**. Custo: **US$ 0/mês**.

## Passo a passo completo

👉 [`../specs/003-fase-5/deploy-oracle.md`](../specs/003-fase-5/deploy-oracle.md)

## TL;DR (já com a VM pronta e o domínio na Cloudflare)

```bash
git clone <repo> level30 && cd level30/deploy
cp .env.example .env && nano .env          # preencher segredos + TUNNEL_TOKEN
docker compose up -d --build
docker compose logs -f api                 # aguardar "Started Level30ApiApplication"
curl https://api.SEU-DOMINIO/actuator/health
```

## Arquivos

| Arquivo | Papel |
|---|---|
| `docker-compose.yml` | `postgres` + `api` (jar) + `cloudflared` |
| `.env.example` | modelo — copie para `.env` (que **não** é versionado) |
| `../backend/Dockerfile` | build multi-stage do jar |
| `../backend/src/main/resources/application-prod.yml` | profile `prod` |

## Atualizar o deploy

```bash
git pull && docker compose up -d --build
```
