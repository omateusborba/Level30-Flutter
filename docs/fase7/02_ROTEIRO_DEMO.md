# Roteiro de demonstração (Fase 7)

Tudo aqui foi executado e validado em 2026-10-28 contra Oracle Free 23 (Docker), API local e o Worker de IA real.
Os números dependem só do calendário relativo: o seed gera o mesmo plano em qualquer dia, mas **rode o reset no
mesmo dia da gravação** (o aluno do roteiro depende de "hoje").

## 0. Preparação (uma vez)

```bash
# Oracle local (senhas: use as suas, via variáveis; nada de senha em arquivo versionado)
ORACLE_SYS_PASSWORD=... ORACLE_USER=level30 ORACLE_PASSWORD=... docker compose -f docker-compose.oracle.yml up -d
# schema e objetos (NÃO rode 02_carga_simulada: o seed da demo substitui a carga da Fase 6)
for f in 01_ddl 03_plsql 06_pkg_engajamento 07_trg_audit_conclusao 08_trg_status_alerta 09_pkg_consultas 10_consolidacao; do
  docker exec -i -w /scripts level30-oracle sqlplus -S -L "$ORACLE_USER/$ORACLE_PASSWORD@//localhost/FREEPDB1" @$f.sql
done
```

## 1. Reset (comando único)

```bash
ORACLE_URL=jdbc:oracle:thin:@//localhost:1521/FREEPDB1 ORACLE_USER=level30 ORACLE_PASSWORD=... \
  scripts/demo-reset.sh
```

Reseta e popula PostgreSQL/H2 **e** Oracle com as mesmas 16 pessoas e os mesmos IDs (90 dias de histórico, XP,
conquistas, risco materializado e 90 snapshots), confere a paridade entre os bancos e falha (código 1) se divergirem.
A saída termina com `DEMO-SEED OK: Resultado[alunos=16, desafios=36, conclusoes=697, ... divergencias=[]]`.
O script **recusa** qualquer banco que não seja local ou de demo (H2, localhost, 127.0.0.1, URL com "demo").
Com `ORACLE_DOCKER_CONTAINER=level30-oracle` ele também roda o `98_limpa_residuo_testes.sql`.

Suba a API com a camada Oracle e a IA ligadas (valores só por ambiente, nunca em arquivo):

```bash
LEVEL30_ORACLE_ENABLED=true ORACLE_URL=... ORACLE_USER=... ORACLE_PASSWORD=... \
AI_WORKER_URL=... AI_SERVICE_TOKEN=... java -jar backend/target/level30-api-1.0.0.jar
```

Logins: dashboard `admin@level30.app` (senha do seu `SEED_ADMIN_PASSWORD`; padrão de dev `admin1234`);
app: qualquer `*@level30.app` com a senha `estudante1` (ex.: `ana@level30.app`).

## 2. Auditoria completa (I, U e D)

1. No app, logada como Ana, conclua o dia de um desafio ativo (gera o **INSERT**).
2. Gere **UPDATE** e **DELETE** na réplica Oracle:
   ```bash
   docker exec -i -w /scripts level30-oracle sqlplus -S -L "$ORACLE_USER/$ORACLE_PASSWORD@//localhost/FREEPDB1" @97_demo_auditoria.sql
   ```
   (UPDATE: +5 XP na última conclusão da Elisa Castro; DELETE: a conclusão mais antiga do Henrique Dias.)
3. Dashboard › **Oracle** › *Auditoria de conclusões* › **Atualizar**: aparecem Inclusão, Alteração (`XP 17 → 22`) e
   Exclusão, cada uma com **ver JSON** (antes/depois formatados).

O `97` só altera o Oracle; depois da gravação rode o reset de novo para voltar à base consistente.

## 3. Trigger ao vivo (alerta abre e fecha sozinho)

Aluna **Larissa Freitas** (`larissa@level30.app`): 1 desafio de 30 dias iniciado há 29 dias, **14 conclusões e
nenhuma hoje = 46,7 % < 50 %**.

1. Dashboard › Oracle › *Alertas abertos*: há `ADESAO_BAIXA · MEDIA · Adesão de 30 dias em 46,7%, abaixo da meta de 50%`.
2. No app, login como Larissa e **conclua o dia uma vez** (dia 15). **Basta 1 conclusão**: 15/30 = 50,0 %, e o
   limite é "abaixo de 50 %", então o alerta fecha. (Validado: `fn_taxa_adesao` foi de 46,67 para 50.)
3. Dashboard › Oracle › **Verificar inatividade agora** (ou recarregar): o alerta `ADESAO_BAIXA` da Larissa sumiu
   dos abertos. Só dá para concluir **uma vez por dia por desafio** (409 se repetir), por isso 1 é o máximo possível
   hoje; para repetir o roteiro, rode o reset.

## 4. Dynamic SQL

Dashboard › Oracle › *Consulta filtrada*: **Nível mínimo 2**, **Adesão mínima 50**, **Ordenar por NOME**, **ASC** →
**9 alunos** (Ana Souza, Bruno Lima, Carla Dias, Diego Rocha, Elisa Castro, Felipe Nunes, Gabriela Alves,
Henrique Dias, João Pedro Melo).

Injeção (o PL/SQL também a barra, ORA-20050; aqui responde o Java, que valida antes):

```bash
curl -s -w ' [HTTP %{http_code}]\n' -H "Authorization: Bearer $TOKEN_ADMIN" -G http://localhost:8080/admin/engajamento \
  --data-urlencode 'ordenarPor=X;DROP'
# {"status":400,"error":"ordenarPor inválido. Use ADESAO, STREAK, NOME ou NIVEL.",...} [HTTP 400]
```

Direto no Oracle (SQL Developer): `EXEC :rc := pkg_l30_consultas.fn_engajamento_filtrado(p_ordenar_por => 'X; DROP TABLE l30_users');`
→ `ORA-20050`.

## 5. Assistente (resposta da IA)

App › ícone de chat (canto superior direito) › pergunte **"Como está meu risco de abandono?"**. Com `AI_WORKER_URL` e
`AI_SERVICE_TOKEN` definidos a resposta vem do Worker (validado: HTTP 200 em ~1 s, texto citando os desafios da
Ana). O detalhe de um desafio também passa a trazer a recomendação gerada (`aiGenerated: true`) em vez do
"Sugestão padrão". Sem as variáveis, o log da API avisa na subida: `IA desligada: AI_WORKER_URL não está definida`.
