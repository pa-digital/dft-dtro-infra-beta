terraform {
  backend "gcs" {
    bucket = "dft-d-tro-terraform"
    prefix = "terraform/state"
  }
}
