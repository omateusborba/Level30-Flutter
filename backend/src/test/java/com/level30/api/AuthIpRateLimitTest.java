package com.level30.api;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

/** A1 — rate limit por IP em /auth/** (filtro). Contexto proprio, limite 3. */
@SpringBootTest(properties = "app.security.auth-rate-limit.max-requests=3")
@AutoConfigureMockMvc
@ActiveProfiles("test")
@DirtiesContext
class AuthIpRateLimitTest {

    @Autowired
    MockMvc mvc;

    @Test
    void acimaDe3RequisicoesNaJanela_retorna429() throws Exception {
        for (int i = 1; i <= 3; i++) {
            mvc.perform(post("/auth/login").contentType(MediaType.APPLICATION_JSON)
                            .content("{\"email\":\"x" + i + "@test.com\",\"password\":\"whatever1\"}"))
                    .andExpect(status().isUnauthorized());
        }
        mvc.perform(post("/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"x4@test.com\",\"password\":\"whatever1\"}"))
                .andExpect(status().isTooManyRequests())
                .andExpect(header().exists("Retry-After"));
    }
}
