output "cluster_name" {
  value       = kind_cluster.this.name
  description = "Nome do cluster kind criado"
}

output "app_url" {
  value       = "http://${var.ingress_host}"
  description = "URL da aplicação (via Ingress)"
}

output "namespace" {
  value       = kubernetes_namespace.app.metadata[0].name
  description = "Namespace da aplicação"
}
