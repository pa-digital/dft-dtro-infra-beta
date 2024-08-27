locals {
  serverless_connector_subnet_name = "serverless-connector-subnet"
}

#ALB VPC
module "alb_vpc_network" {
  source  = "terraform-google-modules/network/google"
  version = "~> 9.1"

  project_id   = data.google_project.project.project_id
  network_name = "${local.name_prefix}-alb-network"

  subnets = [
    {
      subnet_name   = "alb-subnet"
      subnet_ip     = var.alb_vpc_ip_range
      subnet_region = var.region
    }
  ]
}

# Private VPC connection with Apigee network
resource "google_compute_global_address" "private_ip_address" {
  project       = local.project_id
  name          = "${local.name_prefix}-apigee-ip-address"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  address       = var.google_compute_global_address_range
  prefix_length = var.google_compute_global_address_prefix_length
  network       = module.alb_vpc_network.network_id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = module.alb_vpc_network.network_id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}

# Serverless network endpoint for Service UI Cloud Run instance
resource "google_compute_region_network_endpoint_group" "service_ui_serverless_neg" {
  name                  = "${local.name_prefix}-${var.service_ui_image}-serverless-neg"
  network_endpoint_type = "SERVERLESS"
  region                = var.region
  cloud_run {
    service = local.Service_ui_cloud_run_service_name
  }
}

#Backend VPC
module "backend_vpc_network" {
  source  = "terraform-google-modules/network/google"
  version = "~> 9.1"

  project_id   = data.google_project.project.project_id
  network_name = "${local.name_prefix}-backend-network"

  subnets = [
    {
      subnet_name           = local.serverless_connector_subnet_name
      subnet_ip             = var.backend_vpc_ip_range
      subnet_region         = var.region
      subnet_private_access = true
    }
  ]
}

#VPC peering link to Cloud SQL VPC
module "cloudsql_private_service_access" {
  source  = "GoogleCloudPlatform/sql-db/google//modules/private_service_access"
  version = "20.1.0"

  project_id  = data.google_project.project.project_id
  vpc_network = module.backend_vpc_network.network_name

  depends_on = [module.backend_vpc_network]
}

## This could be redundant, we can use Direct VPC egress to connect to the database VPC instead of this.
resource "google_vpc_access_connector" "serverless_connector" {
  name    = "${local.name_prefix}-connector"
  project = data.google_project.project.project_id
  region  = var.region

  subnet {
    project_id = data.google_project.project.project_id
    name       = module.backend_vpc_network.subnets["${var.region}/${local.serverless_connector_subnet_name}"].name
  }

  machine_type  = var.serverless_connector_config.machine_type
  min_instances = var.serverless_connector_config.min_instances
  max_instances = var.serverless_connector_config.max_instances
}

# Post-MVP, There may be a need to have a separate endpoint for Publish and Consume to reduce latency for Consume DSPs
resource "google_compute_region_network_endpoint_group" "publish_service_serverless_neg" {
  name                  = "${local.name_prefix}-${var.dtro_service_image}-serverless-neg"
  network_endpoint_type = "SERVERLESS"
  region                = var.region

  cloud_run {
    service = local.cloud_run_service_name
  }
}

## VPC Service Control
# Manage access policy
module "org_policy" {
  count       = 0
  source      = "terraform-google-modules/vpc-service-controls/google"
  version     = "6.0.0"
  parent_id   = var.organisation_id
  policy_name = "${local.name_prefix}-vpc-sc-policy"
}

module "access_level_members" {
  count   = 0
  source  = "terraform-google-modules/vpc-service-controls/google//modules/access_level"
  version = "6.0.0"
  policy  = module.org_policy[0].policy_id
  name    = "dtro_env_access_members"
  members = ["serviceAccount:${var.wip_service_account}", "user:${var.access_level_members}"]
}

#  According to the docs(https://github.com/terraform-google-modules/terraform-google-vpc-service-controls?tab=readme-ov-file#known-limitations),
#  there may be a delay between a successful response and the change taking effect.
resource "null_resource" "wait_for_members" {
  count = 0
  provisioner "local-exec" {
    command = "sleep 60"
  }
  depends_on = [module.access_level_members]
}

# Regular perimeter: Regular service perimeters protect services on the projects they contain.
module "dtro_regular_service_perimeter" {
  count                       = 0
  source                      = "terraform-google-modules/vpc-service-controls/google//modules/regular_service_perimeter"
  version                     = "6.0.0"
  policy                      = module.org_policy[0].policy_id
  perimeter_name              = "dtro_regular_service_perimeter"
  description                 = "Perimeter shielding DTRO project"
  resources                   = [data.google_project.project.number]
  access_levels               = [module.access_level_members[0].name]
  restricted_services_dry_run = ["apigee.googleapis.com", "artifactregistry.googleapis.com", "bigquery.googleapis.com", "certificatemanager.googleapis.com", "clouddeploy.googleapis.com", "cloudresourcemanager.googleapis.com", "compute.googleapis.com", "iam.googleapis.com", "iamcredentials.googleapis.com", "logging.googleapis.com", "networkmanagement.googleapis.com", "run.googleapis.com", "secretmanager.googleapis.com", "servicenetworking.googleapis.com", "sourcerepo.googleapis.com", "sql-component.googleapis.com", "sqladmin.googleapis.com", "sts.googleapis.com", "storage-component.googleapis.com", "storage.googleapis.com", "vpcaccess.googleapis.com"]
}
