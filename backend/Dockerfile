# syntax=docker/dockerfile:1

# ─── build ───────────────────────────────────────────────────────────────
# O jar é portável (bytecode), então roda igual em x86 e ARM (VM Oracle Ampere).
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /app
COPY pom.xml .
RUN mvn -q -B dependency:go-offline
COPY src ./src
RUN mvn -q -B clean package -DskipTests

# ─── runtime ─────────────────────────────────────────────────────────────
FROM eclipse-temurin:21-jre AS runtime
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/* \
    && useradd -r -u 1001 spring
COPY --from=build /app/target/level30-api-*.jar app.jar
USER spring
EXPOSE 8080

# Limita a heap ao tamanho da fatia de VM (ajuste MaxRAMPercentage se necessário).
ENV JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=60 -XX:+UseSerialGC"
ENV SPRING_PROFILES_ACTIVE=prod

HEALTHCHECK --interval=30s --timeout=5s --start-period=40s --retries=3 \
  CMD ["sh","-c","curl -fsS http://localhost:8080/actuator/health || exit 1"]

ENTRYPOINT ["java","-jar","app.jar"]
