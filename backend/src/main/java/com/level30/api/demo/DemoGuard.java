package com.level30.api.demo;

import java.util.List;
import java.util.Locale;

/**
 * Trava de segurança do seed da demo: ele apaga dados, então só roda em banco local ou de demo.
 * Local = H2, localhost/127.0.0.1/::1/host.docker.internal; demo = URL que contém "demo".
 */
public final class DemoGuard {

    private static final List<String> MARCAS_LOCAIS =
            List.of("localhost", "127.0.0.1", "[::1]", "host.docker.internal", "demo");

    private DemoGuard() { }

    public static boolean permitido(String jdbcUrl) {
        if (jdbcUrl == null || jdbcUrl.isBlank()) {
            return false;
        }
        String url = jdbcUrl.toLowerCase(Locale.ROOT);
        return url.startsWith("jdbc:h2:") || MARCAS_LOCAIS.stream().anyMatch(url::contains);
    }

    /** @throws IllegalStateException se a URL não for local nem de demo (a mensagem não revela credenciais). */
    public static void exigir(String banco, String jdbcUrl) {
        if (!permitido(jdbcUrl)) {
            throw new IllegalStateException("Seed da demo recusado: o datasource " + banco
                    + " não é local nem de demo. Nada foi apagado.");
        }
    }
}
