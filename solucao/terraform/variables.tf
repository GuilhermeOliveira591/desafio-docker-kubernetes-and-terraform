variable "cluster_name" {
  type        = string
  default     = "desafio"
  description = "Nome do cluster kind"
}

variable "node_image" {
  type        = string
  default     = "kindest/node:v1.30.0"
  description = "Imagem do nó kind (pinada p/ compatibilidade com o kind local e o kind load)"
}

variable "namespace" {
  type        = string
  default     = "mural"
  description = "Namespace onde a app é implantada"
}

variable "api_image" {
  type        = string
  default     = "desafio-api:1.0"
  description = "Imagem da API (buildada e carregada no kind)"
}

variable "web_image" {
  type        = string
  default     = "desafio-web:1.0"
  description = "Imagem do front (buildada e carregada no kind)"
}

variable "ingress_host" {
  type        = string
  default     = "mural.localtest.me"
  description = "Host do Ingress (localtest.me resolve para 127.0.0.1)"
}
