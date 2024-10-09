terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

provider "google" {
  project     = var.project_id
  region      = var.region
  credentials = file("credentials.json")
}

provider "kubernetes" {
  host                   = "https://${google_container_cluster.primary.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
}

data "google_client_config" "default" {}

resource "google_container_cluster" "primary" {
  name     = "my-gke-cluster"
  location = "europe-west1"

  remove_default_node_pool = true
  initial_node_count       = 1

  ip_allocation_policy {
    cluster_ipv4_cidr_block  = "/16"
    services_ipv4_cidr_block = "/22"
  }
}

resource "google_container_node_pool" "primary_nodes" {
  name       = "my-node-pool"
  location   = "europe-west1"
  cluster    = google_container_cluster.primary.name
  node_count = 1  # Increased to 2 nodes for the FastAPI replicas

  node_config {
    preemptible  = true
    machine_type = "e2-small"

    # Explicitly set a smaller boot disk size
    disk_size_gb = 10

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}

# PostgreSQL StatefulSet
resource "kubernetes_stateful_set" "postgres" {
  metadata {
    name = "postgres"
  }

  spec {
    service_name = "postgres"
    replicas     = 1

    selector {
      match_labels = {
        app = "postgres"
      }
    }

    template {
      metadata {
        labels = {
          app = "postgres"
        }
      }

      spec {
        container {
          name  = "postgres"
          image = "postgres:15-alpine"

          env {
            name  = "POSTGRES_USER"
            value = "postgres"
          }
          env {
            name  = "POSTGRES_PASSWORD"
            value = "password"
          }
          env {
            name  = "POSTGRES_DB"
            value = "mydatabase"
          }

          port {
            container_port = 5432
          }

          volume_mount {
            name       = "postgres-storage"
            mount_path = "/var/lib/postgresql/data"
            sub_path   = "postgres"
          }
        }
      }
    }

    volume_claim_template {
      metadata {
        name = "postgres-storage"
      }

      spec {
        access_modes = ["ReadWriteOnce"]
        resources {
          requests = {
            storage = "5Gi"
          }
        }
      }
    }
  }
}

# PostgreSQL Service
resource "kubernetes_service" "postgres" {
  metadata {
    name = "postgres"
  }

  spec {
    selector = {
      app = kubernetes_stateful_set.postgres.spec[0].template[0].metadata[0].labels.app
    }

    port {
      port        = 5432
      target_port = 5432
    }

    cluster_ip = "None"  # Headless service for StatefulSet
  }
}

# FastAPI Deployment
resource "kubernetes_deployment" "fastapi" {
  metadata {
    name = "fastapi"
  }

  spec {
    replicas = 2

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
        container {
          image = "ghcr.io/phromaj/cloud-webapp-auto-deploy:latest"
          name  = "fastapi"

          env {
            name  = "DATABASE_URL"
            value = "postgresql://postgres:password@postgres:5432/mydatabase"
          }

          port {
            container_port = 8000
          }
        }
      }
    }
  }
}

# FastAPI Service (ClusterIP)
resource "kubernetes_service" "fastapi" {
  metadata {
    name = "fastapi"
  }

  spec {
    selector = {
      app = kubernetes_deployment.fastapi.spec[0].template[0].metadata[0].labels.app
    }

    port {
      port        = 8000
      target_port = 8000
    }

    type = "ClusterIP"
  }
}

# Nginx Deployment (Load Balancer)
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
          image = "nginx:latest"
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
}

# Nginx ConfigMap
resource "kubernetes_config_map" "nginx_config" {
  metadata {
    name = "nginx-config"
  }

  data = {
    "default.conf" = <<-EOF
      upstream fastapi {
        server fastapi.default.svc.cluster.local:8000;
      }

      server {
        listen 80;

        location / {
          proxy_pass http://fastapi;
        }
      }
    EOF
  }
}

# Nginx Service (LoadBalancer)
resource "kubernetes_service" "nginx" {
  metadata {
    name = "nginx"
  }

  spec {
    selector = {
      app = kubernetes_deployment.nginx.spec[0].template[0].metadata[0].labels.app
    }

    port {
      port        = 80
      target_port = 80
    }

    type = "LoadBalancer"
  }
}

# Firewall rule for HTTP and HTTPS
resource "google_compute_firewall" "allow_http_https" {
  name    = "allow-http-https"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["gke-my-gke-cluster"]
}

output "nginx_load_balancer_ip" {
  description = "The external IP address of the Nginx LoadBalancer service"
  value       = kubernetes_service.nginx.status[0].load_balancer[0].ingress[0].ip
}