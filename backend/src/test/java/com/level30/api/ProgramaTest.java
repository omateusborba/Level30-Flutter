package com.level30.api;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
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

/** C3 · desafios do programa. */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class ProgramaTest {

    private static final String MODELO = """
            {"title":"Leitura diaria","category":"study","description":"20 paginas",
             "totalDays":30,"xpReward":300}""";

    @Autowired
    MockMvc mvc;
    @Autowired
    ObjectMapper mapper;

    private String signup() throws Exception {
        var res = mvc.perform(post("/auth/signup").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"P\",\"email\":\"p-" + System.nanoTime()
                                + "@test.com\",\"password\":\"segredo123\"}"))
                .andExpect(status().isCreated()).andReturn();
        return mapper.readTree(res.getResponse().getContentAsString()).get("token").asText();
    }

    /** DataSeeder.ensureAdmin() sempre roda — admin@level30.app / admin1234 no perfil test. */
    private String adminToken() throws Exception {
        var res = mvc.perform(post("/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"admin@level30.app\",\"password\":\"admin1234\"}"))
                .andExpect(status().isOk()).andReturn();
        return mapper.readTree(res.getResponse().getContentAsString()).get("token").asText();
    }

    private String criarModelo() throws Exception {
        var res = mvc.perform(post("/admin/programa").header("Authorization", "Bearer " + adminToken())
                        .contentType(MediaType.APPLICATION_JSON).content(MODELO))
                .andExpect(status().isCreated()).andReturn();
        return mapper.readTree(res.getResponse().getContentAsString()).get("id").asText();
    }

    @Test
    void alunoAdota_criaDesafioPessoalEMarcaComoAdotado() throws Exception {
        String id = criarModelo();
        String aluno = signup();

        assertAdotado(aluno, id, false);

        mvc.perform(post("/programa/" + id + "/adotar").header("Authorization", "Bearer " + aluno))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.title").value("Leitura diaria"));

        // aparece na lista pessoal de desafios
        mvc.perform(get("/challenges").header("Authorization", "Bearer " + aluno))
                .andExpect(jsonPath("$.length()").value(1));

        assertAdotado(aluno, id, true);

        // segunda adocao → 409
        mvc.perform(post("/programa/" + id + "/adotar").header("Authorization", "Bearer " + aluno))
                .andExpect(status().isConflict());
    }

    private void assertAdotado(String alunoToken, String id, boolean esperado) throws Exception {
        var res = mvc.perform(get("/programa").header("Authorization", "Bearer " + alunoToken))
                .andExpect(status().isOk()).andReturn();
        JsonNode arr = mapper.readTree(res.getResponse().getContentAsString());
        JsonNode alvo = null;
        for (JsonNode n : arr) {
            if (id.equals(n.get("id").asText())) {
                alvo = n;
            }
        }
        org.junit.jupiter.api.Assertions.assertNotNull(alvo, "modelo " + id + " deveria estar na lista");
        org.junit.jupiter.api.Assertions.assertEquals(esperado, alvo.get("adotado").asBoolean());
    }

    @Test
    void modeloArquivado_naoApareceNemPodeSerAdotado() throws Exception {
        String id = criarModelo();
        mvc.perform(patch("/admin/programa/" + id).header("Authorization", "Bearer " + adminToken())
                        .contentType(MediaType.APPLICATION_JSON).content("{\"active\":false}"))
                .andExpect(status().isOk());

        String aluno = signup();
        var res = mvc.perform(get("/programa").header("Authorization", "Bearer " + aluno))
                .andExpect(status().isOk()).andReturn();
        JsonNode arr = mapper.readTree(res.getResponse().getContentAsString());
        for (JsonNode n : arr) {
            org.junit.jupiter.api.Assertions.assertNotEquals(id, n.get("id").asText());
        }

        mvc.perform(post("/programa/" + id + "/adotar").header("Authorization", "Bearer " + aluno))
                .andExpect(status().isBadRequest());
    }

    @Test
    void programa_semAdmin_403() throws Exception {
        String aluno = signup();
        mvc.perform(get("/admin/programa").header("Authorization", "Bearer " + aluno))
                .andExpect(status().isForbidden());
    }

    @Test
    void removerModelo_204() throws Exception {
        String id = criarModelo();
        mvc.perform(delete("/admin/programa/" + id).header("Authorization", "Bearer " + adminToken()))
                .andExpect(status().isNoContent());
    }
}
