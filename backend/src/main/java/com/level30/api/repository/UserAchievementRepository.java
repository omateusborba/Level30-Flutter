package com.level30.api.repository;

import com.level30.api.domain.model.UserAchievement;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface UserAchievementRepository
        extends JpaRepository<UserAchievement, UserAchievement.Key> {

    List<UserAchievement> findByUserId(UUID userId);

    @Query("select a.achievementId from UserAchievement a where a.userId = :userId")
    Set<String> idsByUser(@Param("userId") UUID userId);
}
