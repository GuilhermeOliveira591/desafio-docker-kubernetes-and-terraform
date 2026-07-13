# Do compose ao cluster: Docker, Kubernetes e Terraform

## Descrição

Neste desafio você vai pegar uma aplicação **que já funciona** e levá-la de um
`docker-compose` de desenvolvimento até um **cluster Kubernetes local, provisionado e
implantado inteiramente por Terraform** — do jeito que se faz no dia a dia.

O código da aplicação está pronto e você quase não encosta nele. O desafio é a **infra**:
containerizar direito, orquestrar no cluster e amarrar tudo num provisionamento
idempotente. No fim, um único `terraform apply` deve sair do nada até a aplicação
respondendo no navegador; um segundo `apply` não pode mudar coisa alguma; e um
`terraform destroy` limpa o rastro.

## Cenário

Um pequeno time construiu o **Mural de Recados** — um front simples, uma API em Go e um
Postgres. Hoje ele roda no laptop de quem desenvolveu, via `docker compose up`, e "funciona
na minha máquina". Ninguém sabe subir aquilo em outro lugar sem pedir ajuda: a migração tem
que rodar na ordem certa, a senha do banco está num arquivo qualquer, e não existe nada que
reproduza o ambiente de forma confiável.

A decisão foi tomada: o Mural vai para Kubernetes, e o provisionamento tem que ser
**reproduzível e versionado** — nada de `kubectl apply` manual, nada de "rodei uns comandos
e deu certo". Você é a pessoa de infra que vai fazer essa ponte. Recebe a aplicação como
está, o desenho do estado-alvo e os critérios de aceite. O resto — os Dockerfiles, o chart
e o Terraform que rege tudo — é o que você entrega.

## Sobre o foco do desafio

O foco é **infra, não a aplicação**. O código do Mural (`app/`) vem pronto e funcional, e
serve de contexto: você o lê para entender portas, variáveis, dependências e os pontos em que
o sistema é "chato" de propósito. Você **não deve reescrever a aplicação** para contornar as
dificuldades — elas são o desafio. Resolver uma fricção mexendo no Go em vez de resolvê-la no
Kubernetes é fugir do que se está avaliando.

Algumas situações no starter travam de propósito (a migração que precisa rodar antes, a probe
que derruba o pod se apontada para o lugar errado, o segredo que não pode ir hardcoded). Cada
uma tem uma pista no enunciado: a intenção é você **descobrir** a solução, não sofrer no
escuro.

## Estrutura do desafio

O desafio tem um núcleo obrigatório e um bônus opcional:

- **Obrigatório** — containerizar a app (Docker), empacotar os manifests num **Helm chart** e
  escrever o **Terraform maestro** que provisiona o cluster e implanta o chart de forma
  idempotente. É o que os critérios de aceite cobram e o que precisa rodar de ponta a ponta.
- **Bônus** — autoscaling (HPA) com prova de escala sob carga, e automação do fluxo
  (Makefile/script). Conta pontos extras, não é pré-requisito.

Feche o obrigatório antes de partir para o bônus.

## Objetivo

Entregar, num fork público deste repositório, tudo dentro de `infra/`, de modo que a partir
de um ambiente limpo:

- `terraform apply` **do zero** cria o cluster, disponibiliza as imagens, sobe o Ingress e
  implanta a aplicação — e o Mural responde no navegador;
- `terraform apply` rodado **duas vezes seguidas** não recria recursos à toa (idempotência:
  `0 changed`);
- `terraform destroy` remove o cluster e tudo que foi criado;
- a credencial do banco vive num **Secret** (nunca hardcoded em manifest versionado);
- a imagem da API é **mínima**, com o tamanho antes/depois documentado.

O estado que você deve alcançar está desenhado em
[`docs/arquitetura.md`](docs/arquitetura.md).

## Contexto

### A aplicação existente

O repositório traz um **Mural de Recados** funcional:

- **API em Go** (`app/api/main.go`) — configura-se 100% por variáveis de ambiente
  (`DATABASE_URL`, `PORT`) e expõe três rotas:
  - `GET /healthz` — **liveness**: só diz que o processo está de pé; **não toca no banco**.
  - `GET /readyz` — **readiness**: só passa quando o banco responde **e** a tabela `messages`
    existe (ou seja, a migração já rodou).
  - `GET/POST /api/messages` — lista e cria recados, persistindo no Postgres.
- **Migrations** (`app/api/migrations/`) — a API **não cria a tabela sozinha**; o schema vem
  de `001_init.sql` e `002_seed.sql` (dados iniciais). Ambas precisam rodar antes de a API
  ficar pronta.
- **Front estático** (`app/web/`) — HTML/CSS/JS servido por nginx. Ele fala com a API por
  caminho relativo (`/api/...`) e **não conhece a URL absoluta** dela: quem roteia é o nginx,
  cujo upstream vem de variável de ambiente (`API_UPSTREAM`). O mesmo front funciona no compose
  e no cluster sem recompilar.
- **Postgres** — o banco, com a senha embutida na `DATABASE_URL`.

Suba tudo localmente para conhecer o sistema (isto é só para **entender** — não é a entrega):

```bash
docker compose up --build
# abra http://localhost:8080
```

Repare em três coisas que o `docker-compose.yml` te mostra e que você vai reproduzir no
Kubernetes:

- a **migração roda num serviço separado**, antes da API (no K8s isso vira um `Job`);
- a API só conhece o banco pela env **`DATABASE_URL`**, que carrega a senha;
- o front **faz proxy de `/api`** para a API — ele não sabe o endereço absoluto dela.

O `docker-compose.yml` usa imagens oficiais de propósito (`go run`, `nginx`, `postgres`): ele
existe para você entender a app, **não para te dar de graça** os Dockerfiles, o chart ou o
Terraform.

### A arquitetura-alvo

O estado a atingir está em [`docs/arquitetura.md`](docs/arquitetura.md): um cluster **kind**
onde o Ingress roteia `/` para o front e `/api` para a API, a API conversa com um Postgres em
**StatefulSet + PVC**, um **Job de migração** sobe o schema antes de a API ficar pronta, e o
**Terraform** rege todo o provisionamento — cria o cluster, disponibiliza as imagens, instala
o ingress-nginx e aplica o chart.

### As fricções propositais

São situações intencionais. Cada uma tem uma pista; a solução mora no Kubernetes, não numa
alteração do código da app.

1. **A API não cria a tabela sozinha.** Sem alguém rodar a migração, a API sobe mas **nunca
   fica `Ready`**. *Pista:* olhe `/readyz` e as migrations em `app/api/migrations/`. Como
   rodar isso no cluster antes/junto do deploy? (Pense em `Job`; no Helm, um *hook* recria a
   cada release.)
2. **Liveness ≠ readiness.** `/healthz` diz "processo vivo"; `/readyz` só passa com banco e
   schema prontos. *Pista:* apontar a **livenessProbe** para `/readyz` mata o pod antes de a
   migração terminar — **CrashLoop**. Escolha a probe certa para cada endpoint.
3. **Segredo é Secret.** A `DATABASE_URL` carrega a senha do Postgres. *Pista:* ela não pode
   aparecer em texto plano num `Deployment`/`ConfigMap`. Materialize num `Secret` e injete via
   `secretKeyRef`.

## Requisitos

Tudo é produzido dentro de `infra/`. Nenhum requisito é gratuito: cada um resolve uma dor
concreta de operar o Mural fora de um laptop. Leia o **porquê** antes de sair construindo — é
ele que diz se você resolveu de verdade ou só cumpriu tabela.

### 1. Docker — imagens da API e do front

**Por quê.** Hoje a app sobe com `go run` dentro de uma imagem `golang` de quase 1 GB, com
toolchain e código-fonte junto. Num cluster, isso é imagem lenta para puxar, mais superfície
de ataque e mais coisa para dar errado. Uma API em Go compila para um binário estático — ela
não precisa carregar o mundo junto.

**Tarefa.** Produza os Dockerfiles da API (`api.Dockerfile`) e do front (`web.Dockerfile`) em `infra/docker/`:

- A API é um binário Go: use **multi-stage** e termine numa imagem **mínima**
  (`scratch`/`distroless`). Deixe registrado o tamanho **antes e depois** no README do seu
  fork — é a prova de que você entendeu o ganho, não só copiou um Dockerfile.
- O front é estático servido por **nginx**, com o proxy de `/api` parametrizável por env
  (como no compose) — para a mesma imagem servir em qualquer ambiente sem recompilar.

### 2. Helm chart — os manifests empacotados

**Por quê.** Você poderia jogar um monte de YAML solto e rodar `kubectl apply`. Mas aí ninguém
reinstala de forma limpa, ninguém parametriza por ambiente e cada deploy vira um ritual manual.
Um **chart** transforma o Mural numa unidade versionada, parametrizável e reinstalável. E cada
peça de dentro dele existe por um motivo específico:

- o **Postgres** guarda os recados — se ele voltar vazio a cada restart, o produto perdeu os
  dados. Por isso **`StatefulSet` + PVC**, não Deployment efêmero;
- a **senha do banco** não pode aparecer num `git blame` — por isso **`Secret`**, nunca
  hardcoded no manifest;
- o cluster precisa saber **quando não mandar tráfego** para um pod (subindo, migração
  rodando) — por isso **readiness**; e saber quando um pod travou de vez — por isso
  **liveness**. Trocar uma pela outra derruba a app;
- um pod não pode consumir o nó inteiro e derrubar os vizinhos — por isso **requests/limits**;
- a **migração** tem que rodar antes de a API atender — senão `/readyz` nunca passa.

**Tarefa.** Produza um **Helm chart** em `infra/helm/mural/` (não YAML solto) cobrindo, no mínimo:

- `Deployment` da API e do front;
- **`StatefulSet` + PVC** para o Postgres;
- `Service` para cada workload e um `Ingress` (`/` → front, `/api` → API);
- `ConfigMap` para configuração e **`Secret`** para a credencial do banco;
- **liveness e readiness** corretas (liveness ≠ readiness) onde fizer sentido;
- **requests e limits** de CPU e memória em todos os workloads;
- o mecanismo que roda a **migração** antes de a API ficar `Ready` (`Job`/hook).

Valores relevantes (imagens, tags, host, credencial) devem ser **parametrizáveis** por
`values.yaml` — é o que separa um chart de um YAML disfarçado.

### 3. Terraform — o maestro idempotente

**Por quê.** Este é o ponto do desafio. Sem IaC, subir o Mural é "rodei uns comandos e deu
certo": irreproduzível, indocumentado, e quando quem montou sai de férias ninguém sabe recriar
nem desfazer.
O Terraform torna o ambiente **inteiro** — cluster, rede, ingress, deploy — versionado e
reproduzível por qualquer pessoa a partir de um comando. E ele tem que ser **idempotente**:
rodar de novo sobre um ambiente que já está no ar não pode destruir e recriar o que está
funcionando (isso, num cluster de verdade, é downtime e perda de dados).

**Tarefa.** Produza o Terraform em `infra/terraform/` (`main.tf`, `variables.tf`, `outputs.tf`,
`versions.tf`) usando os providers `kind` + `helm` + `kubernetes`. Ele é o **maestro**: um único
ponto de entrada que orquestra tudo.

- `terraform apply` **do zero** cria o cluster kind, disponibiliza as imagens no cluster
  (dica: `kind load docker-image`), instala o ingress-nginx e faz o **deploy do chart** no
  namespace `mural` — e o Mural responde;
- é **idempotente**: `apply` rodado duas vezes seguidas → **`0 added, 0 changed, 0
  destroyed`**, nada recriado à toa;
- `terraform destroy` remove o cluster e tudo que foi criado, sem sobra.

## Critérios de Aceite

A entrega é avaliada contra os critérios abaixo.

### Docker

- ☐ `Dockerfile` da API em **multi-stage** com build estático.
- ☐ Imagem final da API é **mínima** (`scratch`/`distroless`), com tamanho antes/depois
  documentado.
- ☐ `Dockerfile` do front serve o estático por nginx com proxy de `/api`.

### Kubernetes / Helm

- ☐ Tudo empacotado num **Helm chart** com valores parametrizáveis (não YAML solto).
- ☐ Postgres como **StatefulSet + PVC**.
- ☐ Credencial do banco em **Secret** (nada hardcoded); `ConfigMap` onde couber.
- ☐ **liveness/readiness** corretas — sem CrashLoop por apontar liveness para `/readyz`.
- ☐ **requests/limits** de CPU e memória em todos os workloads.
- ☐ A migração roda no cluster **antes** de a API ficar `Ready` (`Job`/hook).

### Terraform

- ☐ `terraform apply` num ambiente limpo → cluster + namespace `mural` + deploy do chart, e a
  app responde no navegador.
- ☐ **Idempotência**: `apply` 2x → nenhum recurso recriado.
- ☐ `terraform destroy` remove tudo.
- ☐ Uso adequado dos providers `kind`/`helm`/`kubernetes` e código organizado.

### Consistência geral

- ☐ Nenhum arquivo de manifest versionado contém credencial em texto plano.
- ☐ A solução não altera o código da aplicação (`app/`) para contornar as fricções.

## Bônus (opcional)

- ☐ **HPA + teste de carga**: um `HorizontalPodAutoscaler` na API, com prova (`k6`/`hey`) de
  que ela escala sob carga. (Em cluster local o efeito é mais ilustrativo — vale pela prática.)
- ☐ **Automação e decisões**: um `Makefile`/script encurtando o fluxo (`make up`/`make down`)
  e um README curto com as decisões que você tomou.

## Estrutura obrigatória do entregável

```
.
├── README.md                     (este enunciado; substitua por um README seu no fork)
├── docker-compose.yml            (não altere; é só para entender a app)
├── app/                          (aplicação pronta — NÃO alterar)
│   ├── api/                      API em Go + migrations/
│   └── web/                      front estático + template do nginx
├── docs/                         
├── infra/                        <- AQUI você trabalha
│   ├── docker/
│   │   ├── api.Dockerfile        multi-stage → imagem mínima (scratch/distroless)
│   │   └── web.Dockerfile        nginx + proxy /api parametrizável
│   ├── helm/
│   │   └── mural/                chart do Mural de Recados
│   │       ├── Chart.yaml
│   │       ├── values.yaml       valores parametrizáveis (imagens, tags, host, credencial)
│   │       ├── files/
│   │       │   └── migrations/   SQL copiado de app/api/migrations/
│   │       └── templates/
│   │           ├── _helpers.tpl
│   │           ├── api.yaml      Deployment + Service da API (probes, limits)
│   │           ├── web.yaml      Deployment + Service do front
│   │           ├── postgres.yaml StatefulSet + PVC + Service do Postgres
│   │           ├── ingress.yaml  / → front, /api → API
│   │           ├── secret.yaml   credencial do banco (DATABASE_URL)
│   │           ├── migrations-configmap.yaml
│   │           └── migrate-job.yaml  Job/hook que roda a migração antes da API
│   └── terraform/
│       ├── main.tf               maestro: kind + ingress-nginx + helm release
│       ├── variables.tf
│       ├── outputs.tf
│       └── versions.tf           providers kind/helm/kubernetes
└── ...
```

## Como entregar

1. Faça um **fork** deste repositório.
2. Resolva o desafio dentro de `infra/`.
3. Garanta que o ciclo `apply → apply → destroy` funciona a partir de um ambiente limpo.
4. Envie o **link do seu fork**. Um `README` curto explicando decisões e como rodar conta
   pontos.

Ferramentas sugeridas: Docker · [kind](https://kind.sigs.k8s.io/) · kubectl · Helm ·
Terraform. Dica: no kind, para o Ingress funcionar em `localhost`, o nó precisa do label
`ingress-ready=true` e dos port-mappings 80/443; use um host tipo `*.localtest.me` (resolve
para 127.0.0.1) e você não precisa mexer em `/etc/hosts`.

## Ordem de execução sugerida

1. **Rode e entenda a app.** `docker compose up --build`, abra o navegador, publique um recado.
   Observe a ordem de subida (banco → migração → API → front) e de onde vem cada configuração.
2. **Leia a arquitetura-alvo.** Abra [`docs/arquitetura.md`](docs/arquitetura.md) e tenha
   claro o estado que precisa alcançar no cluster.
3. **Docker primeiro.** Escreva os Dockerfiles e valide os builds localmente; meça o tamanho
   da imagem da API.
4. **Helm chart.** Comece pelo Postgres (StatefulSet + PVC) e pela migração; depois API e
   front; por último Ingress, probes, limits e a parametrização por `values`. Valide com
   `helm install` num kind criado à mão antes de automatizar.
5. **Terraform maestro.** Amarre cluster + imagens + ingress + chart. Só considere pronto
   quando o `apply` 2x der `0 changed` e o `destroy` limpar tudo.
6. **Feche o ciclo num ambiente limpo.** Apague o cluster e rode `apply → apply → destroy` do
   zero, seguindo só o seu próprio README.
7. **Bônus.** Com o obrigatório fechado, adicione HPA + carga e/ou a automação.

## Dicas Finais

- **A idempotência é o coração do Terraform.** Se o segundo `apply` recria recursos, algo está
  sendo tratado como mutável quando não deveria. Valide o "apply 2x" cedo e sempre.
- **As fricções são o aprendizado.** Se você se pegar alterando o Go para "facilitar", pare:
  a solução para cada fricção existe no Kubernetes (Job/hook, probe certa, Secret).
- **Banco com estado em cluster local confunde.** Preste atenção em `volumeClaimTemplates` e no
  comportamento do PVC no kind — é a parte que mais trava.
- **Documente decisões.** Um README curto explicando por que você fez cada escolha (e o
  tamanho da imagem antes/depois) diferencia a entrega e conta ponto.

---
