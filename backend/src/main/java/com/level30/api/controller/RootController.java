package com.level30.api.controller;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirements;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.util.Map;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@Tag(name = "Status")
@SecurityRequirements
public class RootController {

    @GetMapping("/")
    @Operation(summary = "Health check publico")
    public Map<String, String> root() {
        return Map.of("name", "level30-api", "status", "ok");
    }
}
