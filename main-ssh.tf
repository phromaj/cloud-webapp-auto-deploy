# Configure the Google Cloud provider
provider "google" {
  credentials = file("credentials.json")
  project     = "student-sup-de-vinci"
  region      = "us-central1"
  zone        = "us-central1-f"
}

# Generate a new SSH key pair
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Manage project metadata
resource "google_compute_project_metadata" "my_project_metadata" {
  metadata = {
    ssh-keys = "ci_user:${trimspace(tls_private_key.ssh_key.public_key_openssh)}"
  }
}

# Define the VM instances
resource "google_compute_instance" "tp_sdv_cloud" {
  count        = 3
  name         = "tpsdvcloud${count.index + 1}"
  machine_type = "t2a-standard-1"
  zone         = "us-central1-f"

  boot_disk {
    auto_delete = true
    device_name = "tpsdvcloud${count.index + 1}"
    initialize_params {
      image = "projects/debian-cloud/global/images/debian-12-bookworm-arm64-v20240910"
      size  = 10
      type  = "pd-standard"
    }
    mode = "READ_WRITE"
  }

  network_interface {
    network = "default"
    access_config {
      // Ephemeral IP
    }
  }

  # Allow SSH access
  tags = ["allow-ssh"]

  metadata_startup_script = <<-EOF
    #!/bin/bash
    echo "Installing Docker.io"
    apt-get update
    apt-get install -y docker.io
    systemctl enable docker
    systemctl start docker
    echo "Docker installation completed"
  EOF

  service_account {
    email  = "915723698108-compute@developer.gserviceaccount.com"
    scopes = [
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring.write",
      "https://www.googleapis.com/auth/service.management.readonly",
      "https://www.googleapis.com/auth/servicecontrol",
      "https://www.googleapis.com/auth/trace.append"
    ]
  }
}

# Firewall rule to allow SSH access
resource "google_compute_firewall" "allow_ssh" {
  name    = "allow-ssh"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["allow-ssh"]

  # Add a lifecycle rule to prevent recreation if it already exists
  lifecycle {
    create_before_destroy = true
  }
}

# Output the private key for CI/CD use
output "private_key" {
  value     = tls_private_key.ssh_key.private_key_pem
  sensitive = false
}

# Output to display the external IP addresses of the VMs
output "vm_external_ips" {
  value = google_compute_instance.tp_sdv_cloud[*].network_interface[0].access_config[0].nat_ip
}