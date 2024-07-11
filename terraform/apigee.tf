locals {
  apigee-mig = "apigee-mig"
}

## Apigee
resource "google_apigee_organization" "apigee_org" {
  project_id         = local.project_id
  analytics_region   = var.region
  display_name       = "${local.name_prefix}-apigee-org"
  description        = "Terraform-provisioned D-TRO Apigee Org."
  runtime_type       = "CLOUD"
  authorized_network = module.alb_vpc_network.network_id
  retention          = "DELETION_RETENTION_UNSPECIFIED"
  billing_type       = "PAYG"
}

resource "google_apigee_instance" "apigee_instance" {
  name     = "${var.application_name}-apigee-instance"
  location = var.region
  org_id   = google_apigee_organization.apigee_org.id
  ip_range = "10.9.0.0/22"
}

resource "google_apigee_environment" "apigee_env" {
  org_id       = google_apigee_organization.apigee_org.id
  name         = "${local.name_prefix}-apigee-environment"
  description  = "${var.environment} ${var.application_name} Apigee Environment"
  display_name = "${var.environment} ${var.application_name} Environment"
  type         = "INTERMEDIATE"
  depends_on   = [google_service_networking_connection.private_vpc_connection]
}

resource "google_apigee_instance_attachment" "attachment" {
  instance_id = google_apigee_instance.apigee_instance.id
  environment = google_apigee_environment.apigee_env.name
}

resource "google_apigee_envgroup" "env_group" {
  name      = "${local.name_prefix}-apigee-environment-group"
  hostnames = var.environment == "prod" ? ["dtro.${var.org_domain}"] : ["${var.environment}.${var.org_domain}"]
  org_id    = google_apigee_organization.apigee_org.id
}

resource "google_apigee_envgroup_attachment" "group_attachment" {
  envgroup_id = google_apigee_envgroup.env_group.id
  environment = google_apigee_environment.apigee_env.name
}

# Managed Instance Group
resource "google_compute_subnetwork" "apigee_mig" {
  project                  = local.project_id
  name                     = "${local.apigee-mig}-subnetwork"
  ip_cidr_range            = var.apigee_ip_range
  region                   = var.region
  network                  = module.alb_vpc_network.network_id
  private_ip_google_access = true
}

resource "google_compute_instance_template" "apigee_mig" {
  project      = local.project_id
  name         = "${local.apigee-mig}-template"
  machine_type = var.default_machine_type
  tags         = ["https-server", "${local.apigee-mig}-proxy", "gke-apigee-proxy"]
  disk {
    source_image = "projects/debian-cloud/global/images/family/debian-11"
    auto_delete  = true
    boot         = true
    disk_size_gb = 20
  }
  network_interface {
    network    = module.alb_vpc_network.network_id
    subnetwork = google_compute_subnetwork.apigee_mig.id
  }
  service_account {
    email  = var.execution_service_account
    scopes = ["cloud-platform"]
  }
  metadata = {
    ENDPOINT           = google_apigee_instance.apigee_instance.host
    startup-script-url = "gs://apigee-5g-saas/apigee-envoy-proxy-release/latest/conf/startup-script.sh"
  }
}

resource "google_compute_region_instance_group_manager" "apigee_mig" {
  project            = local.project_id
  name               = "${local.apigee-mig}-proxy"
  region             = var.region
  base_instance_name = "${local.apigee-mig}-proxy"
  target_size        = 2
  version {
    name              = "appserver-canary"
    instance_template = google_compute_instance_template.apigee_mig.self_link_unique
  }
  named_port {
    name = "https"
    port = 443
  }
  #   auto_healing_policies {
  #     health_check      = google_compute_health_check.auto_healing.id
  #     initial_delay_sec = 300
  #   }
}

resource "google_compute_region_autoscaler" "apigee_autoscaler" {
  project = local.project_id
  name    = "${local.apigee-mig}-autoscaler"
  region  = var.region
  target  = google_compute_region_instance_group_manager.apigee_mig.id
  autoscaling_policy {
    max_replicas    = 3
    min_replicas    = 2
    cooldown_period = 90
    cpu_utilization {
      target = 0.75
    }
  }
}
