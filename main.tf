# Configure the Google Cloud provider
provider "google" {
  credentials = file("credentials.json")
  project     = "student-sup-de-vinci"
  region      = "us-central1"
  zone        = "us-central1-f"
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
  can_ip_forward      = false
  deletion_protection = false
  enable_display      = false
  labels = {
    goog-ec-src = "vm_add-tf"
  }
  network_interface {
    access_config {
      network_tier = "PREMIUM"
    }
    nic_type    = "GVNIC"
    queue_count = 0
    stack_type  = "IPV4_ONLY"
    subnetwork  = "projects/student-sup-de-vinci/regions/us-central1/subnetworks/default"
  }
  scheduling {
    automatic_restart   = true
    on_host_maintenance = "TERMINATE"
    preemptible         = false
    provisioning_model  = "STANDARD"
  }
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
  shielded_instance_config {
    enable_integrity_monitoring = true
    enable_secure_boot          = false
    enable_vtpm                 = true
  }
  # Script to install Docker.io and configure VM
  metadata_startup_script = <<-EOF
    #!/bin/bash
    echo "Installing Docker.io"

    # Update the package database
    apt-get update

    # Install Docker.io
    apt-get install -y docker.io

    # Enable Docker service to start on boot
    systemctl enable docker
    # Start Docker service
    systemctl start docker
    # Add the user to the Docker group (if you want to run Docker as a non-root user)
    #usermod -aG docker $USER
    echo "Docker installation completed"
  EOF
}
# Output to display the internal IP of the first VM
output "first_vm_internal_ip" {
  value = google_compute_instance.tp_sdv_cloud[0].network_interface[0].network_ip
}
