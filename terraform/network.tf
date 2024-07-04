locals {
  backend_subnet_name = "backend-subnet"
  network_name_prefix = "${var.application_name}-${var.environment}"
}

#ALB VPC
module "alb_vpc_network" {
  source  = "terraform-google-modules/network/google"
  version = "~> 9.1"

  project_id   = data.google_project.project.project_id
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
  project_id   = data.google_project.project.project_id
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

  project_id   = data.google_project.project.project_id
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

  project_id  = data.google_project.project.project_id
  vpc_network = module.backend_vpc_network.network_name

  depends_on = [module.backend_vpc_network]
}

## This could be redundant, we can use Direct VPC egress to connect to the database VPC instead of this.
resource "google_vpc_access_connector" "serverless_connector" {
  name    = "${local.network_name_prefix}-connector"
  project = data.google_project.project.project_id
  region  = var.region

  subnet {
    project_id = data.google_project.project.project_id
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

## VPC Service Control
# Manage access policy
module "org_policy" {
  count  = 0
  source = "terraform-google-modules/vpc-service-controls/google"
  #   parent_id   = data.google_organization.organisation.org_id
  parent_id   = var.organisation_id
  policy_name = "${local.network_name_prefix}-vpc-sc-policy"
}

module "access_level_members" {
  count   = 0
  source  = "terraform-google-modules/vpc-service-controls/google//modules/access_level"
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
  policy                      = module.org_policy[0].policy_id
  perimeter_name              = "dtro_regular_service_perimeter"
  description                 = "Perimeter shielding DTRO project"
  resources                   = [data.google_project.project.number]
  access_levels               = [module.access_level_members[0].name]
  restricted_services_dry_run = ["apigee.googleapis.com", "artifactregistry.googleapis.com", "bigquery.googleapis.com", "certificatemanager.googleapis.com", "clouddeploy.googleapis.com", "cloudresourcemanager.googleapis.com", "compute.googleapis.com", "iam.googleapis.com", "iamcredentials.googleapis.com", "logging.googleapis.com", "networkmanagement.googleapis.com", "run.googleapis.com", "secretmanager.googleapis.com", "servicenetworking.googleapis.com", "sourcerepo.googleapis.com", "sql-component.googleapis.com", "sqladmin.googleapis.com", "sts.googleapis.com", "storage-component.googleapis.com", "storage.googleapis.com", "vpcaccess.googleapis.com"]
}
