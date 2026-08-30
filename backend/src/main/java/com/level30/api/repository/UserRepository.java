package com.level30.api.repository;

import com.level30.api.domain.model.Role;
import com.level30.api.domain.model.User;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface UserRepository extends JpaRepository<User, UUID> {

    Optional<User> findByEmail(String email);

    boolean existsByEmail(String email);

    long countByRole(Role role);

    @Query("select coalesce(sum(u.totalXp), 0) from User u")
    long somaTotalXp();

    /** XP de cada estudante — alimenta o histograma de nível (B4). */
    @Query("select u.totalXp from User u where u.role = com.level30.api.domain.model.Role.USER")
    List<Integer> xpDosEstudantes();

    /** id + data de cadastro dos estudantes — alimenta a retenção por coorte (B2). */
    @Query("select u.id as id, u.createdAt as criadoEm from User u "
            + "where u.role = com.level30.api.domain.model.Role.USER")
    List<CadastroView> cadastrosDeEstudantes();

    interface CadastroView {
        UUID getId();

        Instant getCriadoEm();
    }
}
