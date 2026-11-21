terraform {
  required_version = ">= 1.6"

  # Estado local FUERA del workspace del runner (actions/checkout limpia el repo).
  # La ruta se pasa en init: -backend-config="path=$HOME/.taskflow/terraform.tfstate"
  backend "local" {}

  required_providers {
    kind = {
      source  = "tehcyx/kind"
      version = "~> 0.6"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.35"
    }
  }
}
