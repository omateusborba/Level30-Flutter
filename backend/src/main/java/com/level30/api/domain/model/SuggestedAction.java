package com.level30.api.domain.model;

/**
 * Ação sugerida pelo motor de risco. Espelha o enum SuggestedAction do Dart
 * (lib/data/model/risk_assessment.dart).
 */
public enum SuggestedAction {
    NONE("Continue assim! Voce esta indo muito bem."),
    SEND_REMINDER("Não esqueça do seu desafio de hoje!"),
    SEND_MOTIVATION("Você chegou até aqui — não desista agora!"),
    SUGGEST_REPLAN("Que tal reajustar o ritmo? Recomeçar é vencer."),
    CELEBRATE_MILESTONE("🎉 Marco atingido! Você é incrível!");

    private final String message;

    SuggestedAction(String message) {
        this.message = message;
    }

    public String getMessage() {
        return message;
    }
}
