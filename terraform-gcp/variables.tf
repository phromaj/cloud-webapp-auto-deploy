# default values for variables

variable "project_id" {
  description = "The ID of your Google Cloud project"
  type        = string
}

variable "region" {
  description = "The region to deploy resources to"
  type        = string
  default     = "us-central1"
}

variable "gke_num_nodes" {
  description = "Number of nodes in the GKE cluster"
  type        = number
  default     = 2
}