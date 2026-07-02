# Gabarito — Dockerfile da API (multi-stage → imagem mínima).
# Contexto de build esperado: app/api
#   docker build -f solucao/docker/api.Dockerfile -t desafio-api:1.0 app/api
#
# Estágio 1: compila um binário estático (CGO desligado).
# Estágio 2: distroless/static (sem shell, non-root) — só o binário.
# Resultado: imagem de poucos MB vs. ~300MB+ de uma imagem golang cheia.

FROM golang:1.23-alpine AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /api .

FROM gcr.io/distroless/static:nonroot
COPY --from=build /api /api
USER nonroot:nonroot
EXPOSE 8080
ENTRYPOINT ["/api"]
