package com.level30.api.repository;

import com.level30.api.domain.model.Challenge;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ChallengeRepository extends JpaRepository<Challenge, UUID> {

    List<Challenge> findByUserIdOrderByCreatedAtDesc(UUID userId);

    Optional<Challenge> findByIdAndUserId(UUID id, UUID userId);

    long countByUserId(UUID userId);
}
