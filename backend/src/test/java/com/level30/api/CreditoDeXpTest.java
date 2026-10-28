package com.level30.api;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.level30.api.domain.Leveling;
import com.level30.api.domain.model.User;
import com.level30.api.repository.UserRepository;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

/**
 * Fase 7 (correções, item 3) — concluir um dia pela API credita o XP, atualiza o nível e desbloqueia
 * "Primeiro Passo". A base de demo antiga tinha 0 XP porque o seed gravava estado final sem passar por aqui.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class CreditoDeXpTest {

    @Autowired
    MockMvc mvc;
    @Autowired
    ObjectMapper mapper;
    @Autowired
    UserRepository users;

    private JsonNode json(String corpo) throws Exception {
        return mapper.readTree(corpo);
    }

    @Test
    void concluirDia_creditaXp_sobeDeNivel_eDesbloqueiaPrimeiroPasso() throws Exception {
        String email = "xp-" + System.nanoTime() + "@test.com";
        String token = json(mvc.perform(post("/auth/signup").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"Aluno XP\",\"email\":\"" + email + "\",\"password\":\"segredo123\"}"))
                .andExpect(status().isCreated()).andReturn().getResponse().getContentAsString()).get("token").asText();
        String auth = "Bearer " + token;

        // 495 XP: falta pouco para o nível 2 (500 XP por nível)
        User u = users.findByEmail(email).orElseThrow();
        u.setTotalXp(495);
        users.save(u);
        assertThat(Leveling.level(495)).isEqualTo(1);

        String desafio = json(mvc.perform(post("/challenges").header("Authorization", auth)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"title\":\"Desafio de XP\",\"category\":\"study\",\"description\":\"d\","
                                + "\"totalDays\":7,\"xpReward\":1000}"))
                .andExpect(status().isCreated()).andReturn().getResponse().getContentAsString()).get("id").asText();

        JsonNode concluir = json(mvc.perform(post("/challenges/" + desafio + "/complete")
                        .header("Authorization", auth).contentType(MediaType.APPLICATION_JSON).content("{}"))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString());

        int xpDelta = concluir.get("xpDelta").asInt();
        assertThat(xpDelta).isEqualTo(142);                          // 1 * 1000 / 7
        assertThat(concluir.get("totalXp").asInt()).isEqualTo(495 + xpDelta);
        assertThat(concluir.get("conquistas")).anySatisfy(c -> assertThat(c.get("id").asText()).isEqualTo("primeiro_passo"));

        // fonte de verdade: o saldo persistido e o que /me devolve ao app
        JsonNode me = json(mvc.perform(get("/me").header("Authorization", auth))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString());
        assertThat(me.get("totalXp").asInt()).isEqualTo(637);
        assertThat(Leveling.level(me.get("totalXp").asInt())).isEqualTo(2);
        assertThat(Leveling.rank(me.get("totalXp").asInt())).isEqualTo("Aprendiz");

        JsonNode conquistas = json(mvc.perform(get("/me/conquistas").header("Authorization", auth))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString());
        assertThat(conquistas).anySatisfy(c -> {
            assertThat(c.get("id").asText()).isEqualTo("primeiro_passo");
            assertThat(c.get("desbloqueada").asBoolean()).isTrue();
        });
        assertThat(UUID.fromString(users.findByEmail(email).orElseThrow().getId().toString())).isNotNull();
    }
}
