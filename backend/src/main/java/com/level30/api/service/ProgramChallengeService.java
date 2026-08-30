package com.level30.api.service;

import com.level30.api.domain.model.Challenge;
import com.level30.api.domain.model.ProgramChallenge;
import com.level30.api.domain.model.User;
import com.level30.api.dto.request.ProgramChallengeRequest;
import com.level30.api.dto.response.ChallengeResponse;
import com.level30.api.dto.response.ProgramChallengeResponse;
import com.level30.api.exception.RecursoNaoEncontradoException;
import com.level30.api.exception.RegraNegocioException;
import com.level30.api.repository.ChallengeRepository;
import com.level30.api.repository.ProgramChallengeRepository;
import com.level30.api.repository.UserRepository;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * C3 · Desafios do programa (F3). A coordenação publica modelos; o aluno adota
 * um modelo e ganha um desafio pessoal. Resolve a ambiguidade do form de /admin (D6).
 */
@Service
public class ProgramChallengeService {

    private final ProgramChallengeRepository programs;
    private final ChallengeRepository challenges;
    private final UserRepository users;
    private final RiskMaterializationService risk;

    public ProgramChallengeService(ProgramChallengeRepository programs, ChallengeRepository challenges,
                                   UserRepository users, RiskMaterializationService risk) {
        this.programs = programs;
        this.challenges = challenges;
        this.users = users;
        this.risk = risk;
    }

    // ---- visão do aluno ----

    @Transactional(readOnly = true)
    public List<ProgramChallengeResponse> ativos(UUID userId) {
        Set<UUID> adotados = challenges.programIdsAdotadosPor(userId);
        return programs.findByActiveTrueOrderByCreatedAtDesc().stream()
                .map(p -> ProgramChallengeResponse.of(
                        p, challenges.countByProgramChallengeId(p.getId()), adotados.contains(p.getId())))
                .toList();
    }

    @Transactional
    public ChallengeResponse adotar(UUID userId, UUID programId) {
        ProgramChallenge p = programs.findById(programId)
                .orElseThrow(() -> new RecursoNaoEncontradoException("Desafio do programa nao encontrado."));
        if (!p.isActive()) {
            throw new RegraNegocioException("Este desafio do programa nao esta mais disponivel.");
        }
        if (challenges.existsByUserIdAndProgramChallengeId(userId, programId)) {
            throw new RegraNegocioException("Voce ja adotou este desafio.", HttpStatus.CONFLICT);
        }
        User user = users.findById(userId)
                .orElseThrow(() -> new RecursoNaoEncontradoException("Usuario nao encontrado."));

        Challenge c = Challenge.create(user, p.getTitle(), p.getCategory(), p.getDescription(),
                p.getTotalDays(), p.getXpReward());
        c.setProgramChallengeId(p.getId());
        risk.refresh(c);
        challenges.save(c);
        return ChallengeResponse.from(c);
    }

    // ---- visão do admin ----

    @Transactional(readOnly = true)
    public List<ProgramChallengeResponse> listarTodos() {
        return programs.findAllByOrderByCreatedAtDesc().stream()
                .map(p -> ProgramChallengeResponse.of(
                        p, challenges.countByProgramChallengeId(p.getId()), false))
                .toList();
    }

    @Transactional
    public ProgramChallengeResponse criar(ProgramChallengeRequest req, UUID adminId) {
        ProgramChallenge p = programs.save(ProgramChallenge.create(
                req.title().trim(), req.category(), req.description().trim(),
                req.totalDays(), req.xpReward(), adminId));
        return ProgramChallengeResponse.of(p, 0, false);
    }

    @Transactional
    public ProgramChallengeResponse definirAtivo(UUID id, boolean ativo) {
        ProgramChallenge p = programs.findById(id)
                .orElseThrow(() -> new RecursoNaoEncontradoException("Desafio do programa nao encontrado."));
        p.setActive(ativo);
        return ProgramChallengeResponse.of(p, challenges.countByProgramChallengeId(id), false);
    }

    @Transactional
    public void remover(UUID id) {
        if (!programs.existsById(id)) {
            throw new RecursoNaoEncontradoException("Desafio do programa nao encontrado.");
        }
        programs.deleteById(id);
    }
}
