terraform {
  backend "gcs" {}
}

# data "terraform_remote_state" "state" {
#   backend = "gcs"
#   config = {
#     #     bucket = "dft-d-tro-terraform" # PA bucket
#     bucket = var.tf_state_bucket # DfT bucket
#     prefix = "terraform/state"
#   }
# }