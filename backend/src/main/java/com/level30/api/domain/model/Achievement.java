package com.level30.api.domain.model;

/**
 * F4 · Catálogo de conquistas. O id (minúsculo, estável) é o que vai para o banco
 * e para o JSON — nome e descrição são apresentação.
 */
public enum Achievement {
    PRIMEIRO_PASSO("primeiro_passo", "Primeiro Passo", "Sua primeira conclusão"),
    SEMANA_CHEIA("semana_cheia", "Semana Cheia", "Uma sequência de 7 dias"),
    CONSTANCIA("constancia", "Constância", "Uma sequência de 21 dias"),
    MARATONISTA("maratonista", "Maratonista", "Um desafio concluído até o fim"),
    POLIGLOTA("poliglota", "Multidisciplinar", "Desafios ativos em 3 categorias distintas"),
    MADRUGADOR("madrugador", "Madrugador", "5 conclusões antes das 8h"),
    RESILIENTE("resiliente", "Resiliente", "Retomar um desafio após zerar a sequência"),
    VETERANO("veterano", "Veterano", "Chegar ao nível 5");

    private final String id;
    private final String nome;
    private final String descricao;

    Achievement(String id, String nome, String descricao) {
        this.id = id;
        this.nome = nome;
        this.descricao = descricao;
    }

    public String id() {
        return id;
    }

    public String nome() {
        return nome;
    }

    public String descricao() {
        return descricao;
    }

    public static Achievement byId(String id) {
        for (Achievement a : values()) {
            if (a.id.equals(id)) {
                return a;
            }
        }
        throw new IllegalArgumentException("Conquista desconhecida: " + id);
    }
}
