# Infraestructura como código: cluster Kubernetes local (kind) + 2 ambientes aislados
resource "kind_cluster" "this" {
  name            = var.cluster_name
  wait_for_ready  = true
  kubeconfig_path = pathexpand("~/.kube/taskflow-config")

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    node {
      role = "control-plane"

      # Cada ambiente se expone en un puerto distinto del host
      dynamic "extra_port_mappings" {
        for_each = var.environments
        content {
          container_port = extra_port_mappings.value.node_port
          host_port      = extra_port_mappings.value.host_port
          listen_address = "0.0.0.0"
        }
      }
    }
  }
}

provider "kubernetes" {
  host                   = kind_cluster.this.endpoint
  client_certificate     = kind_cluster.this.client_certificate
  client_key             = kind_cluster.this.client_key
  cluster_ca_certificate = kind_cluster.this.cluster_ca_certificate
}

resource "kubernetes_namespace" "env" {
  for_each = var.environments
  metadata {
    name = each.key
    labels = {
      app         = "taskflow"
      environment = each.key
      managed-by  = "terraform"
    }
  }
}

resource "kubernetes_resource_quota" "env" {
  for_each = var.environments
  metadata {
    name      = "taskflow-quota"
    namespace = kubernetes_namespace.env[each.key].metadata[0].name
  }
  spec {
    hard = {
      "limits.cpu"    = each.value.cpu_limit
      "limits.memory" = each.value.mem_limit
      pods            = each.value.max_pods
    }
  }
}

resource "kubernetes_limit_range" "env" {
  for_each = var.environments
  metadata {
    name      = "taskflow-defaults"
    namespace = kubernetes_namespace.env[each.key].metadata[0].name
  }
  spec {
    limit {
      type = "Container"
      default = {
        cpu    = "250m"
        memory = "256Mi"
      }
      default_request = {
        cpu    = "50m"
        memory = "64Mi"
      }
    }
  }
}

resource "kubernetes_config_map" "env" {
  for_each = var.environments
  metadata {
    name      = "taskflow-config"
    namespace = kubernetes_namespace.env[each.key].metadata[0].name
  }
  data = {
    APP_ENV   = each.key
    LOG_LEVEL = each.value.log_level
    NODE_PORT = tostring(each.value.node_port)
  }
}
