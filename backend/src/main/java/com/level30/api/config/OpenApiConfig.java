package com.level30.api.config;

import io.swagger.v3.oas.models.Components;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.security.SecurityRequirement;
import io.swagger.v3.oas.models.security.SecurityScheme;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class OpenApiConfig {

    private static final String BEARER = "bearerAuth";

    @Bean
    OpenAPI level30OpenAPI() {
        return new OpenAPI()
                .info(new Info()
                        .title("Level30 / Smart HAS API")
                        .description("Nucleo de dominio da Fase 5 — auth, desafios, risco, IA e painel admin. "
                                + "Contrato JSON congelado: consumido pelo app Flutter e pelo dashboard Angular.")
                        .version("1.0.0"))
                .addSecurityItem(new SecurityRequirement().addList(BEARER))
                .components(new Components().addSecuritySchemes(BEARER, new SecurityScheme()
                        .type(SecurityScheme.Type.HTTP)
                        .scheme("bearer")
                        .bearerFormat("JWT")));
    }
}
