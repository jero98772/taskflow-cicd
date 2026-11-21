output "cluster_name" {
  value = kind_cluster.this.name
}

output "environment_urls" {
  description = "URL pública de cada ambiente"
  value       = { for k, v in var.environments : k => "http://localhost:${v.host_port}" }
}

output "kubeconfig_path" {
  value = kind_cluster.this.kubeconfig_path
}
