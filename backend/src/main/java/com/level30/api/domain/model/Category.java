package com.level30.api.domain.model;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonValue;

/**
 * Categoria de desafio.
 *
 * <p>Contrato congelado: o app Flutter (ChallengeCategory.values.byName) e o Worker atual
 * usam os nomes em <b>minúsculas</b>. Persistimos em MAIÚSCULAS (EnumType.STRING) e
 * serializamos/desserializamos em minúsculas via {@link JsonValue}/{@link JsonCreator}.
 */
public enum Category {
    HEALTH,
    STUDY,
    PRODUCTIVITY,
    MINDFULNESS,
    FITNESS;

    @JsonValue
    public String toJson() {
        return name().toLowerCase();
    }

    @JsonCreator
    public static Category fromJson(String value) {
        if (value == null) {
            throw new IllegalArgumentException("Categoria ausente.");
        }
        try {
            return Category.valueOf(value.trim().toUpperCase());
        } catch (IllegalArgumentException ex) {
            throw new IllegalArgumentException("Categoria invalida: " + value);
        }
    }
}
