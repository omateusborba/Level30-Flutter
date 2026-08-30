package com.level30.api;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

/** A6 — validacao de upload de avatar. */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class AvatarValidationTest {

    /** PNG 1x1 valido. */
    private static final String PNG_1X1 =
            "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==";

    @Autowired
    MockMvc mvc;
    @Autowired
    ObjectMapper mapper;

    private String token;

    @BeforeEach
    void auth() throws Exception {
        MvcResult res = mvc.perform(post("/auth/signup")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"Ava\",\"email\":\"ava-" + System.nanoTime()
                                + "@test.com\",\"password\":\"segredo123\"}"))
                .andExpect(status().isCreated())
                .andReturn();
        JsonNode json = mapper.readTree(res.getResponse().getContentAsString());
        token = json.get("token").asText();
    }

    private org.springframework.test.web.servlet.ResultActions putAvatar(String avatar) throws Exception {
        return mvc.perform(put("/me/avatar")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(mapper.writeValueAsString(java.util.Map.of("avatar", avatar))));
    }

    @Test
    void pngValido_reencodadoParaPng() throws Exception {
        putAvatar(PNG_1X1)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.avatar").value(org.hamcrest.Matchers.startsWith("data:image/png;base64,")));
    }

    @Test
    void svg_rejeitado() throws Exception {
        putAvatar("data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciPjxzY3JpcHQ+YWxlcnQoMSk8L3NjcmlwdD48L3N2Zz4=")
                .andExpect(status().isUnprocessableEntity());
    }

    @Test
    void prefixoPngMasConteudoNaoImagem_rejeitado() throws Exception {
        // "hello" em base64 — prefixo diz png, magic bytes reprovam
        putAvatar("data:image/png;base64,aGVsbG8gd29ybGQ=")
                .andExpect(status().isUnprocessableEntity());
    }

    @Test
    void naoDataUri_retorna400() throws Exception {
        putAvatar("https://exemplo.com/foto.png")
                .andExpect(status().isBadRequest());
    }
}
