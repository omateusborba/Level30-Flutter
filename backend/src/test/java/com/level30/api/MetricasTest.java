package com.level30.api;

import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
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

/** B1 — endpoints agregados + risco materializado. */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class MetricasTest {

    @Autowired
    MockMvc mvc;
    @Autowired
    ObjectMapper mapper;

    private String userToken;

    @BeforeEach
    void setup() throws Exception {
        var res = mvc.perform(post("/auth/signup").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"M\",\"email\":\"met-" + System.nanoTime()
                                + "@test.com\",\"password\":\"segredo123\"}"))
                .andExpect(status().isCreated()).andReturn();
        userToken = mapper.readTree(res.getResponse().getContentAsString()).get("token").asText();

        // cria um desafio e conclui um dia — gera dado para as métricas
        var cr = mvc.perform(post("/challenges").header("Authorization", "Bearer " + userToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"title\":\"Ler\",\"category\":\"study\",\"description\":\"20 pag\","
                                + "\"totalDays\":30,\"xpReward\":300}"))
                .andExpect(status().isCreated()).andReturn();
        String challengeId = mapper.readTree(cr.getResponse().getContentAsString()).get("id").asText();
        mvc.perform(post("/challenges/" + challengeId + "/complete")
                        .header("Authorization", "Bearer " + userToken))
                .andExpect(status().isOk());
    }

    @Test
    void desafiosAdmin_trazRiscoMaterializado() throws Exception {
        mvc.perform(get("/admin/desafios").with(user("adm").roles("ADMIN")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content[0].riskLevel").exists())
                .andExpect(jsonPath("$.content[0].riskScore").exists());
    }

    @Test
    void desafiosAdmin_buscaServerSide() throws Exception {
        mvc.perform(get("/admin/desafios?busca=Ler").with(user("adm").roles("ADMIN")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(1));
        mvc.perform(get("/admin/desafios?busca=zzzznaoexiste").with(user("adm").roles("ADMIN")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(0));
    }

    @Test
    void indicadores_semFindAll() throws Exception {
        mvc.perform(get("/admin/indicadores").with(user("adm").roles("ADMIN")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalDesafios").value(org.hamcrest.Matchers.greaterThanOrEqualTo(1)))
                .andExpect(jsonPath("$.porNivelDeRisco").isArray());
    }

    @Test
    void engajamento_serieDiariaComODiaDeHoje() throws Exception {
        var r = mvc.perform(get("/admin/metricas/engajamento?dias=7").with(user("adm").roles("ADMIN")))
                .andExpect(status().isOk()).andReturn();
        JsonNode arr = mapper.readTree(r.getResponse().getContentAsString());
        org.junit.jupiter.api.Assertions.assertEquals(7, arr.size());
        JsonNode hoje = arr.get(arr.size() - 1);
        org.junit.jupiter.api.Assertions.assertTrue(hoje.get("conclusoes").asLong() >= 1);
        org.junit.jupiter.api.Assertions.assertTrue(hoje.get("novosDesafios").asLong() >= 1);
    }

    @Test
    void demaisMetricas_respondem200() throws Exception {
        for (String path : new String[] {
                "/admin/metricas/sobrevivencia", "/admin/metricas/retencao",
                "/admin/metricas/risco", "/admin/metricas/gamificacao", "/admin/metricas/padroes" }) {
            mvc.perform(get(path).with(user("adm").roles("ADMIN")))
                    .andExpect(status().isOk());
        }
    }

    @Test
    void metricas_semAdmin_403() throws Exception {
        mvc.perform(get("/admin/metricas/engajamento").header("Authorization", "Bearer " + userToken))
                .andExpect(status().isForbidden());
    }

    @Test
    void meAtividade_trazXpPorDia() throws Exception {
        mvc.perform(get("/me/atividade?desde=2026-01-01").header("Authorization", "Bearer " + userToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].quantidade").value(1))
                .andExpect(jsonPath("$[0].xp").value(org.hamcrest.Matchers.greaterThanOrEqualTo(1)));
    }
}
