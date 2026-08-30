package com.level30.api.repository;

import com.level30.api.domain.model.ChallengeCompletion;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface ChallengeCompletionRepository
        extends JpaRepository<ChallengeCompletion, UUID> {

    List<ChallengeCompletion> findByChallengeIdOrderByDayNumberAsc(UUID challengeId);

    List<ChallengeCompletion> findByUserId(UUID userId);

    long countByUserId(UUID userId);

    List<ChallengeCompletion> findByUserIdAndCompletedOnGreaterThanEqualOrderByCompletedOnAsc(
            UUID userId, LocalDate desde);

    long countByChallengeId(UUID challengeId);

    /** Conclusões e XP por dia — alimenta o heatmap e o "Meu Progresso" (B6). */
    @Query("""
            select c.completedOn as data, count(c) as quantidade,
                   coalesce(sum(c.xpDelta), 0) as xp
            from ChallengeCompletion c
            where c.userId = :userId and c.completedOn >= :desde
            group by c.completedOn
            order by c.completedOn
            """)
    List<AtividadeXpView> atividadePorDia(@Param("userId") UUID userId,
                                          @Param("desde") LocalDate desde);

    // ---- B1/B2: métricas agregadas do programa ----

    @Query("""
            select c.completedOn as data, count(c) as quantidade
            from ChallengeCompletion c where c.completedOn >= :desde
            group by c.completedOn
            """)
    List<AtividadeDiaView> conclusoesPorDia(@Param("desde") LocalDate desde);

    @Query("""
            select c.completedOn as data, count(distinct c.userId) as quantidade
            from ChallengeCompletion c where c.completedOn >= :desde
            group by c.completedOn
            """)
    List<AtividadeDiaView> usuariosAtivosPorDia(@Param("desde") LocalDate desde);

    @Query("""
            select c.completedOn as data, coalesce(sum(c.xpDelta), 0) as quantidade
            from ChallengeCompletion c where c.completedOn >= :desde
            group by c.completedOn
            """)
    List<AtividadeDiaView> xpPorDia(@Param("desde") LocalDate desde);

    /** completedOn (dia da semana) + createdAt (hora aproximada) para o mapa de padrões. */
    @Query("select c.completedOn as data, c.createdAt as instante from ChallengeCompletion c")
    List<PadraoView> paraPadroes();

    /** userId + dia de todas as conclusões — alimenta a retenção por coorte (B2). */
    @Query("select c.userId as userId, c.completedOn as data from ChallengeCompletion c")
    List<UsuarioDiaView> todasConclusoes();

    interface AtividadeDiaView {
        LocalDate getData();

        long getQuantidade();
    }

    interface AtividadeXpView {
        LocalDate getData();

        long getQuantidade();

        long getXp();
    }

    interface PadraoView {
        LocalDate getData();

        java.time.Instant getInstante();
    }

    interface UsuarioDiaView {
        UUID getUserId();

        LocalDate getData();
    }
}
