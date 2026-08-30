package com.level30.api.domain.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.LocalDate;
import java.util.Map;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/** B1/B3 — foto diária da distribuição de risco do programa. Uma linha por dia. */
@Entity
@Table(name = "risk_snapshots")
@Getter
@Setter
@NoArgsConstructor
public class RiskSnapshot {

    @Id
    @Column(name = "snapshot_on", nullable = false, updatable = false)
    private LocalDate snapshotOn;

    @Column(nullable = false)
    private int low;

    @Column(nullable = false)
    private int medium;

    @Column(nullable = false)
    private int high;

    @Column(nullable = false)
    private int critical;

    public static RiskSnapshot of(LocalDate day, Map<RiskLevel, Integer> dist) {
        RiskSnapshot s = new RiskSnapshot();
        s.snapshotOn = day;
        s.apply(dist);
        return s;
    }

    public void apply(Map<RiskLevel, Integer> dist) {
        this.low = dist.getOrDefault(RiskLevel.LOW, 0);
        this.medium = dist.getOrDefault(RiskLevel.MEDIUM, 0);
        this.high = dist.getOrDefault(RiskLevel.HIGH, 0);
        this.critical = dist.getOrDefault(RiskLevel.CRITICAL, 0);
    }
}
