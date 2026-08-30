package com.level30.api;

import static org.hamcrest.Matchers.notNullValue;
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

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class AuthFlowTest {

    @Autowired
    MockMvc mvc;
    @Autowired
    ObjectMapper mapper;

    private String signup(String email) throws Exception {
        String body = """
                {"name":"Teste","email":"%s","password":"segredo123"}
                """.formatted(email);
        MvcResult res = mvc.perform(post("/auth/signup")
                        .contentType(MediaType.APPLICATION_JSON).content(body))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.token", notNullValue()))
                .andExpect(jsonPath("$.user.totalXp").value(0))
                .andReturn();
        JsonNode json = mapper.readTree(res.getResponse().getContentAsString());
        return json.get("token").asText();
    }

    @Test
    void signup_login_e_me() throws Exception {
        String token = signup("fulano@test.com");

        mvc.perform(get("/me").header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.email").value("fulano@test.com"));

        mvc.perform(post("/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"fulano@test.com\",\"password\":\"segredo123\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.token", notNullValue()));
    }

    @Test
    void signup_emailDuplicado_retorna409() throws Exception {
        signup("dup@test.com");
        mvc.perform(post("/auth/signup")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"X\",\"email\":\"dup@test.com\",\"password\":\"segredo123\"}"))
                .andExpect(status().isConflict());
    }

    @Test
    void login_credenciaisInvalidas_retorna401() throws Exception {
        mvc.perform(post("/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"naoexiste@test.com\",\"password\":\"errada12\"}"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void me_semToken_retorna401() throws Exception {
        mvc.perform(get("/me")).andExpect(status().isUnauthorized());
    }

    @Test
    void admin_comUsuarioComum_retorna403() throws Exception {
        String token = signup("comum@test.com");
        mvc.perform(get("/admin/indicadores").header("Authorization", "Bearer " + token))
                .andExpect(status().isForbidden());
    }

    @Test
    void signup_senhaCurta_retorna400() throws Exception {
        mvc.perform(post("/auth/signup")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"X\",\"email\":\"curta@test.com\",\"password\":\"1234\"}"))
                .andExpect(status().isBadRequest());
    }
}
