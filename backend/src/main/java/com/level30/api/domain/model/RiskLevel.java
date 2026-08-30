package com.level30.api.domain.model;

import com.fasterxml.jackson.annotation.JsonValue;

/**
 * Nível de risco de abandono. Serializado em minúsculas para bater com o contrato
 * atual do Worker (campo {@code riskLevel} da recomendação) e com o Dart RiskLevel.
 */
public enum RiskLevel {
    LOW,
    MEDIUM,
    HIGH,
    CRITICAL;

    @JsonValue
    public String toJson() {
        return name().toLowerCase();
    }

    public static RiskLevel fromString(String value) {
        return RiskLevel.valueOf(value.trim().toUpperCase());
    }
}
