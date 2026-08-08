# Requirements — Backend real (auth, banco, IA)

Origem: pedido do usuário para transformar o Level30 num app cliente-servidor de verdade — login real, desafios persistidos em banco, sem seed padrão, e uma recomendação gerada por IA de verdade (gratuita/open source, via Cloudflare Workers AI).

## R1 — Cadastro e login reais

**Como** estudante
**Quero** criar uma conta com e-mail e senha e fazer login de verdade
**Para** ter meus dados vinculados a mim, protegidos por senha, e acessíveis de qualquer instalação do app

```gherkin
Dado que não tenho conta
Quando me cadastro com nome, e-mail e senha válidos
Então minha conta é criada no servidor e recebo um token de sessão válido

Dado que já tenho conta
Quando informo e-mail e senha corretos
Então recebo um token de sessão válido e sou levado para a Home

Dado que informo uma senha incorreta ou e-mail inexistente
Quando tento fazer login
Então vejo uma mensagem de erro clara, sem indicar qual dos dois campos está errado (segurança)

Dado que tento me cadastrar com um e-mail já usado
Quando envio o formulário
Então vejo uma mensagem informando que o e-mail já está cadastrado
```

## R2 — Sessão persistente entre aberturas do app

```gherkin
Dado que fiz login e fechei o app
Quando reabro o app
Então sou levado direto para a Home, sem precisar logar de novo (enquanto o token não expirar)

Dado que meu token expirou ou é inválido
Quando o app faz qualquer chamada à API
Então sou desconectado automaticamente e levado para a tela de login
```

## R3 — Desafios sem seed padrão

```gherkin
Dado que acabei de criar minha conta
Quando entro na Home pela primeira vez
Então vejo uma tela vazia com uma chamada para criar meu primeiro desafio, não uma lista de exemplos
```

## R4 — Desafios persistidos em banco de verdade

```gherkin
Dado que criei, completei um dia ou excluí um desafio
Quando fecho o app, reinstalo ou entro em outro dispositivo com a mesma conta
Então vejo exatamente o mesmo estado — os dados vivem no servidor, não só no dispositivo
```

## R5 — XP correto, calculado no servidor

```gherkin
Dado um desafio com xpReward=300 e totalDays=7
Quando completo os 7 dias, um de cada vez, via API
Então a soma do XP creditado ao meu perfil no servidor é exatamente 300
```

Mesma lógica (delta de `earnedXp`) da correção já feita no cliente, agora como fonte de verdade no backend.

## R6 — Recomendação gerada por IA de verdade

**Como** estudante vendo o detalhe de um desafio
**Quero** uma recomendação escrita por um modelo de IA real, não só uma frase fixa
**Para** ter uma sugestão genuinamente personalizada

```gherkin
Dado que abro o detalhe de um desafio
Quando a recomendação carrega
Então vejo um texto gerado por um modelo de linguagem (Cloudflare Workers AI, modelo open source), rotulado como "Gerado por IA"

Dado que a chamada à IA falha ou expira
Quando a recomendação carrega
Então vejo uma mensagem padrão (mesma lógica de hoje, baseada no nível de risco), rotulada como "Sugestão padrão" — nunca um erro cru ou tela quebrada

Dado o nível de risco de um desafio
Quando a recomendação é gerada
Então o SCORE de risco continua sendo calculado por uma fórmula determinística auditável (mesma do RiskEngine atual) — só o TEXTO passa a ser gerado por IA
```

## R7 — Custo zero

```gherkin
Dado que este é um projeto de faculdade
Quando a infraestrutura é escolhida
Então banco de dados (D1) e IA (Workers AI) usam exclusivamente os tiers gratuitos da Cloudflare, sem exigir cartão de crédito para o uso esperado de uma demonstração
```

## Fora de escopo (Won't have nesta entrega)

- Refresh token / rotação de sessão — JWT de longa duração (30 dias) é suficiente.
- Recuperação de senha.
- Rate limiting / proteção contra bots nos endpoints de auth.
- Testes automatizados do Worker — verificação manual via curl e uso real do app.
- Modo offline / cache local dos desafios — a fonte de verdade é sempre a API.
- Botão "Explorar sem conta" — removido, pois contradiz contas reais com dados persistidos.
