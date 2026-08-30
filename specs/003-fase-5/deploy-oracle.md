# Deploy — Opção C: JAR na Oracle Cloud (grátis) + resto na Cloudflare

> Objetivo: subir a **API Spring Boot** (`backend/`) num servidor real de graça, mantendo
> **dashboard Angular** no Cloudflare Pages e **Worker de IA** (`server/`) na Cloudflare.
> Custo final: **US$ 0/mês**.

```
Internet
 ├─ Cloudflare Pages ────────────── dashboard Angular            [grátis]
 ├─ Cloudflare Worker ──────────── IA (server/)                  [grátis]
 └─ Cloudflare Tunnel ─ api.SEU-DOMINIO ─┐                       [grátis]
                                         ▼
                    VM Oracle Cloud "Always Free" (ARM Ampere)   [grátis p/ sempre]
                     docker compose:  postgres + api(jar) + cloudflared
```

**Por que Cloudflare Tunnel:** o `cloudflared` faz uma conexão **de saída** da VM para a
Cloudflare. Você **não abre nenhuma porta** na Oracle (pula a parte chata de security list +
iptables), ganha HTTPS automático e um hostname estável.

---

## 0. Pré-requisitos

- Conta **GitHub** com o repositório do projeto (para o Pages e para clonar na VM).
- **GitHub Student Developer Pack** ativo (você já tem) → usaremos o **domínio grátis**.
- Cartão de crédito **só para verificação** na Oracle (não há cobrança no Always Free).
- No seu Mac: nada além do que já está instalado.

Tempo total: ~1h (a maior parte é esperar a VM provisionar e os nameservers propagarem).

---

## 1. Domínio grátis + Cloudflare

1. **Pegue um domínio** pelo Student Pack:
   - **Namecheap** → 1 ano grátis de `.me`, ou
   - **name.com** → 1 ano grátis de `.tech` / `.online` / `.site` / `.space`.
   Registre, por exemplo, `level30-fiap.me`.
2. **Adicione o domínio na Cloudflare** (plano **Free**):
   - dash.cloudflare.com → *Add a site* → digite o domínio → plano **Free**.
   - A Cloudflare mostra 2 nameservers (ex.: `xxx.ns.cloudflare.com`).
   - Volte no registrador (Namecheap/name.com) e **troque os nameservers** pelos da Cloudflare.
   - Aguarde a ativação (minutos a algumas horas). O e-mail da Cloudflare avisa.

> Sem domínio agora? Dá pra testar com um *quick tunnel* (`cloudflared tunnel --url http://localhost:8080`),
> mas a URL é aleatória e muda a cada restart — ruim para a entrega. Recomendado ter o domínio.

---

## 2. Criar a VM na Oracle Cloud

1. Crie a conta em **cloud.oracle.com** → *Start for free*.
   - **Home region**: escolha **Brazil East (São Paulo)** ou **Brazil Southeast (Vinhedo)**.
   - Conclua a verificação (cartão). Aguarde o provisionamento da tenancy.
2. Console OCI → **Compute → Instances → Create instance**:
   - **Name**: `level30`
   - **Image**: *Canonical Ubuntu 22.04* (ou 24.04)
   - **Shape**: *Ampere* → **VM.Standard.A1.Flex** → **2 OCPUs / 12 GB RAM**
     (o Always Free cobre até 4 OCPU / 24 GB somados; 2/12 dá folga e provisiona mais fácil).
   - **Networking**: mantenha *Create new VCN*; **Assign a public IPv4 address: Yes**.
   - **SSH keys**: *Generate a key pair for me* → **baixe a chave privada** (ou cole sua pública).
   - **Create**. Anote o **Public IP** quando o estado ficar *Running*.

> **"Out of capacity" no Ampere?** É comum. Tente outra *Availability Domain*, reduza para
> 1 OCPU / 6 GB, ou repita mais tarde. Evite a shape AMD *E2.1.Micro* (só 1 GB RAM — não
> comporta Postgres + JVM).

3. **Conecte por SSH** (do seu Mac):
   ```bash
   chmod 400 ~/Downloads/ssh-key-*.key
   ssh -i ~/Downloads/ssh-key-*.key ubuntu@SEU_IP_PUBLICO
   ```
   (a porta 22 já é liberada por padrão na security list da Oracle.)

---

## 3. Preparar a VM

Dentro da VM (via SSH):

```bash
# swap de 2 GB (segurança durante o build do jar)
sudo fallocate -l 2G /swapfile && sudo chmod 600 /swapfile
sudo mkswap /swapfile && sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# Docker + compose
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER
newgrp docker
docker --version && docker compose version

# clonar o projeto
sudo apt-get install -y git
git clone https://github.com/SEU_USUARIO/SEU_REPO.git level30
cd level30/deploy
```

---

## 4. Cloudflare Tunnel

No **dashboard da Cloudflare** (dash.cloudflare.com):

1. **Zero Trust** (menu lateral) → na primeira vez, escolha o plano **Free** do Zero Trust
   (pede cartão para verificação, não cobra).
2. **Networks → Tunnels → Create a tunnel**:
   - Tipo **Cloudflared** → nome `level30` → **Save tunnel**.
   - Na tela seguinte (*Install and run a connector*), **copie o token** — é a string gigante
     depois de `--token ` (começa com `eyJ...`). Esse é o `TUNNEL_TOKEN`.
   - **Não** rode o comando que eles mostram — o `docker compose` já sobe o `cloudflared`.
3. Ainda na config do tunnel → aba **Public Hostname → Add a public hostname**:
   - **Subdomain**: `api`
   - **Domain**: seu domínio (ex.: `level30-fiap.me`)
   - **Type**: `HTTP`
   - **URL**: `api:8080`  ← nome do serviço no compose + porta
   - **Save**.
4. (Opcional, para o dashboard) repita: **Subdomain** `app`, mesma ideia, mas só se você for
   servir o Angular pela VM. Se usar o Cloudflare Pages (passo 6), não precisa.

Resultado: `https://api.SEU-DOMINIO` → tunnel → container `api:8080`.

---

## 5. Configurar e subir

Na VM, em `level30/deploy`:

```bash
cp .env.example .env
nano .env
```

Preencha:

| Variável | Valor |
|---|---|
| `DB_PASSWORD` | senha forte qualquer |
| `JWT_SECRET` | `openssl rand -hex 32` (rode no seu Mac e cole) |
| `CORS_ORIGINS` | a URL do dashboard — use já `https://app.SEU-DOMINIO` (custom domain do Pages, passo 6) |
| `SEED_ADMIN_EMAIL` / `SEED_ADMIN_PASSWORD` | login admin do dashboard (troque do default!) |
| `TUNNEL_TOKEN` | o token copiado no passo 4 |
| `AI_WORKER_URL` / `AI_SERVICE_TOKEN` | deixe vazio por ora (passo 8) |

Suba:

```bash
docker compose up -d --build      # primeiro build do jar: ~3-5 min
docker compose logs -f api        # aguarde "Started Level30ApiApplication"
docker compose ps                 # api e postgres devem ficar "healthy"
```

Teste (de qualquer lugar):

```bash
curl https://api.SEU-DOMINIO/actuator/health          # {"status":"UP"}
curl https://api.SEU-DOMINIO/swagger-ui.html          # redireciona p/ o Swagger
curl -X POST https://api.SEU-DOMINIO/auth/login \
  -H 'content-type: application/json' \
  -d '{"email":"SEU_SEED_ADMIN_EMAIL","password":"SUA_SENHA"}'
```

---

## 6. Dashboard no Cloudflare Pages

1. No seu Mac, edite **`dashboard/src/environments/environment.prod.ts`**:
   ```ts
   apiBaseUrl: 'https://api.SEU-DOMINIO',
   ```
   Commit e push.
2. Cloudflare dashboard → **Workers & Pages → Create → Pages → Connect to Git** → escolha o repo.
3. **Build settings**:
   - *Framework preset*: **Angular**
   - *Build command*: `npm ci && npm run build -- --configuration production`
   - *Build output directory*: `dist/dashboard/browser`
   - *Root directory* (em *Advanced*): `dashboard`
4. **Save and Deploy**. Ao terminar, o Pages dá `https://SEU-PROJETO.pages.dev`.
5. **Custom domain** (recomendado, casa com o `CORS_ORIGINS`): aba *Custom domains* do projeto
   Pages → *Set up a custom domain* → `app.SEU-DOMINIO`. A Cloudflare cria o DNS sozinha.
6. Confirme que `CORS_ORIGINS` no `.env` da VM = **exatamente** a origem do dashboard
   (`https://app.SEU-DOMINIO`, sem barra no fim). Se mudou, na VM:
   ```bash
   docker compose up -d      # relê o .env
   ```

Abra `https://app.SEU-DOMINIO`, faça login com o admin do seed. 🎯

> Alternativa sem Pages: descomente um serviço `nginx` no compose servindo `dashboard/dist` e
> exponha via o hostname `app` do tunnel (passo 4.4).

---

## 7. App Flutter apontando para a API

```bash
# rodar
flutter run --dart-define=API_BASE_URL=https://api.SEU-DOMINIO

# gerar APK para a demo
flutter build apk --release --dart-define=API_BASE_URL=https://api.SEU-DOMINIO
# -> build/app/outputs/flutter-apk/app-release.apk
```

---

## 8. (Opcional) Ligar a IA generativa

Sem isso, a recomendação usa o fallback determinístico e o chat responde 502. O Worker (`server/`)
agora é **só** o gateway de IA — **não usa D1** (auth/desafios estão no Postgres da VM).

```bash
# no seu Mac, em server/
cd server
npx wrangler logout                    # sai da conta antiga
npx wrangler login                     # logar na conta NOVA (a do dominio level30.online)
npx wrangler whoami                    # confirmar
npx wrangler deploy                    # cria o Worker "level30-ai-gateway" (binding: só AI)
npx wrangler secret put SERVICE_TOKEN  # cole um valor aleatorio: openssl rand -hex 24
```

Primeiro deploy numa conta nova: o wrangler pede para registrar um subdominio `*.workers.dev`.
Anote a URL final (ex.: `https://level30-ai-gateway.mateus.workers.dev`).

Na VM, no `.env`:
```
AI_WORKER_URL=https://level30-ai-gateway.SEU-SUBDOMINIO.workers.dev
AI_SERVICE_TOKEN=<o mesmo valor do SERVICE_TOKEN acima>
```
```bash
docker compose up -d
```

Teste: `GET https://api.SEU-DOMINIO/challenges/{id}/recommendation` deve voltar `aiGenerated: true`.

---

## 9. Operação

```bash
docker compose logs -f api           # logs da API
docker compose restart api           # reiniciar só a API
docker compose down                  # parar tudo (dados do Postgres ficam no volume pgdata)
docker compose up -d                 # subir

# atualizar após um push no repo
git pull && docker compose up -d --build

# backup do banco
docker compose exec postgres pg_dump -U level30 level30 > ~/backup-$(date +%F).sql
```

- Os containers têm `restart: unless-stopped` e o Docker sobe no boot da VM
  (`sudo systemctl enable docker`), então a stack volta sozinha após reinício.
- A VM Always Free pode ser **recuperada pela Oracle se ficar 100% ociosa por ~7 dias**.
  Manter a stack rodando + o tunnel ativo já gera atividade suficiente.

---

## 10. Troubleshooting

| Sintoma | Causa provável / solução |
|---|---|
| `Out of host capacity` ao criar a VM | Falta de Ampere na região. Trocar AD, reduzir para 1 OCPU/6 GB, ou repetir depois. |
| SSH `Connection refused` | Use o usuário `ubuntu` e a chave certa. A porta 22 já é aberta pela Oracle. |
| `docker compose` sem permissão | Faltou `newgrp docker` (ou reabrir o SSH após `usermod -aG docker`). |
| Build do jar morre (OOM) | Ative o swap (passo 3) ou use uma shape com mais RAM. |
| Cloudflare mostra **502** | Container `api` ainda subindo ou não-*healthy*: `docker compose logs api`. |
| Tunnel não conecta | `docker compose logs cloudflared`; confira o `TUNNEL_TOKEN` e se o *Public Hostname* aponta para `http://api:8080`. |
| Dashboard: erro de **CORS** no console | `CORS_ORIGINS` tem que ser **idêntico** à origem do Pages (esquema + host, sem path, sem `/` final). Ajuste o `.env` e `docker compose up -d`. |
| Login sempre 401 | Confirme `SEED_ADMIN_EMAIL`/`SEED_ADMIN_PASSWORD` do `.env` (o seed só roda com a base vazia — se já rodou com outra senha, `docker compose down -v` recria). |
| Swagger/`/auth` pedindo login | Não deveria — são públicos. Se acontecer, o profile `prod` não subiu; cheque `SPRING_PROFILES_ACTIVE`. |

---

## Resumo dos arquivos deste deploy

| Arquivo | Papel |
|---|---|
| `backend/Dockerfile` | build multi-stage do jar → imagem JRE 21 |
| `backend/src/main/resources/application-prod.yml` | profile `prod`: Postgres via env, `forward-headers`, health probes |
| `deploy/docker-compose.yml` | postgres + api + cloudflared |
| `deploy/.env.example` | modelo das variáveis (copie para `.env`, nunca versione) |
| `dashboard/src/environments/environment.prod.ts` | `apiBaseUrl` de produção (usado no build `--configuration production`) |
