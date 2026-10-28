package com.level30.api.domain.engine;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.within;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.level30.api.domain.model.Category;
import com.level30.api.domain.model.Challenge;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.UUID;
import java.util.stream.Stream;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.MethodSource;

/**
 * Paridade Java x Dart: lê a MESMA fixture de {@code test/risk_parity_test.dart}
 * ({@code test/fixtures/risk_parity.json}). Inclui o caso "Corrida matinal" (97 %, crítico) que
 * aparece no app.
 */
class RiskEngineParityTest {

    private static final Path FIXTURE = Path.of("..", "test", "fixtures", "risk_parity.json");

    private final RiskEngine engine = new RiskEngine();

    static Stream<JsonNode> casos() throws IOException {
        JsonNode raiz = new ObjectMapper().readTree(Files.readString(FIXTURE));
        return Stream.iterate(0, i -> i + 1).limit(raiz.get("casos").size()).map(i -> raiz.get("casos").get(i));
    }

    @ParameterizedTest(name = "{0}")
    @MethodSource("casos")
    void mesmoScoreEFaixaQueODart(JsonNode caso) {
        Challenge c = new Challenge();
        c.setId(UUID.randomUUID());
        c.setTitle("Parity");
        c.setCategory(Category.STUDY);
        c.setDescription("");
        c.setXpReward(100);
        c.setTotalDays(caso.get("totalDays").asInt());
        c.setCurrentDay(caso.get("currentDay").asInt());
        c.setStreak(caso.get("streak").asInt());
        c.setCreatedAt(Instant.now());
        JsonNode dias = caso.get("diasSemAtividade");
        c.setLastActivityAt(dias.isNull() ? null : Instant.now().minus(dias.asInt(), ChronoUnit.DAYS).minus(1, ChronoUnit.HOURS));

        double score = engine.calculateScore(c);

        assertThat(score).isCloseTo(caso.get("scoreEsperado").asDouble(), within(1e-6));
        assertThat(engine.scoreToLevel(score).toJson()).isEqualTo(caso.get("nivelEsperado").asText());
    }
}
