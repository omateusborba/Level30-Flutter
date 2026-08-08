# Requirements — Prontidão do protótipo Level30

Origem: relatório multiagente (Scanner + PO + UX/UI + Design), 08/08/2026, sobre o estado do app antes da entrega do Enterprise Challenge FIAP 2026 (Fase 4, avaliado pela Leroy Merlin). Cada item abaixo é rastreável ao achado correspondente do relatório.

## R1 — Persistência de dados de negócio

**Como** estudante usando o Level30
**Quero** que meus desafios, XP e perfil continuem salvos após fechar o app
**Para que** meu progresso não se perca e a demonstração mostre continuidade real

```gherkin
Dado que completei um desafio e ganhei XP
Quando fecho e reabro o app
Então meu XP total, meus desafios (ativos e concluídos) e meu perfil permanecem idênticos

Dado que é a primeira execução do app (sem dados salvos ainda)
Quando abro o app
Então vejo os 5 desafios padrão e o perfil inicial, como hoje
```

Notas técnicas: reaproveitar o padrão SharedPreferences já validado em `NotificationProvider`; serializar `List<Challenge>` e `UserProfile` como JSON.

## R2 — XP diário não pode "vazar"

**Como** estudante completando um desafio
**Quero** que a soma do XP ganho dia a dia bata exatamente com o XP prometido na criação
**Para que** o sistema de recompensa seja confiável

```gherkin
Dado um desafio com xpReward=300 e totalDays=7
Quando completo os 7 dias, um de cada vez
Então a soma de todo o XP creditado ao meu perfil é exatamente 300, não menos
```

Causa raiz: cada dia creditava `xpReward ~/ totalDays` (divisão inteira), perdendo o resto ao longo do desafio.

## R3 — Honestidade sobre "IA" vs. regras determinísticas

**Como** avaliador da banca
**Quero** que o app não alegue "IA" onde há um sistema de regras determinísticas
**Para** avaliar o projeto com uma alegação tecnicamente correta, no ano em que o tema da disciplina é IA

```gherkin
Dado que vejo a sugestão de risco no Detalhe do Desafio
Quando leio o rótulo do card
Então ele não usa "IA" nem o emoji de robô sem indicar que é um cálculo de regras (inatividade, progresso, streak)

Dado que leio o README
Quando chego à seção do motor de risco
Então a descrição diz claramente que é um sistema de regras/heurísticas, não aprendizado de máquina
```

## R4 — Mapa: posição do desafio é ilustrativa, não geolocalização real

**Como** usuário/avaliador na tela de Mapa
**Quero** saber quando a posição de um desafio é ilustrativa
**Para** não confundir dado sintético com dado real de geolocalização

```gherkin
Dado que estou na tela do Mapa
Quando vejo os marcadores de desafios
Então a legenda indica que a posição é calculada a partir da minha localização real, não uma geolocalização própria de cada desafio
```

## R5 — Preview em tempo real ao criar desafio

```gherkin
Dado que estou preenchendo o formulário de criação de desafio
Quando digito no campo de título
Então a pré-visualização abaixo atualiza a cada tecla, sem precisar mexer em outro campo
```

## R6 — Contraste do indicador de risco

```gherkin
Dado um desafio com risco Alto ou Crítico
Quando vejo o badge de risco em qualquer tela
Então o texto do badge tem contraste ≥ 4.5:1 contra seu fundo (WCAG AA)
```

## R7 — Cores de categoria não competem com cores de risco

```gherkin
Dado um ChallengeCard de categoria Saúde, Produtividade ou Fitness
Quando o risco desse desafio é Baixo, Alto ou Crítico respectivamente
Então a cor da categoria não é a mesma cor usada para aquele nível de risco
```

## R8 — Botão de tema não finge ser funcional

```gherkin
Dado que estou na tela de Perfil
Quando olho para o controle de tema na AppBar
Então ele não parece um toggle interativo (ícone/estado clicável) já que não alterna nada — o app é sempre dark por identidade de marca
```

## R9 — Sem código morto visível no fluxo de estado

```gherkin
Dado o grafo de providers do app
Quando um novo desenvolvedor (ou a banca, se abrir o repositório) inspeciona o main.dart
Então todo provider registrado é de fato lido por alguma tela
```

Achado: `RiskProvider` é registrado mas nunca lido — `ChallengeProvider.getRisk()` instancia seu próprio `RiskEngine`.

## R10 — Clima da Home reflete o comportamento documentado no código

```gherkin
Dado o comentário "Tenta localização; fallback para São Paulo" em home_screen.dart
Quando o app carrega o card de clima
Então ele de fato tenta obter a localização real do dispositivo antes de usar o fallback fixo
```

## R11 — Sem affordance de "desfazer" que não desfaz

```gherkin
Dado que exclui um desafio via swipe na Home
Quando vejo o snackbar de confirmação
Então não há um botão de ação que aparenta reverter a exclusão sem de fato reverter
```

## R12 — Borda de componentes com contraste mínimo de UI

```gherkin
Dado qualquer card, chip ou input com borda decorativa
Quando comparo a cor da borda com o fundo ao redor
Então o contraste é ≥ 3:1 (WCAG 1.4.11, componentes não-textuais)
```

Achado: `AppColors.primary` (#1A3A5C) reaproveitado como borda tem contraste 1.57:1 contra `surface`.

## R13 — Paleta consistente no Mapa e nos Marcos do Perfil

```gherkin
Dado as telas de Mapa e a seção "Marcos Atingidos" do Perfil
Quando comparo as cores usadas com o restante do app
Então elas vêm da paleta `AppColors`, não de `Colors.blue/red/amber` do Material puro
```

## R14 — Ícone do app não ganha fundo branco no Android

```gherkin
Dado o ícone adaptativo gerado pelo flutter_launcher_icons para Android
Quando o launcher aplica a máscara adaptativa
Então o fundo usado é um tom da paleta dark do app, não o branco padrão
```

## Fora de escopo (Won't have nesta entrega)

- Autenticação real (login com senha/backend) — fora do escopo pedagógico do desafio.
- Substituir o motor de regras por ML/LLM real — esforço de sprint inteira; declarar como roadmap futuro.
- Cobertura completa de testes de widget/provider — o núcleo mais crítico (RiskEngine) já está coberto.
- Backend/persistência em nuvem — SharedPreferences local já demonstra o conceito.
- Unificação completa da escala tipográfica e de `border-radius` — polimento cosmético amplo, menor prioridade e maior risco de regressão visual sem verificação ao vivo.
