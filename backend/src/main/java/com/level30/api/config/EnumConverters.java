package com.level30.api.config;

import com.level30.api.domain.model.Category;
import com.level30.api.domain.model.RiskLevel;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.convert.converter.Converter;
import org.springframework.format.FormatterRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

/** Aceita os enums em query params de forma tolerante a caixa (ex.: {@code ?riskLevel=critical}). */
@Configuration
public class EnumConverters implements WebMvcConfigurer {

    @Override
    public void addFormatters(FormatterRegistry registry) {
        registry.addConverter(String.class, RiskLevel.class,
                (Converter<String, RiskLevel>) s -> s == null || s.isBlank() ? null : RiskLevel.fromString(s));
        registry.addConverter(String.class, Category.class,
                (Converter<String, Category>) s -> s == null || s.isBlank() ? null : Category.fromJson(s));
    }
}
