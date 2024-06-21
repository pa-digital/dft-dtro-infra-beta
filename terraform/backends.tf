terraform {
  backend "gcs" {
    #     bucket = "dft-d-tro-terraform"
    bucket = "dft-d-tro-terraform-${var.environment}" # DfT bucket
    prefix = "terraform/state"
  }
}
