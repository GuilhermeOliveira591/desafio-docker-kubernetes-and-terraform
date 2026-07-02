# Issues (preview) — Desafio Docker + Kubernetes + Terraform

> Prévia para revisão. **Nada foi criado no GitHub ainda.** Cada bloco vira uma issue
> (título + corpo) quando você aprovar. Ref do spec: `docs/specs/01-desafio-docker-k8s-terraform.md`.

---

## 1: Estrutura do repositório

**Corpo:**

## Contexto
Ref: docs/specs/01-desafio-docker-k8s-terraform.md

## Objetivo
Criar a árvore de pastas e o esqueleto base do repositório do desafio: `app/`,
`infra/{docker,helm,terraform}`, `solucao/`, `docs/`, `.gitignore` e um README base que
linka as seções.

## Critério de aceite
- [ ] Árvore de pastas criada e commitada
- [ ] README base referencia as seções do desafio
- [ ] Pasta `solucao/` separada do que o aluno preenche (`infra/`)

## Depende de
—

---

## 2: API em Go (health/ready + CRUD no Postgres, config via env)

**Corpo:**

## Contexto
Ref: docs/specs/01-desafio-docker-k8s-terraform.md

## Objetivo
Implementar a API em Go que o aluno recebe pronta: endpoints `/healthz`, `/readyz` e um CRUD
simples que persiste no Postgres, com toda a configuração vinda de variáveis de ambiente
(`DATABASE_URL`, porta, etc.).

## Critério de aceite
- [ ] API compila e sobe localmente lendo config de env
- [ ] CRUD grava e lê do Postgres
- [ ] `/healthz` e `/readyz` respondem corretamente

## Depende de
#1

---

## 3: Migrations + seed do Postgres

**Corpo:**

## Contexto
Ref: docs/specs/01-desafio-docker-k8s-terraform.md

## Objetivo
Criar as migrations do schema usado pela API e um seed opcional. Documentar que a migration
precisa rodar **antes** de a API subir (fricção intencional do desafio).

## Critério de aceite
- [ ] Migration cria o schema necessário
- [ ] Seed opcional disponível
- [ ] Documentado que a migration roda antes do boot da API

## Depende de
#2

---

## 4: Front estático (nginx) que consome a API

**Corpo:**

## Contexto
Ref: docs/specs/01-desafio-docker-k8s-terraform.md

## Objetivo
Criar um front estático (HTML/CSS/JS) que consome a API, com a URL da API vinda de config.
Servido por nginx.

## Critério de aceite
- [ ] Página serve e faz chamada à API
- [ ] URL da API parametrizável (não hardcoded)
- [ ] Serve por nginx localmente

## Depende de
#1

---

## 5: docker-compose.yml para rodar/entender a app

**Corpo:**

## Contexto
Ref: docs/specs/01-desafio-docker-k8s-terraform.md

## Objetivo
Fornecer um `docker-compose.yml` que sobe front + API + Postgres para o aluno **entender** o
sistema (portas, variáveis, dependências) antes de partir para o Kubernetes.

## Critério de aceite
- [ ] `docker compose up` sobe front + API + Postgres
- [ ] App funciona no navegador
- [ ] Serve apenas de apoio ao entendimento (não é o entregável do aluno)

## Depende de
#2, #3, #4

---

## 6: Diagrama da arquitetura-alvo

**Corpo:**

## Contexto
Ref: docs/specs/01-desafio-docker-k8s-terraform.md

## Objetivo
Criar o diagrama do estado que o aluno deve atingir no cluster: pods, Services, Ingress,
StatefulSet do Postgres e o papel do Terraform como maestro.

## Critério de aceite
- [ ] Diagrama versionado em `docs/`
- [ ] Mostra pods, Services, Ingress e StatefulSet do Postgres
- [ ] Deixa claro o papel do Terraform no provisionamento/deploy

## Depende de
#1

---

## 7: README/enunciado do desafio

**Corpo:**

## Contexto
Ref: docs/specs/01-desafio-docker-k8s-terraform.md

## Objetivo
Escrever o enunciado claro e autossuficiente: objetivos, requisitos obrigatórios
(Docker + Helm + Terraform-maestro idempotente), bônus (HPA + teste de carga), como entregar
(fork + link do repo) e tempo estimado (~8–12h).

## Critério de aceite
- [ ] Enunciado claro e autossuficiente
- [ ] Requisitos obrigatórios e bônus listados
- [ ] Forma de entrega (fork + link) e tempo estimado documentados

## Depende de
#6

---

## 8: Fricções realistas de propósito + trilhas de pista

**Corpo:**

## Contexto
Ref: docs/specs/01-desafio-docker-k8s-terraform.md

## Objetivo
Introduzir no starter as fricções intencionais (migration antes do boot, healthcheck não
óbvio, secret que não pode ir hardcoded) e garantir que cada uma tenha uma pista descobrível
no enunciado — fricção que ensina, não frustração cega.

## Critério de aceite
- [ ] Cada fricção presente no starter
- [ ] Cada fricção tem pista/direção descobrível no enunciado
- [ ] Nenhuma fricção sem caminho de solução

## Depende de
#3, #5, #7

---

## 9: Dockerfiles de referência (gabarito)

**Corpo:**

## Contexto
Ref: docs/specs/01-desafio-docker-k8s-terraform.md

## Objetivo
Escrever os Dockerfiles da solução de referência: API em multi-stage terminando em
`scratch`/`distroless` (imagem mínima) e front servido por nginx.

## Critério de aceite
- [ ] Imagens buildam com sucesso
- [ ] Imagem da API é mínima (tamanho antes/depois documentado)
- [ ] Front serve por nginx

## Depende de
#2, #4

---

## 10: Helm chart de referência (gabarito)

**Corpo:**

## Contexto
Ref: docs/specs/01-desafio-docker-k8s-terraform.md

## Objetivo
Criar o Helm chart da solução de referência: Deployment da API, StatefulSet + PVC do Postgres,
Services, Ingress, ConfigMap, Secret, probes e resource limits, com values parametrizáveis.

## Critério de aceite
- [ ] `helm install` sobe tudo num cluster kind
- [ ] App acessível via Ingress; credencial do banco em Secret
- [ ] Probes e resource limits presentes; values parametrizáveis

## Depende de
#9

---

## 11: Terraform maestro de referência (gabarito)

**Corpo:**

## Contexto
Ref: docs/specs/01-desafio-docker-k8s-terraform.md

## Objetivo
Escrever o Terraform que orquestra tudo (providers `kind`/`helm`/`kubernetes`): cria o cluster
kind, namespaces e faz o deploy do chart — de forma idempotente.

## Critério de aceite
- [ ] `terraform apply` do zero sobe a app
- [ ] `apply` executado 2x não quebra nem recria recursos à toa
- [ ] `terraform destroy` limpa tudo

## Depende de
#10

---

## 12: Validação end-to-end do gabarito em máquina limpa

**Corpo:**

## Contexto
Ref: docs/specs/01-desafio-docker-k8s-terraform.md

## Objetivo
Validar a solução de referência numa máquina limpa seguindo só o README, provando que o
desafio tem solução viável.

## Critério de aceite
- [ ] `apply` do zero → app no ar seguindo só o README
- [ ] `apply` 2x comprovadamente idempotente
- [ ] `destroy` limpa tudo; resultado registrado como prova

## Depende de
#11

---

## 13: Rubrica de correção objetiva

**Corpo:**

## Contexto
Ref: docs/specs/01-desafio-docker-k8s-terraform.md

## Objetivo
Escrever a rubrica de correção com pontos por item (Docker, Helm/K8s, Terraform/idempotência,
fricções resolvidas) e critérios de reprovação, alinhada ao enunciado.

## Critério de aceite
- [ ] Pontuação por item definida
- [ ] Critérios de reprovação claros
- [ ] Rubrica alinhada ao enunciado (#7) e à validação (#12)

## Depende de
#7, #12
