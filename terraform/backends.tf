terraform {
  backend "gcs" {
    bucket = "dft-dtro-terraform"
    prefix = "terraform/state"
  }
}
