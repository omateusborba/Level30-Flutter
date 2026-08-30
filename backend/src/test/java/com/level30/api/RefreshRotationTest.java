package com.level30.api;

import static org.hamcrest.Matchers.greaterThanOrEqualTo;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

/** A2 — rotacao de refresh token, deteccao de reuso, logout, sessoes. */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class RefreshRotationTest {

    @Autowired
    MockMvc mvc;
    @Autowired
    ObjectMapper mapper;

    private JsonNode signup(String email) throws Exception {
        MvcResult res = mvc.perform(post("/auth/signup").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"R\",\"email\":\"" + email + "\",\"password\":\"segredo123\"}"))
                .andExpect(status().isCreated())
                .andReturn();
        return mapper.readTree(res.getResponse().getContentAsString());
    }

    private MvcResult refresh(String rt) throws Exception {
        return mvc.perform(post("/auth/refresh").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"refreshToken\":\"" + rt + "\"}"))
                .andReturn();
    }

    @Test
    void rotaciona_eDevolveRefreshNovo() throws Exception {
        String r1 = signup("rot1@test.com").get("refreshToken").asText();

        MvcResult res = refresh(r1);
        org.junit.jupiter.api.Assertions.assertEquals(200, res.getResponse().getStatus());
        JsonNode body = mapper.readTree(res.getResponse().getContentAsString());
        String r2 = body.get("refreshToken").asText();

        org.junit.jupiter.api.Assertions.assertNotEquals(r1, r2);
        org.junit.jupiter.api.Assertions.assertFalse(body.get("token").asText().isBlank());
    }

    @Test
    void reusarRefreshConsumido_revogaFamilia() throws Exception {
        String r1 = signup("rot2@test.com").get("refreshToken").asText();
        String r2 = mapper.readTree(refresh(r1).getResponse().getContentAsString())
                .get("refreshToken").asText();

        // r1 ja foi consumido -> reuso
        org.junit.jupiter.api.Assertions.assertEquals(401, refresh(r1).getResponse().getStatus());
        // e a familia inteira cai: r2 tambem para de valer
        org.junit.jupiter.api.Assertions.assertEquals(401, refresh(r2).getResponse().getStatus());
    }

    @Test
    void logout_revogaRefresh() throws Exception {
        JsonNode s = signup("rot3@test.com");
        String rt = s.get("refreshToken").asText();

        mvc.perform(post("/auth/logout").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"refreshToken\":\"" + rt + "\"}"))
                .andExpect(status().isNoContent());

        org.junit.jupiter.api.Assertions.assertEquals(401, refresh(rt).getResponse().getStatus());
    }

    @Test
    void sessoes_listaAtivas() throws Exception {
        JsonNode s = signup("rot4@test.com");
        String access = s.get("token").asText();

        mvc.perform(get("/me/sessoes").header("Authorization", "Bearer " + access))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(greaterThanOrEqualTo(1)));
    }
}
