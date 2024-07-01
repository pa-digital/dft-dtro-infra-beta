locals {
  backend_subnet_name = "backend-subnet"
  network_name_prefix = "${var.application_name}-${var.environment}"
}

#ALB VPC
module "alb_vpc_network" {
  source  = "terraform-google-modules/network/google"
  version = "~> 9.1"

  project_id   = var.project
  network_name = "${local.network_name_prefix}-alb-network"

  subnets = [
    {
      subnet_name   = "alb-subnet"
      subnet_ip     = var.alb_vpc_ip_range
      subnet_region = var.region
    }
  ]
}

#Firewall rules for ALB VPC
module "alb_vpc_network_firewall_rules" {
  source       = "terraform-google-modules/network/google//modules/firewall-rules"
  project_id   = var.project
  network_name = module.alb_vpc_network.network_name

  rules = [{
    name = "deny-all"
    deny = [{ protocol = "all"
    ports = [] }]
  }]
}

#Backend VPC
module "backend_vpc_network" {
  source  = "terraform-google-modules/network/google"
  version = "~> 9.1"

  project_id   = var.project
  network_name = "${local.network_name_prefix}-backend-network"

  subnets = [
    {
      subnet_name   = local.backend_subnet_name
      subnet_ip     = var.backend_vpc_ip_range
      subnet_region = var.region
    }
  ]
}

#VPC peering link to Cloud SQL VPC
module "cloudsql_private_service_access" {
  source  = "GoogleCloudPlatform/sql-db/google//modules/private_service_access"
  version = "20.1.0"

  project_id  = var.project
  vpc_network = module.backend_vpc_network.network_name

  depends_on = [module.backend_vpc_network]
}

## This could be redundant, we can use Direct VPC egress to connect to the database VPC instead of this.
resource "google_vpc_access_connector" "serverless_connector" {
  name    = "${local.network_name_prefix}-connector"
  project = var.project
  region  = var.region

  subnet {
    project_id = var.project
    name       = module.backend_vpc_network.subnets["${var.region}/${local.backend_subnet_name}"].name
  }

  machine_type  = var.serverless_connector_config.machine_type
  min_instances = var.serverless_connector_config.min_instances
  max_instances = var.serverless_connector_config.max_instances
}

resource "google_compute_region_network_endpoint_group" "publish_service_serverless_neg" {
  name                  = "${local.network_name_prefix}-${var.dtro_service_image}-serverless-neg"
  network_endpoint_type = "SERVERLESS"
  region                = var.region

  cloud_run {
    service = "${local.network_name_prefix}-${var.dtro_service_image}"
  }
}

# ## VPC Service Control
# # Manage access policy
# module "org_policy" {
#   source      = "terraform-google-modules/vpc-service-controls/google"
#   parent_id   = var.orgainisation # Orgainisation name
#   policy_name = var.policy_name
# }
#
# module "access_level_members" {
#   source  = "terraform-google-modules/vpc-service-controls/google//modules/access_level"
#   policy  = module.org_policy.policy_id
#   name    = "terraform_members"
#   members = var.access_level_members # List of members with access to the policy (service accounts)
# }
#
# #  Acording to the docs, there may be a delay between a successful response and the change taking effect.
# #  This dealy value is from the docs and allows time for the resource to come online
# resource "null_resource" "wait_for_members" {
#   provisioner "local-exec" {
#     command = "sleep 60"
#   }
#   depends_on = [module.access_level_members]
# }
#
# # Regular perimeter: Regular service perimeters protect services on the projects they contain.
# module "regular_service_perimeter_1" {
#   source              = "terraform-google-modules/vpc-service-controls/google//modules/regular_service_perimeter"
#   policy              = module.org_policy.policy_id
#   perimeter_name      = "regular_perimeter_1"
#   description         = "Perimeter shielding projects"
#   resources           = [var.project_id, "alb-vpc", "backend-vpc"]
#   access_levels       = [module.access_level_members.name]
#   restricted_services = ["vpcaccess.googleapis.com", "sqladmin.googleapis.com", "run.googleapis.com", "artifactregistry.googleapis.com"]
#   shared_resources    = {
#     all = ["11111111"]
#   }
# }
