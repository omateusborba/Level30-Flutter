package com.level30.api.repository;

import com.level30.api.domain.model.RiskSnapshot;
import java.time.LocalDate;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface RiskSnapshotRepository extends JpaRepository<RiskSnapshot, LocalDate> {

    List<RiskSnapshot> findBySnapshotOnGreaterThanEqualOrderBySnapshotOnAsc(LocalDate desde);
}
