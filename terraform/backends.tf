terraform {
  backend "gcs" {
    bucket = "dft-d-tro-terraform-${var.environment}"
    prefix = "terraform/state"
  }
}
