data "google_project" "project" {}

data "google_compute_network" "alb_vpc_network" {
  name = "${var.application_name}-${var.environment}-alb-network"
}

data "terraform_remote_state" "primary_default_tfstate" {
  backend = "gcs"
  config = {
    bucket = "dft-d-tro-terraform-${var.environment}"
    prefix = "terraform/state"
  }
}
