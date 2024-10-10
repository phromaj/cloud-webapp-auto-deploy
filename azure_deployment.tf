# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Create a resource group
resource "azurerm_resource_group" "rg" {
  name     = "my-aks-rg"
  location = "East US"
}

# Create AKS cluster with 3 nodes
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "my-aks-cluster"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "myakscluster"

  default_node_pool {
    name       = "default"
    node_count = 3
    vm_size    = "Standard_D2_v2"
  }

  identity {
    type = "SystemAssigned"
  }
}

# Define a variable for PostgreSQL password
variable "postgres_password" {
  description = "The password for the PostgreSQL server administrator."
  type        = string
}

# Generate a random string for uniqueness
resource "random_string" "unique_id" {
  length  = 6
  special = false
  upper   = false
}

# Create Azure Database for PostgreSQL with a unique name
resource "azurerm_postgresql_server" "postgres" {
  name                = "my-postgres-${random_string.unique_id.result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  sku_name = "B_Gen5_1"

  storage_mb                   = 5120
  backup_retention_days        = 7
  geo_redundant_backup_enabled = false
  auto_grow_enabled            = true

  administrator_login          = "postgres"
  administrator_login_password = var.postgres_password
  version                      = "11"
  ssl_enforcement_enabled      = true
}

resource "azurerm_postgresql_database" "mydatabase" {
  name                = "mydatabase"
  resource_group_name = azurerm_resource_group.rg.name
  server_name         = azurerm_postgresql_server.postgres.name
  charset             = "UTF8"
  collation           = "English_United States.1252"
}

# Configure the Kubernetes provider
provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.aks.kube_config.0.host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.cluster_ca_certificate)
}

# Configure the Helm provider
provider "helm" {
  kubernetes {
    host                   = azurerm_kubernetes_cluster.aks.kube_config.0.host
    client_certificate     = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.cluster_ca_certificate)
  }
}

# Deploy the application with one replica per node
resource "kubernetes_deployment" "fastapi" {
  metadata {
    name = "fastapi"
  }

  spec {
    replicas = 3

    selector {
      match_labels = {
        app = "fastapi"
      }
    }

    template {
      metadata {
        labels = {
          app = "fastapi"
        }
      }

      spec {
        affinity {
          pod_anti_affinity {
            required_during_scheduling_ignored_during_execution {
              label_selector {
                match_expressions {
                  key      = "app"
                  operator = "In"
                  values   = ["fastapi"]
                }
              }
              topology_key = "kubernetes.io/hostname"
            }
          }
        }

        container {
          image = "ghcr.io/phromaj/cloud-webapp-auto-deploy:latest"
          name  = "fastapi"

          env {
            name  = "DATABASE_URL"
            value = "postgresql://postgres:${var.postgres_password}@${azurerm_postgresql_server.postgres.fqdn}:5432/mydatabase?sslmode=require"
          }
        }
      }
    }
  }
}

# Expose FastAPI using a Kubernetes Service
resource "kubernetes_service" "fastapi" {
  metadata {
    name = "fastapi"
  }

  spec {
    selector = {
      app = "fastapi"
    }

    port {
      port        = 8000
      target_port = 8000
    }
  }
}

# Install NGINX Ingress Controller using Helm
resource "helm_release" "nginx_ingress" {
  name       = "nginx-ingress"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  namespace  = "default"

  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }
}

# Create an Ingress resource for FastAPI
resource "kubernetes_ingress_v1" "fastapi_ingress" {
  metadata {
    name = "fastapi-ingress"
    annotations = {
      "kubernetes.io/ingress.class" = "nginx"
    }
  }

  spec {
    rule {
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.fastapi.metadata[0].name
              port {
                number = 8000
              }
            }
          }
        }
      }
    }
  }
}
