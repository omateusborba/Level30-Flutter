// Substituído no build de produção (angular.json > configurations.production > fileReplacements).
// Ajuste apiBaseUrl para a URL pública da API (Cloudflare Tunnel → VM Oracle).
export const environment = {
  production: true,
  apiBaseUrl: 'https://api.SEU-DOMINIO.com',
};
