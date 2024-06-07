resource "google_apigee_organization" "org" {
  project_id         = "npp-${var.environment}-${var.project}"
  analytics_region   = var.region
  display_name       = "npp-apigee-org"
  description        = "Terraform-provisioned NPP Apigee Org."
  authorized_network =  module.network.project_id
  retention          = "MINIMUM"
  billing_type       = "PAYG"
  depends_on         = [module.network]
}

resource "google_apigee_instance" "apigee_instance" {
  name     = "npp-apigee-instance"
  location = var.region
  org_id   = google_apigee_organization.org.id
  ip_range = "10.9.0.0/22"
}

# resource "google_apigee_environment" "apigee_env" {
#   org_id       = google_apigee_organization.org.id
#   name         = "my-environment-name"
#   description  = "Apigee Environment"
#   display_name = "environment-1"
# }
#
# resource "google_apigee_instance_attachment" "attachment" {
#   instance_id = google_apigee_instance.apigee_instance.id
#   environment = google_apigee_environment.apigee_env.name
# }

# Managed Instance Group
resource "google_compute_instance_template" "apigee_mig" {
  project      = "npp-${var.environment}-${var.project}"
  name         = "apigee-mig-template"
  machine_type = "e2-medium"
  tags         = ["apigee-mig-proxy"]
  disk {
    source_image = "projects/debian-cloud/global/images/family/debian-10"
    auto_delete  = true
    boot         = true
    disk_size_gb = 20
  }
  network_interface {
    network    = module.network.project_id
    subnetwork = module.network.subnets_ids[0]
  }
  metadata = {
    ENDPOINT           = google_apigee_instance.apigee_instance.host
    startup-script-url = "gs://apigee-5g-saas/apigee-envoy-proxy-release/latest/conf/startup-script.sh"
  }
}

resource "google_compute_health_check" "auto_healing" {
  project             = "npp-${var.environment}-${var.project}"
  name                = "autohealing-health-check"
  check_interval_sec  = 5
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 10 # 50 seconds
  tcp_health_check {
    port = "80"
  }
}

resource "google_compute_region_instance_group_manager" "apigee_mig" {
  project            = "npp-${var.environment}-${var.project}"
  name               = "apigee-mig-proxy"
  region             = var.region
  base_instance_name = "apigee-mig-proxy"
  target_size        = 2
  version {
    name              = "appserver-canary"
    instance_template = module.network.subnets_self_links[0]
  }
  named_port {
    name = "http"
    port = 433
  }
  auto_healing_policies {
    health_check      = google_compute_health_check.auto_healing.id
    initial_delay_sec = 300
  }
}