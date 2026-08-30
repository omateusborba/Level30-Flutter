package com.level30.api.domain;

/**
 * Progressão de nível/rank. <b>Espelho</b> de {@code UserProfile} do Flutter
 * (lib/data/model/user_profile.dart) e de {@code levelInfo()} em server/src/routes/chat.ts.
 * 500 XP por nível.
 */
public final class Leveling {

    private static final String[] RANKS = {
            "Iniciante", "Aprendiz", "Intermediario", "Avancado", "Especialista"
    };

    private Leveling() {
    }

    public static int level(int totalXp) {
        return totalXp / 500 + 1;
    }

    public static String rank(int totalXp) {
        int level = level(totalXp);
        return level >= 1 && level <= RANKS.length ? RANKS[level - 1] : "Lendario";
    }
}
