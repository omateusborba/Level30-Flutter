package com.level30.api.service;

import com.level30.api.domain.Leveling;
import com.level30.api.domain.model.Challenge;
import com.level30.api.domain.model.User;
import com.level30.api.dto.request.ChatRequest;
import com.level30.api.dto.response.ChatResponse;
import com.level30.api.repository.ChallengeRepository;
import java.util.List;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Monta o contexto do "Guia do Level30" com os dados reais do jogador e delega
 * a geração ao {@link AiGatewayService}. Mesma lógica de systemPrompt de
 * {@code server/src/routes/chat.ts}, agora com o Spring como fonte dos dados.
 */
@Service
public class ChatService {

    private final ChallengeRepository challenges;
    private final UserService userService;
    private final AiGatewayService aiGateway;

    public ChatService(ChallengeRepository challenges, UserService userService,
                       AiGatewayService aiGateway) {
        this.challenges = challenges;
        this.userService = userService;
        this.aiGateway = aiGateway;
    }

    @Transactional(readOnly = true)
    public ChatResponse chat(UUID userId, ChatRequest req) {
        User user = userService.load(userId);
        List<Challenge> lista = challenges.findByUserIdOrderByCreatedAtDesc(userId);
        return aiGateway.chat(buildSystemContext(user, lista), req);
    }

    private String buildSystemContext(User user, List<Challenge> lista) {
        int level = Leveling.level(user.getTotalXp());
        String rank = Leveling.rank(user.getTotalXp());

        StringBuilder sb = new StringBuilder();
        sb.append("Voce e o Guia do Level30, companheiro de jornada num app de gamificacao de habitos ")
          .append("em formato RPG (desafios de 30 dias, XP, niveis, sequencias/streaks, marcos). ")
          .append("Personalidade: amigavel, animado e ludico, como um mentor de RPG torcendo pelo jogador. ")
          .append("Use linguagem de jogo e ao menos um emoji por resposta. Respostas curtas (3-4 frases), em portugues. ")
          .append("Pode usar **negrito** e listas com '- '. Baseie a resposta nos dados reais do jogador abaixo.\n\n");

        sb.append("Jogador: ").append(user.getName())
          .append(", nivel ").append(level).append(" (").append(rank).append("), ")
          .append(user.getTotalXp()).append(" XP total.\n\n");

        sb.append("Desafios do jogador:\n");
        if (lista.isEmpty()) {
            sb.append("O jogador ainda nao criou nenhum desafio - incentive com carinho a criar o primeiro.");
        } else {
            for (Challenge c : lista) {
                int pct = c.getTotalDays() > 0
                        ? Math.round((float) c.getCurrentDay() / c.getTotalDays() * 100)
                        : 0;
                String alerta = (c.getStreak() == 0 && c.getCurrentDay() > 0)
                        ? " (sequencia quebrada, atencao)" : "";
                sb.append("- \"").append(c.getTitle()).append("\" [").append(c.getCategory().toJson())
                  .append("]: dia ").append(c.getCurrentDay()).append('/').append(c.getTotalDays())
                  .append(" (").append(pct).append("% concluido), sequencia de ")
                  .append(c.getStreak()).append(" dia(s)").append(alerta).append('\n');
            }
        }
        return sb.toString();
    }
}
