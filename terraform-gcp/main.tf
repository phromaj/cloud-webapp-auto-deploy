# Configure the Google Cloud provider
provider "google" {
  project     = var.project_id
  region      = var.region
  credentials = file("credentials.json")
}

# Enable required APIs
resource "google_project_service" "kubernetes_engine" {
  service = "container.googleapis.com"
}

resource "google_project_service" "sql_admin" {
  service = "sqladmin.googleapis.com"
}

# Create a GKE cluster
resource "google_container_cluster" "primary" {
  name               = "my-gke-cluster"
  location           = var.region
  initial_node_count = 1

  node_config {
    machine_type = "e2-medium"
  }

  depends_on = [
    google_project_service.kubernetes_engine
  ]
}

# Create a Cloud SQL PostgreSQL instance
resource "google_sql_database_instance" "postgres" {
  name             = "postgres-instance"
  database_version = "POSTGRES_15"
  region           = var.region

  settings {
    tier = "db-f1-micro"

    ip_configuration {
      ipv4_enabled = true
      authorized_networks {
        name  = "All IP addresses"
        value = "0.0.0.0/0"
      }
    }
  }

  deletion_protection = false

  depends_on = [
    google_project_service.sql_admin
  ]
}

# Create a database
resource "google_sql_database" "database" {
  name     = "mydatabase"
  instance = google_sql_database_instance.postgres.name
}

# Create a user
resource "google_sql_user" "users" {
  name     = "postgres"
  instance = google_sql_database_instance.postgres.name
  password = "password"
}

# Kubernetes provider configuration
data "google_client_config" "default" {}

provider "kubernetes" {
  host                   = "https://${google_container_cluster.primary.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
}

# Deploy custom webapp
resource "kubernetes_deployment" "webapp" {
  metadata {
    name = "webapp"
  }

  spec {
    replicas = 2

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
            name  = "DATABASE_URL"
            value = "postgresql://postgres:password@${google_sql_database_instance.postgres.public_ip_address}:5432/mydatabase"
          }

          port {
            container_port = 8000
          }
        }
      }
    }
  }

  depends_on = [
    google_container_cluster.primary,
    google_sql_database_instance.postgres
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

# Deploy Nginx as load balancer
resource "kubernetes_deployment" "nginx" {
  metadata {
    name = "nginx"
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "nginx"
      }
    }

    template {
      metadata {
        labels = {
          app = "nginx"
        }
      }

      spec {
        container {
          image = "nginx:1.21.6"
          name  = "nginx"

          port {
            container_port = 80
          }

          volume_mount {
            name       = "nginx-config"
            mount_path = "/etc/nginx/conf.d"
            read_only  = true
          }
        }

        volume {
          name = "nginx-config"
          config_map {
            name = kubernetes_config_map.nginx_config.metadata[0].name
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_deployment.webapp
  ]
}

# Nginx ConfigMap for load balancing
resource "kubernetes_config_map" "nginx_config" {
  metadata {
    name = "nginx-config"
  }

  data = {
    "default.conf" = <<-EOF
      upstream webapp {
        server webapp:8000;
      }
      server {
        listen 80;
        location / {
          proxy_pass http://webapp;
        }
      }
    EOF
  }
}

# Expose Nginx service
resource "kubernetes_service" "nginx" {
  metadata {
    name = "nginx"
  }

  spec {
    selector = {
      app = "nginx"
    }

    port {
      port        = 80
      target_port = 80
    }

    type = "LoadBalancer"
  }
}

# Output the external IP of the Nginx service
output "nginx_external_ip" {
  value = kubernetes_service.nginx.status[0].load_balancer[0].ingress[0].ip
}