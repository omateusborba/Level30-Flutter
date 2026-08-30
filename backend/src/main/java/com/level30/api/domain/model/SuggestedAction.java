package com.level30.api.domain.model;

/**
 * Ação sugerida pelo motor de risco. Espelha o enum SuggestedAction do Dart
 * (lib/data/model/risk_assessment.dart).
 */
public enum SuggestedAction {
    NONE("Continue assim! Voce esta indo muito bem."),
    SEND_REMINDER("Nao esqueca do seu desafio de hoje!"),
    SEND_MOTIVATION("Voce chegou ate aqui - nao desista agora!"),
    SUGGEST_REPLAN("Que tal reajustar o ritmo? Recomecar e vencer."),
    CELEBRATE_MILESTONE("Marco atingido! Voce e incrivel!");

    private final String message;

    SuggestedAction(String message) {
        this.message = message;
    }

    public String getMessage() {
        return message;
    }
}
