# Desafio Full Cycle — Docker + Kubernetes + Terraform (deploy local)

> Status: implementado e validado · Autor: guilherme · Data: 2026-07-02
>
> Pacote completo entregue (starter + enunciado + gabarito + rubrica). Gabarito validado
> em máquina limpa: `apply` do zero sobe a app via Ingress, `apply` 2x é idempotente
> (`0 changed`), `destroy` limpa tudo. Detalhes em `solucao/VALIDACAO.md`.

## 1. Problema
Alunos da Full Cycle precisam de repertório prático em **Docker, Kubernetes e Terraform**
aplicados de ponta a ponta — não só conceito isolado, mas o fluxo real de containerizar
uma aplicação, orquestrá-la num cluster e provisioná-la com IaC de forma idempotente.

Hoje o aprendizado tende a ficar fragmentado (um tutorial de Docker, outro de K8s, outro de
Terraform), e o aluno raramente junta as três peças num único fluxo que "roda". Falta um
desafio integrado, com **enunciado claro** e um **esqueleto que o localize** (pra não travar
no "e agora?"), mas que ainda exija que ele **bote a mão na massa** e enfrente fricções
parecidas com as do dia a dia.

## 2. Objetivo & critérios de sucesso
- **Objetivo:** entregar um pacote de desafio (starter + enunciado + gabarito + rubrica) que
  leve o aluno a subir uma app web+API+Postgres num cluster Kubernetes local, com o
  **Terraform orquestrando** todo o provisionamento e deploy de forma idempotente.
- **Sucesso quando:**
  1. Um aluno consegue, partindo do starter e do enunciado, chegar num estado em que a app
     responde no navegador com **`terraform apply` rodando do zero** num ambiente limpo.
  2. `terraform apply` executado **duas vezes seguidas** não quebra nem recria recursos à toa
     (idempotência comprovada), e `terraform destroy` limpa tudo.
  3. A **solução de referência (gabarito)** roda de ponta a ponta numa máquina limpa seguindo
     só o README, provando que o desafio tem solução viável.

## 3. Formato & contexto
- **Tipo de entrega:** pacote de desafio educacional = repositório *starter* (app semi-montada)
  + `README`/enunciado + solução de referência + rubrica de correção.
- **Novo projeto / feature:** projeto novo (repositório dedicado ao desafio). O branch atual
  limpou o scaffold antigo de newsletter; este spec inaugura o novo conteúdo.

## 4. Escopo
### Dentro (MVP)
- **App semi-montada e funcional:** front simples + API em Go + Postgres, rodando via
  `docker-compose` só para o aluno **entender** o sistema (portas, variáveis, dependências).
- **Diagrama da arquitetura-alvo** (o estado que o aluno deve alcançar no cluster).
- **Enunciado claro** (README do desafio) com objetivos, requisitos obrigatórios, bônus,
  restrições e critérios de aceite — incluindo **fricções realistas de propósito**
  (ex.: migration precisa rodar antes de subir; healthcheck não óbvio; segredo não pode ir
  hardcoded).
- **O aluno constrói:** Dockerfiles (multi-stage → imagem mínima), **Helm chart** com os
  manifests (Deployment, Service, Ingress, ConfigMap, Secret, probes, resource limits) e o
  **Terraform maestro** que provisiona o cluster (kind), namespaces e faz o deploy do chart.
- **Solução de referência (gabarito)** completa e validada em máquina limpa.
- **Rubrica de correção** objetiva (o que vale ponto, o que reprova).

### Fora (não-objetivos)
- Cloud real (AWS/EKS) — decisão consciente por acessibilidade; tudo roda local.
- **LocalStack / qualquer recurso AWS-ish** — cortado do MVP para manter o foco em
  Docker + K8s + Terraform-sobre-cluster. O Terraform maestro provisiona **só** o cluster e
  o deploy do chart. (Pode voltar como bônus/passo 2 se quiser praticar o provider `aws`.)
- Skill de correção automatizada (`corrige-desafio-*`) — fica para um passo 2, depois do
  gabarito existir e ser validado.
- CI/CD, observabilidade avançada, service mesh, políticas de rede.
- Autoscaling e teste de carga como requisito obrigatório (entra apenas como **bônus**).
- Ensinar a aplicação em si / lógica de negócio — o foco é infra; a app vem pronta.

## 5. Padrão do projeto
- **Arquitetura do desafio:** app web+API+banco (2 serviços) + Postgres, alvo em Kubernetes
  local orquestrado por IaC. Repositório organizado por **responsabilidade do desafio**:
  `app/` (código pronto), `infra/` (o que o aluno preenche: docker, helm, terraform),
  `solucao/` (gabarito, fora do alcance do aluno até a correção), `docs/`.
- **Estrutura de pastas (proposta):**
  ```
  /app            # código Go (API) + front simples — pronto, funcional
  /docker-compose.yml
  /infra
    /docker       # (aluno) Dockerfiles
    /helm         # (aluno) chart
    /terraform    # (aluno) módulo maestro
  /solucao        # gabarito completo (Dockerfiles + chart + terraform) — validado
  /docs           # diagrama, rubrica, enunciado longo
  README.md       # enunciado / ponto de partida
  ```
- **Convenções:** Conventional Commits; Conventional Branch; README como enunciado canônico.
- **UI & styling:** front **propositalmente simples** (HTML/CSS estático servido por nginx ou
  um SPA mínimo) — não é o foco; sem design system. Só precisa provar comunicação
  front → API → Postgres dentro do cluster. Responsivo/acessível: N/A (fora de escopo).
- **Referência a espelhar:** padrão das skills `corrige-desafio-*` deste repo para o formato
  de enunciado + rubrica.

## 6. Restrições & decisões técnicas
- **Ambiente:** 100% local — **kind** (ou minikube) para o cluster. Zero custo, roda no
  laptop. Sem LocalStack no MVP.
- **Stack da app:** **Go** na API (binário estático → Dockerfile multi-stage terminando em
  `scratch`/`distroless`, aula de imagem mínima), front simples, **Postgres** como banco.
- **IaC:** **Terraform** com providers `kind`/`helm`/`kubernetes` — **maestro idempotente**:
  `apply` cria cluster + namespaces + deploy do chart; `apply` repetido não quebra;
  `destroy` limpa.
- **Orquestração:** **Helm chart** (não YAML solto) — habilita o Terraform a deployar via
  provider `helm` e é a skill cobrada no mercado.
- **Higiene de produção (obrigatória via chart):** liveness/readiness probes, requests/limits
  de CPU/memória, credencial do Postgres em **Secret**, config da API em **ConfigMap**.
- **Decisões já fixadas:**
  - Ambiente local só com kind/minikube; **sem LocalStack** (MVP focado). ✔
  - App = web + API + Postgres, API em Go. ✔
  - Terraform como maestro idempotente é o requisito **obrigatório** central. ✔
  - Helm e higiene de prod entram por consequência do maestro (o Terraform deploya o chart). ✔
  - HPA + teste de carga = **bônus**, não obrigatório. ✔
  - Postgres roda como **StatefulSet + PVC** (padrão correto de banco em K8s). ✔
  - Cluster padrão do enunciado: **kind** (minikube permitido por conta do aluno). ✔
  - Front: **estático (HTML/CSS/JS) servido por nginx** (Dockerfile simples, foco em infra). ✔
  - Entregável = starter + enunciado + gabarito + rubrica. ✔
  - Entrega do aluno: **fork + link do repo**; esforço estimado **~8–12h**. ✔

## 7. Riscos & incógnitas
- **Provider `kind` no Terraform tem pegadinhas de idempotência** (recriação do cluster) →
  mitigar validando o "apply 2x" no próprio gabarito e documentando a versão dos providers.
- **Fricções de propósito podem virar frustração cega** se mal explicadas → cada fricção deve
  ter uma "trilha de pista" no enunciado (o problema é intencional, a direção da solução é
  descobrível).
- **Postgres com estado em cluster local** (StatefulSet + PVC) é a parte que mais confunde →
  o gabarito deve documentar bem `volumeClaimTemplates` e o comportamento do PVC no kind.
- **Escopo do gabarito é o maior custo do projeto** → tratá-lo como entregável de primeira
  classe, validado em máquina limpa antes de "fechar" o desafio.

## 8. Questões em aberto
- _(nenhuma — todas resolvidas; ver decisões fixadas na seção 6)_

## 9. Tarefas (horizontais)

> Estas tarefas constroem o **pacote do desafio** (não são as tarefas do aluno).

**Issues criadas no GitHub** (`GuilhermeOliveira591/newsletter-do-gomes`):
tarefa 1 → [#18](https://github.com/GuilhermeOliveira591/newsletter-do-gomes/issues/18) ·
2 → [#19](https://github.com/GuilhermeOliveira591/newsletter-do-gomes/issues/19) ·
3 → [#20](https://github.com/GuilhermeOliveira591/newsletter-do-gomes/issues/20) ·
4 → [#21](https://github.com/GuilhermeOliveira591/newsletter-do-gomes/issues/21) ·
5 → [#22](https://github.com/GuilhermeOliveira591/newsletter-do-gomes/issues/22) ·
6 → [#23](https://github.com/GuilhermeOliveira591/newsletter-do-gomes/issues/23) ·
7 → [#24](https://github.com/GuilhermeOliveira591/newsletter-do-gomes/issues/24) ·
8 → [#25](https://github.com/GuilhermeOliveira591/newsletter-do-gomes/issues/25) ·
9 → [#26](https://github.com/GuilhermeOliveira591/newsletter-do-gomes/issues/26) ·
10 → [#27](https://github.com/GuilhermeOliveira591/newsletter-do-gomes/issues/27) ·
11 → [#28](https://github.com/GuilhermeOliveira591/newsletter-do-gomes/issues/28) ·
12 → [#29](https://github.com/GuilhermeOliveira591/newsletter-do-gomes/issues/29) ·
13 → [#30](https://github.com/GuilhermeOliveira591/newsletter-do-gomes/issues/30)

**Épico 0 — Fundação**

| #  | Tarefa | Depende de | Tamanho | Critério de aceite |
|----|--------|-----------|---------|--------------------|
| 1  | Estrutura do repositório: pastas `app/`, `infra/{docker,helm,terraform}`, `solucao/`, `docs/`, `.gitignore`, README base | — | P | Árvore de pastas criada e commitada; README base linka as seções; `solucao/` separada do que o aluno preenche |

**Épico A — Aplicação semi-montada (starter)**

| #  | Tarefa | Depende de | Tamanho | Critério de aceite |
|----|--------|-----------|---------|--------------------|
| 2  | API em Go: endpoints (`/healthz`, `/readyz`, um CRUD simples que persiste no Postgres) + config 100% via env | 1 | M | API compila e sobe local lendo `DATABASE_URL`/porta de env; CRUD grava/lê do Postgres; healthchecks respondem |
| 3  | Migrations + seed do Postgres | 2 | P | Migration cria o schema; seed opcional; documentado que precisa rodar **antes** da API subir (fricção intencional) |
| 4  | Front estático (HTML/CSS/JS) que consome a API | 1 | P | Página serve e faz chamada à API (URL vinda de config); serve por nginx local |
| 5  | `docker-compose.yml` para rodar a app localmente (só entendimento) | 2,3,4 | P | `docker compose up` sobe front+API+Postgres e a app funciona no navegador |

**Épico B — Enunciado & material do desafio**

| #  | Tarefa | Depende de | Tamanho | Critério de aceite |
|----|--------|-----------|---------|--------------------|
| 6  | Diagrama da arquitetura-alvo (estado a atingir no cluster) | 1 | P | Diagrama versionado em `docs/` mostrando pods, Services, Ingress, StatefulSet do Postgres e o papel do Terraform |
| 7  | README/enunciado do desafio (objetivos, requisitos obrigatórios, bônus, como entregar, tempo ~8–12h) | 6 | M | Enunciado claro e autossuficiente; lista obrigatórios (Docker+Helm+Terraform-maestro idempotente) e bônus (HPA+carga); explica entrega por fork+link |
| 8  | Fricções realistas de propósito no starter + trilhas de pista no enunciado | 3,5,7 | M | Cada fricção (migration antes do boot, healthcheck não óbvio, secret não-hardcoded) está presente no starter e tem pista descobrível no enunciado |

**Épico C — Solução de referência (gabarito)**

| #  | Tarefa | Depende de | Tamanho | Critério de aceite |
|----|--------|-----------|---------|--------------------|
| 9  | Dockerfiles de referência (API multi-stage → `scratch`/`distroless`; front nginx) | 2,4 | M | Imagens buildam; imagem da API é mínima (documentar tamanho antes/depois); front serve por nginx |
| 10 | Helm chart de referência: Deployment da API, **StatefulSet+PVC** do Postgres, Services, Ingress, ConfigMap, Secret, probes, resource limits | 9 | G | `helm install` sobe tudo num cluster kind; app acessível via Ingress; segredo em Secret; probes/limits presentes; values parametrizáveis |
| 11 | Terraform maestro de referência (providers `kind`/`helm`/`kubernetes`): cria cluster + namespaces + deploy do chart | 10 | G | `terraform apply` do zero sobe a app; **`apply` 2x não quebra/recria à toa**; `terraform destroy` limpa tudo |

**Épico D — Rubrica & validação**

| #  | Tarefa | Depende de | Tamanho | Critério de aceite |
|----|--------|-----------|---------|--------------------|
| 12 | Validação end-to-end do gabarito em máquina limpa | 11 | M | Seguindo só o README: `apply` do zero → app no ar; `apply` 2x idempotente; `destroy` limpo. Registrado como prova de que o desafio tem solução |
| 13 | Rubrica de correção objetiva | 7,12 | M | Rubrica com pontos por item (Docker, Helm/K8s, Terraform/idempotência, fricções resolvidas) e critérios de reprovação; alinhada ao enunciado |

**Paralelização**
- Depois da **#1**, os épicos **A** e **B(#6)** podem correr em paralelo.
- Dentro de A: **#4 (front)** é independente de **#2/#3 (API/banco)**.
- Épico **C** depende da app pronta (A) e segue **sequencial** (#9 → #10 → #11) por dependência técnica.
- **#12** só depois de #11; **#13** fecha o pacote (precisa do enunciado #7 e da validação #12).
