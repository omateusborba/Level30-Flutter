package com.level30.api.dto.request;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record SignupRequest(
        @NotBlank(message = "Nome e obrigatorio.")
        String name,

        @NotBlank(message = "E-mail e obrigatorio.")
        @Email(message = "E-mail invalido.")
        String email,

        @NotBlank(message = "Senha e obrigatoria.")
        @Size(min = 8, message = "A senha precisa ter pelo menos 8 caracteres.")
        String password
) {
}
