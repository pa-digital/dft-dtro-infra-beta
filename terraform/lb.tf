locals {
  apigee-mig = "apigee-mig"
}

# XLB
module "loadbalancer" {
  source  = "GoogleCloudPlatform/lb-http/google"
  version = "~> 10.0.0"
  name    = "${local.name_prefix}-xlb"
  project = local.project_id

  target_tags       = [local.apigee-mig-proxy]
  firewall_networks = [module.alb_vpc_network.network_id]

  backends = {
    dtro = {
      description          = "${var.dtro_service_image} service"
      protocol             = "HTTPS"
      port_name            = "https"
      security_policy      = ""
      edge_security_policy = ""
      timeout_sec          = 302

      health_check = {
        check_interval_sec  = 30
        timeout_sec         = 10
        healthy_threshold   = 2
        unhealthy_threshold = 2
        port                = 443
        request_path        = "/healthz/ingress"
      }

      groups = [
        {
          group           = google_compute_region_instance_group_manager.apigee_mig.instance_group
          max_utilization = var.cpu_max_utilization
        }
      ]
    }
  }

  # Create IPV4 HTTPS IP Address
  create_address                  = true
  ssl                             = true
  managed_ssl_certificate_domains = [var.dtro_service_domain]
  create_url_map                  = true
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
  tags         = ["https-server", local.apigee-mig-proxy, "gke-apigee-proxy"]
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
}

resource "google_compute_region_autoscaler" "apigee_autoscaler" {
  project = local.project_id
  name    = "${local.apigee-mig}-autoscaler"
  region  = var.region
  target  = google_compute_region_instance_group_manager.apigee_mig.id
  # TODO: Assess if these values are sufficient or requires updating
  autoscaling_policy {
    max_replicas    = 3
    min_replicas    = 2
    cooldown_period = 90
    cpu_utilization {
      target = var.cpu_max_utilization
    }
  }
}
