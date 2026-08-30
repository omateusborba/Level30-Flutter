package com.level30.api;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

/**
 * A1 — lockout progressivo por conta. Contexto proprio com rate limit por IP
 * alto (100) para nao mascarar o bloqueio por conta.
 */
@SpringBootTest(properties = "app.security.auth-rate-limit.max-requests=100")
@AutoConfigureMockMvc
@ActiveProfiles("test")
@DirtiesContext
class AuthLockoutTest {

    @Autowired
    MockMvc mvc;
    @Autowired
    ObjectMapper mapper;

    private void signup(String email) throws Exception {
        mvc.perform(post("/auth/signup").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"L\",\"email\":\"" + email + "\",\"password\":\"segredo123\"}"))
                .andExpect(status().isCreated());
    }

    private org.springframework.test.web.servlet.ResultActions login(String email, String senha) throws Exception {
        return mvc.perform(post("/auth/login").contentType(MediaType.APPLICATION_JSON)
                .content("{\"email\":\"" + email + "\",\"password\":\"" + senha + "\"}"));
    }

    @Test
    void quintaFalha_bloqueiaContaCom429ERetryAfter() throws Exception {
        String email = "lock1@test.com";
        signup(email);

        for (int i = 0; i < 5; i++) {
            login(email, "errada00").andExpect(status().isUnauthorized());
        }
        // conta agora bloqueada — mesmo com a senha certa
        login(email, "segredo123")
                .andExpect(status().isTooManyRequests())
                .andExpect(header().exists("Retry-After"));
    }

    @Test
    void loginBemSucedido_zeraOContador() throws Exception {
        String email = "lock2@test.com";
        signup(email);

        login(email, "errada00").andExpect(status().isUnauthorized());
        login(email, "errada00").andExpect(status().isUnauthorized());
        login(email, "errada00").andExpect(status().isUnauthorized());
        login(email, "segredo123").andExpect(status().isOk());

        // contador zerado: 4 novas falhas ainda dao 401, nao 429
        for (int i = 0; i < 4; i++) {
            login(email, "errada00").andExpect(status().isUnauthorized());
        }
    }
}
