package com.level30.api.domain.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.IdClass;
import jakarta.persistence.Table;
import java.io.Serializable;
import java.time.Instant;
import java.util.Objects;
import java.util.UUID;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(name = "user_achievements")
@IdClass(UserAchievement.Key.class)
@Getter
@Setter
@NoArgsConstructor
public class UserAchievement {

    @Id
    @Column(name = "user_id", nullable = false, updatable = false)
    private UUID userId;

    @Id
    @Column(name = "achievement_id", nullable = false, updatable = false, length = 40)
    private String achievementId;

    @Column(name = "unlocked_at", nullable = false, updatable = false)
    private Instant unlockedAt;

    public static UserAchievement of(UUID userId, Achievement a) {
        UserAchievement e = new UserAchievement();
        e.userId = userId;
        e.achievementId = a.id();
        e.unlockedAt = Instant.now();
        return e;
    }

    public record Key(UUID userId, String achievementId) implements Serializable {
        @Override
        public boolean equals(Object o) {
            return o instanceof Key k
                    && Objects.equals(userId, k.userId)
                    && Objects.equals(achievementId, k.achievementId);
        }
    }
}
