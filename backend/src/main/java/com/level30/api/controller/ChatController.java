package com.level30.api.controller;

import com.level30.api.dto.request.ChatRequest;
import com.level30.api.dto.response.ChatResponse;
import com.level30.api.security.AuthPrincipal;
import com.level30.api.service.ChatService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/chat")
@Tag(name = "Assistente")
public class ChatController {

    private final ChatService chatService;

    public ChatController(ChatService chatService) {
        this.chatService = chatService;
    }

    @PostMapping
    @Operation(summary = "Conversa com o Guia do Level30 (502 se o gateway de IA estiver fora)")
    public ChatResponse chat(@AuthenticationPrincipal AuthPrincipal principal,
                             @Valid @RequestBody ChatRequest req) {
        return chatService.chat(principal.id(), req);
    }
}
