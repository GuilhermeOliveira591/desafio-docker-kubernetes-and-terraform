# Gabarito — Dockerfile do front (nginx servindo estático + proxy /api).
# Contexto de build esperado: app/web
#   docker build -f solucao/docker/web.Dockerfile -t desafio-web:1.0 app/web
#
# A imagem oficial do nginx aplica envsubst nos arquivos em /etc/nginx/templates,
# então ${API_UPSTREAM} é resolvido no boot do container (definido pelo chart).

FROM nginx:1.27-alpine
COPY index.html app.js styles.css /usr/share/nginx/html/
COPY nginx.conf.template /etc/nginx/templates/default.conf.template
# valor padrão; no Kubernetes o chart injeta o Service da API
ENV API_UPSTREAM=api:80
EXPOSE 8080
