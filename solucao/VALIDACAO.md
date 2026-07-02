# Validação end-to-end do gabarito

> Prova de que o desafio tem solução viável. Executado em máquina limpa (WSL2), seguindo
> só os comandos abaixo. Data: 2026-07-02.

## Ambiente usado
- Go 1.23 · Docker · kind v0.23.0 · kubectl v1.31 · Helm v3.18 · Terraform v1.9.8
- Node image do kind **pinado** em `kindest/node:v1.30.0` (o `kind load` do kind 0.23 é
  incompatível com o containerd v2 de node images mais novos — ver `variables.tf`).

## 1. App isolada (docker-compose)
```
docker compose up -d
curl http://localhost:8080/api/messages     # retorna o seed
curl -X POST .../api/messages -d '{...}'     # cria e persiste
```
Resultado: migração roda como serviço separado (CREATE TABLE + seed), front 200,
GET/POST/`readyz` OK. ✔

## 2. Gabarito completo (Terraform maestro)
```
cd solucao/terraform
terraform init
terraform apply -auto-approve      # cria kind + imagens + ingress + app
```
Resultado do `apply` do zero: **5 resources added**. Pods:
```
mural-api-...      1/1 Running   (x2)   # readiness só passou após a migração
mural-postgres-0  1/1 Running          # StatefulSet + PVC
mural-web-...      1/1 Running   (x2)
```
Acesso via Ingress (`mural.localtest.me` → 127.0.0.1, portas 80/443 mapeadas pelo kind):
```
GET  http://mural.localtest.me/            -> 200
GET  http://mural.localtest.me/api/messages -> lista (seed)
POST http://mural.localtest.me/api/messages -> cria e persiste ✔
```

## 3. Idempotência (o critério central)
```
terraform apply -auto-approve      # segunda vez
# => Apply complete! Resources: 0 added, 0 changed, 0 destroyed.
```
✔ `apply` repetido não recria nada (build/load de imagem só re-dispara por hash de código).

## 4. Limpeza
```
terraform destroy -auto-approve
# => Destroy complete! Resources: 5 destroyed.  |  kind: No kind clusters found.
```
✔ `destroy` remove o cluster inteiro.

## Tamanho das imagens (aula de imagem mínima)
| Imagem | Tamanho |
|--------|---------|
| `golang:1.23-alpine` (builder) | 246 MB |
| `desafio-api:1.0` (distroless static) | **11.6 MB** |
| `desafio-web:1.0` (nginx alpine) | 48.2 MB |
