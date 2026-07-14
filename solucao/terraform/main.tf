# Gabarito — Terraform maestro.
# Um único `terraform apply`:
#   1. cria o cluster kind (com nó pronto para Ingress e port-mappings 80/443);
#   2. builda e carrega as imagens da API e do front no cluster;
#   3. instala o Traefik (ingress controller);
#   4. cria o namespace e implanta o chart da app.
# `apply` repetido é idempotente; `destroy` remove o cluster inteiro.

locals {
  repo_root = abspath("${path.module}/../..")
}

# 1) Cluster kind. O nó control-plane recebe o label ingress-ready e mapeia as
#    portas 80/443 do host, para o Ingress ficar acessível em localhost.
resource "kind_cluster" "this" {
  name            = var.cluster_name
  node_image      = var.node_image
  wait_for_ready  = true
  kubeconfig_path = "${path.module}/.kube/config"

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    node {
      role = "control-plane"

      kubeadm_config_patches = [
        "kind: InitConfiguration\nnodeRegistration:\n  kubeletExtraArgs:\n    node-labels: \"ingress-ready=true\"\n"
      ]

      extra_port_mappings {
        container_port = 80
        host_port      = 80
      }
      extra_port_mappings {
        container_port = 443
        host_port      = 443
      }
    }
  }
}

# Providers configurados a partir do cluster recém-criado.
provider "kubernetes" {
  host                   = kind_cluster.this.endpoint
  client_certificate     = kind_cluster.this.client_certificate
  client_key             = kind_cluster.this.client_key
  cluster_ca_certificate = kind_cluster.this.cluster_ca_certificate
}

provider "helm" {
  kubernetes {
    host                   = kind_cluster.this.endpoint
    client_certificate     = kind_cluster.this.client_certificate
    client_key             = kind_cluster.this.client_key
    cluster_ca_certificate = kind_cluster.this.cluster_ca_certificate
  }
}

# 2) Build + load das imagens. Só re-executa quando código/Dockerfile mudam
#    (triggers por hash) — garante idempotência de `apply` repetido.
resource "null_resource" "images" {
  triggers = {
    cluster      = kind_cluster.this.name
    api_src      = sha1(join("", [for f in fileset("${local.repo_root}/app/api", "**") : filesha1("${local.repo_root}/app/api/${f}")]))
    web_src      = sha1(join("", [for f in fileset("${local.repo_root}/app/web", "**") : filesha1("${local.repo_root}/app/web/${f}")]))
    api_docker   = filesha1("${local.repo_root}/solucao/docker/api.Dockerfile")
    web_docker   = filesha1("${local.repo_root}/solucao/docker/web.Dockerfile")
    api_image    = var.api_image
    web_image    = var.web_image
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      docker build -f ${local.repo_root}/solucao/docker/api.Dockerfile -t ${var.api_image} ${local.repo_root}/app/api
      docker build -f ${local.repo_root}/solucao/docker/web.Dockerfile -t ${var.web_image} ${local.repo_root}/app/web
      kind load docker-image ${var.api_image} ${var.web_image} --name ${kind_cluster.this.name}
    EOT
  }
}

# 3) Ingress controller — Traefik. O projeto ingress-nginx foi descontinuado
#    (aposentado pela comunidade Kubernetes), então usamos o Traefik no lugar.
#    Flavor kind: DaemonSet fixado no nó ingress-ready ligando as portas 80/443
#    direto no host (hostPort) — o mesmo esquema de antes. Service ClusterIP porque
#    o kind não tem provider de LoadBalancer: o tráfego entra pelo hostPort.
#    O chart já cria o IngressClass "traefik" por padrão (ingressClass.enabled=true).
resource "helm_release" "traefik" {
  name             = "traefik"
  repository       = "https://traefik.github.io/charts"
  chart            = "traefik"
  version          = "41.0.2"
  namespace        = "traefik"
  create_namespace = true
  wait             = true
  timeout          = 300

  set {
    name  = "deployment.kind"
    value = "DaemonSet"
  }
  set {
    name  = "ports.web.hostPort"
    value = "80"
  }
  set {
    name  = "ports.websecure.hostPort"
    value = "443"
  }
  set {
    name  = "service.spec.type"
    value = "ClusterIP"
  }
  set {
    name  = "nodeSelector.ingress-ready"
    value = "true"
    type  = "string"
  }
  set {
    name  = "tolerations[0].key"
    value = "node-role.kubernetes.io/control-plane"
  }
  set {
    name  = "tolerations[0].operator"
    value = "Exists"
  }
  set {
    name  = "tolerations[0].effect"
    value = "NoSchedule"
  }

  depends_on = [kind_cluster.this]
}

# 4) Namespace + deploy do chart da app.
resource "kubernetes_namespace" "app" {
  metadata {
    name = var.namespace
  }
  depends_on = [kind_cluster.this]
}

resource "helm_release" "app" {
  name      = "mural"
  chart     = "${local.repo_root}/solucao/helm/mural"
  namespace = kubernetes_namespace.app.metadata[0].name

  # wait=false de propósito: a readiness da API só passa DEPOIS do Job de migração
  # (hook post-install). Esperar a API ficar pronta antes do hook rodar travaria.
  wait          = false
  wait_for_jobs = false

  set {
    name  = "image.api.repository"
    value = split(":", var.api_image)[0]
  }
  set {
    name  = "image.api.tag"
    value = split(":", var.api_image)[1]
  }
  set {
    name  = "image.web.repository"
    value = split(":", var.web_image)[0]
  }
  set {
    name  = "image.web.tag"
    value = split(":", var.web_image)[1]
  }
  set {
    name  = "ingress.host"
    value = var.ingress_host
  }

  depends_on = [
    null_resource.images,
    helm_release.traefik,
  ]
}
