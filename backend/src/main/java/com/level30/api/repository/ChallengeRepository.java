package com.level30.api.repository;

import com.level30.api.domain.model.Category;
import com.level30.api.domain.model.Challenge;
import com.level30.api.domain.model.RiskLevel;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface ChallengeRepository extends JpaRepository<Challenge, UUID> {

    List<Challenge> findByUserIdOrderByCreatedAtDesc(UUID userId);

    Optional<Challenge> findByIdAndUserId(UUID id, UUID userId);

    long countByUserId(UUID userId);

    boolean existsByRiskUpdatedAtIsNull();

    // C3 — desafios do programa
    long countByProgramChallengeId(UUID programChallengeId);

    boolean existsByUserIdAndProgramChallengeId(UUID userId, UUID programChallengeId);

    @Query("select c.programChallengeId from Challenge c where c.user.id = :userId and c.programChallengeId is not null")
    java.util.Set<UUID> programIdsAdotadosPor(@Param("userId") UUID userId);

    // ---- B1: consultas do painel sobre a coluna de risco materializada ----

    /**
     * Lista paginada do painel. Filtros opcionais (null = ignora), ordenada por
     * risco desc, com o usuário carregado no mesmo select (sem N+1).
     */
    @Query(value = """
            select c from Challenge c join fetch c.user u
            where (:riskLevel is null or c.riskLevel = :riskLevel)
              and (:category is null or c.category = :category)
              and (:busca is null
                   or lower(c.title) like :busca
                   or lower(u.name) like :busca
                   or lower(u.email) like :busca)
            order by c.riskScore desc
            """,
            countQuery = """
            select count(c) from Challenge c join c.user u
            where (:riskLevel is null or c.riskLevel = :riskLevel)
              and (:category is null or c.category = :category)
              and (:busca is null
                   or lower(c.title) like :busca
                   or lower(u.name) like :busca
                   or lower(u.email) like :busca)
            """)
    Page<Challenge> pageForAdmin(@Param("riskLevel") RiskLevel riskLevel,
                                 @Param("category") Category category,
                                 @Param("busca") String busca,
                                 Pageable pageable);

    @Query("select count(c) from Challenge c where c.currentDay >= c.totalDays")
    long countConcluidos();

    long countByRiskLevelIn(List<RiskLevel> levels);

    @Query("select coalesce(max(c.streak), 0) from Challenge c")
    int melhorStreak();

    @Query("select c.category as chave, count(c) as quantidade from Challenge c group by c.category")
    List<ContagemView> contagemPorCategoria();

    @Query("select c.riskLevel as chave, count(c) as quantidade from Challenge c group by c.riskLevel")
    List<ContagemView> contagemPorRisco();

    @Query("select c.currentDay as chave, count(c) as quantidade from Challenge c group by c.currentDay")
    List<ContagemView> contagemPorDiaAtual();

    @Query("select c.streak as chave, count(c) as quantidade from Challenge c group by c.streak")
    List<ContagemView> contagemPorStreak();

    @Query("select c.createdAt from Challenge c where c.createdAt >= :cutoff")
    List<Instant> createdAtSince(@Param("cutoff") Instant cutoff);

    interface ContagemView {
        Object getChave();

        long getQuantidade();
    }
}
