locals {
  name_prefix = "${var.application_name}-${var.environment}"
}

#ALB VPC
module "alb_vpc_network" {
  source  = "terraform-google-modules/network/google"
  version = "~> 9.1"

  project_id   = var.project
  network_name = "${local.name_prefix}-alb-network"

  subnets = [
    {
      subnet_name   = "alb-subnet"
      subnet_ip     = var.alb_vpc_ip_range
      subnet_region = var.region
    }
  ]
}

#Backend VPC
module "backend_vpc_network" {
  source  = "terraform-google-modules/network/google"
  version = "~> 9.1"

  project_id   = var.project
  network_name = "${local.name_prefix}-backend-network"

  subnets = [
    {
      subnet_name   = "backend-subnet"
      subnet_ip     = var.backend_vpc_ip_range
      subnet_region = var.region
    }
  ]
}

#  VPC peering link to Cloud SQL VPC
# module "cloudsql_private_service_access" {
#   source  = "GoogleCloudPlatform/sql-db/google//modules/private_service_access"
#   version = "15.1.0"
#
#   project_id  = var.project
#   vpc_network = module.network.network_name
#
#   depends_on = [module.network]
# }

// This could be redundant, we can use Direct VPC egress to connect to the database VPC instead of this.
resource "google_vpc_access_connector" "serverless_connector" {
  name    = "${local.name_prefix}-connector"
  project = var.project
  region  = var.region

  machine_type  = var.serverless_connector_config.machine_type
  min_instances = var.serverless_connector_config.min_instances
  max_instances = var.serverless_connector_config.max_instances
}

resource "google_compute_region_network_endpoint_group" "publish_service_serverless_neg" {
  name                  = "${local.name_prefix}-${var.publish_service_image}-serverless-neg"
  network_endpoint_type = "SERVERLESS"
  region                = var.region

  cloud_run {
    service = "${local.name_prefix}-${var.publish_service_image}"
  }
}

resource "google_compute_region_network_endpoint_group" "consume_service_serverless_neg" {
  name                  = "${local.name_prefix}-${var.consume_service_image}-serverless-neg"
  network_endpoint_type = "SERVERLESS"
  region                = var.region

  cloud_run {
    service = "${local.name_prefix}-${var.consume_service_image}"
  }
}

// Add firewall here