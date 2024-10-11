# Configure the Azure provider
provider "azurerm" {
  features {}
}

# Create a resource group
resource "azurerm_resource_group" "rg" {
  name     = "my-aks-rg"
  location = "eastus"
}

# Create an AKS cluster
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "my-aks-cluster"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "myakscluster"

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_DS2_v2"
  }

  identity {
    type = "SystemAssigned"
  }
}

# Create an Azure Database for PostgreSQL server
resource "azurerm_postgresql_server" "postgres" {
  name                = "postgres-server"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  sku_name = "B_Gen5_1"

  storage_mb                   = 5120
  backup_retention_days        = 7
  geo_redundant_backup_enabled = false
  auto_grow_enabled            = true

  administrator_login          = "psqladmin"
  administrator_login_password = var.postgres_password
  version                      = "11"
  ssl_enforcement_enabled      = true
}

# Create a database
resource "azurerm_postgresql_database" "database" {
  name                = "mydatabase"
  resource_group_name = azurerm_resource_group.rg.name
  server_name         = azurerm_postgresql_server.postgres.name
  charset             = "UTF8"
  collation           = "English_United States.1252"
}

# Allow access to Azure services
resource "azurerm_postgresql_firewall_rule" "azure_services" {
  name                = "allow-azure-services"
  resource_group_name = azurerm_resource_group.rg.name
  server_name         = azurerm_postgresql_server.postgres.name
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "0.0.0.0"
}

# Kubernetes provider configuration
provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.aks.kube_config.0.host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.cluster_ca_certificate)
}

# Helm provider configuration
provider "helm" {
  kubernetes {
    host                   = azurerm_kubernetes_cluster.aks.kube_config.0.host
    client_certificate     = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.cluster_ca_certificate)
  }
}

# Create a Kubernetes secret for the database URL
resource "kubernetes_secret" "database_url" {
  metadata {
    name = "database-url"
  }

  data = {
    url = "postgresql://psqladmin%40${azurerm_postgresql_server.postgres.name}:${var.postgres_password}@${azurerm_postgresql_server.postgres.fqdn}:5432/mydatabase?sslmode=require"
  }

  depends_on = [
    azurerm_postgresql_server.postgres,
    azurerm_postgresql_database.database
  ]
}

# Deploy custom webapp
resource "kubernetes_deployment" "webapp" {
  metadata {
    name = "webapp"
  }

  spec {
    replicas = 3

    selector {
      match_labels = {
        app = "webapp"
      }
    }

    template {
      metadata {
        labels = {
          app = "webapp"
        }
      }

      spec {
        container {
          image = "ghcr.io/phromaj/cloud-webapp-auto-deploy:latest"
          name  = "webapp"

          env {
            name = "DATABASE_URL"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.database_url.metadata[0].name
                key  = "url"
              }
            }
          }

          port {
            container_port = 8000
          }
        }
      }
    }
  }

  depends_on = [
    azurerm_kubernetes_cluster.aks,
    kubernetes_secret.database_url
  ]
}

# Expose webapp service
resource "kubernetes_service" "webapp" {
  metadata {
    name = "webapp"
  }

  spec {
    selector = {
      app = "webapp"
    }

    port {
      port        = 8000
      target_port = 8000
    }

    type = "ClusterIP"
  }
}

# Install Nginx Ingress Controller using Helm
resource "helm_release" "nginx_ingress" {
  name       = "nginx-ingress"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.7.1"

  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }

  depends_on = [
    azurerm_kubernetes_cluster.aks
  ]
}

# Create Ingress resource
resource "kubernetes_ingress_v1" "webapp_ingress" {
  metadata {
    name = "webapp-ingress"
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
              name = kubernetes_service.webapp.metadata[0].name
              port {
                number = 8000
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.nginx_ingress
  ]
}

# Output the external IP of the Nginx Ingress Controller
data "kubernetes_service" "nginx_ingress" {
  metadata {
    name      = "nginx-ingress-ingress-nginx-controller"
    namespace = "default"
  }

  depends_on = [
    helm_release.nginx_ingress
  ]
}

output "nginx_ingress_ip" {
  value = data.kubernetes_service.nginx_ingress.status[0].load_balancer[0].ingress[0].ip
}

# Variable declaration for PostgreSQL password
variable "postgres_password" {
  description = "Password for the PostgreSQL server"
  type        = string
  sensitive   = true
}
