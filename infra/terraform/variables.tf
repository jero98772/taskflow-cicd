variable "cluster_name" {
  description = "Nombre del cluster kind"
  type        = string
  default     = "taskflow"
}

variable "environments" {
  description = "Ambientes a crear: nombre => configuración"
  type = map(object({
    node_port = number
    host_port = number
    log_level = string
    cpu_limit = string
    mem_limit = string
    max_pods  = number
  }))
  default = {
    staging = {
      node_port = 30080
      host_port = 8080
      log_level = "debug"
      cpu_limit = "2"
      mem_limit = "2Gi"
      max_pods  = 10
    }
    production = {
      node_port = 30081
      host_port = 8081
      log_level = "info"
      cpu_limit = "4"
      mem_limit = "4Gi"
      max_pods  = 20
    }
  }
}
