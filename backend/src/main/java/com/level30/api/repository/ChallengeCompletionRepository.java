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

    /** Contagem de conclusões por dia — alimenta o heatmap. */
    @Query("""
            select c.completedOn as data, count(c) as quantidade
            from ChallengeCompletion c
            where c.userId = :userId and c.completedOn >= :desde
            group by c.completedOn
            order by c.completedOn
            """)
    List<AtividadeDiaView> atividadePorDia(@Param("userId") UUID userId,
                                           @Param("desde") LocalDate desde);

    interface AtividadeDiaView {
        LocalDate getData();

        long getQuantidade();
    }
}
