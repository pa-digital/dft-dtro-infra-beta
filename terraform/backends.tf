terraform {
  backend "gcs" {
    bucket = "dft-d-tro-terraform"
    #     bucket = "dft-d-tro-terraform-dev" # DfT bucket
    prefix = "terraform/state"
  }
}
