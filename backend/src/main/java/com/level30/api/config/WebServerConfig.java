package com.level30.api.config;

import org.apache.catalina.connector.Connector;
import org.springframework.boot.web.embedded.tomcat.TomcatServletWebServerFactory;
import org.springframework.boot.web.server.WebServerFactoryCustomizer;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/** Remove o header {@code Server:} das respostas — nao entrega a versao do Tomcat. */
@Configuration
public class WebServerConfig {

    @Bean
    WebServerFactoryCustomizer<TomcatServletWebServerFactory> hideServerHeader() {
        return factory -> factory.addConnectorCustomizers(this::blankServerHeader);
    }

    private void blankServerHeader(Connector connector) {
        connector.setProperty("server", " ");
    }
}
