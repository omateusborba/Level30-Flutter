package com.level30.api.repository;

import com.level30.api.domain.model.RefreshToken;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

public interface RefreshTokenRepository extends JpaRepository<RefreshToken, UUID> {

    List<RefreshToken> findByUserIdOrderByIssuedAtDesc(UUID userId);

    /**
     * Consumo atomico: marca o token como usado somente se ele ainda estava
     * ativo. rowcount 0 => reuso, revogado ou expirado. Cada chamada em sua
     * propria transacao (imune a rollback de excecao no chamador).
     */
    @Transactional
    @Modifying
    @Query("""
            update RefreshToken t set t.usedAt = :now
            where t.jti = :jti and t.usedAt is null and t.revokedAt is null and t.expiresAt > :now
            """)
    int consume(@Param("jti") UUID jti, @Param("now") Instant now);

    @Transactional
    @Modifying
    @Query("update RefreshToken t set t.revokedAt = :now where t.familyId = :familyId and t.revokedAt is null")
    void revokeFamily(@Param("familyId") UUID familyId, @Param("now") Instant now);

    @Transactional
    @Modifying
    @Query("delete from RefreshToken t where t.expiresAt < :cutoff")
    int deleteExpiredBefore(@Param("cutoff") Instant cutoff);
}
