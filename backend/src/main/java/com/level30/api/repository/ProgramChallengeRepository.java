package com.level30.api.repository;

import com.level30.api.domain.model.ProgramChallenge;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ProgramChallengeRepository extends JpaRepository<ProgramChallenge, UUID> {

    List<ProgramChallenge> findByActiveTrueOrderByCreatedAtDesc();

    List<ProgramChallenge> findAllByOrderByCreatedAtDesc();
}
