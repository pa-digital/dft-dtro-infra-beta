locals {
  apigee-mig          = "apigee-mig"
  apigee-mig-proxy    = "apigee-mig-proxy"
  ui-apigee-mig       = "ui-apigee-mig"
}

# External Load Balancer
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
      enable_cdn           = false

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
          group           = google_compute_region_instance_group_manager.apigee_mig_2.instance_group
          max_utilization = var.cpu_max_utilization
        }
      ]

      iap_config = {
        enable               = false
        oauth2_client_id     = ""
        oauth2_client_secret = ""
      }

      log_config = {
        enable      = false
        sample_rate = null
      }
    }
  }

  # Enable SSL support
  ssl                             = true
  create_address                  = false
  address                         = google_compute_global_address.external_ipv4_address.address
  http_forward                    = false
  ssl_certificates                = [google_compute_managed_ssl_certificate.alb-cert.id]
  managed_ssl_certificate_domains = []
  create_url_map                  = true

  depends_on = [google_compute_global_address.external_ipv4_address, google_compute_managed_ssl_certificate.alb-cert]
}

# Create IPV4 HTTPS IP Address
resource "google_compute_global_address" "external_ipv4_address" {
  project    = local.project_id
  name       = "${local.name_prefix}-xlb-ipv4-address"
  ip_version = "IPV4"
}

resource "google_compute_managed_ssl_certificate" "alb-cert" {
  project = local.project_id
  name    = "${local.name_prefix}-xlb-cert"
  managed {
    domains = [var.domain[var.environment]]
  }
}

# Managed Instance Group for Apigee
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
  count = 0
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
  named_port {
    name = "http"
    port = 80
  }
}
resource "google_compute_region_instance_group_manager" "apigee_mig_2" {
  project            = local.project_id
  name               = "${local.apigee-mig}-proxy"
  region             = var.region
  base_instance_name = "${local.apigee-mig}-proxy"
  target_size        = 1
  version {
    name              = "appserver-canary"
    instance_template = google_compute_instance_template.apigee_mig.self_link_unique
  }
  named_port {
    name = "http"
    port = 80
  }
}

resource "google_compute_region_autoscaler" "apigee_autoscaler" {
  project = local.project_id
  name    = "${local.apigee-mig}-autoscaler"
  region  = var.region
  target  = google_compute_region_instance_group_manager.apigee_mig_2.id
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

# External Load Balancer for CSO Portal UI
module "ui_loadbalancer" {
  source  = "GoogleCloudPlatform/lb-http/google//modules/serverless_negs"
  version = "~> 11.1.0"
  name    = "${local.name_prefix}-ui-xlb"
  project = local.project_id

  backends = {
    ui = {
      description = "D-TRO CSO Service UI"
      timeout_sec = 302
      enable_cdn  = false

      groups = [
        {
          group = google_compute_region_network_endpoint_group.cloudrun_neg.id
        }
      ]

      iap_config = {
        enable               = false
        oauth2_client_id     = ""
        oauth2_client_secret = ""
      }

      log_config = {
        enable      = false
        sample_rate = null
      }
    }
  }

  # Enable SSL support
  ssl                             = true
  create_address                  = false
  address                         = google_compute_global_address.ui_external_ipv4_address.address
  http_forward                    = false
  ssl_certificates                = [google_compute_managed_ssl_certificate.ui-alb-cert.id]
  managed_ssl_certificate_domains = []
  create_url_map                  = true

  depends_on = [google_compute_global_address.ui_external_ipv4_address, google_compute_managed_ssl_certificate.ui-alb-cert]
}

# Create IPV4 HTTPS IP Address for the UI
resource "google_compute_global_address" "ui_external_ipv4_address" {
  project    = local.project_id
  name       = "${local.name_prefix}-ui-xlb-ipv4-address"
  ip_version = "IPV4"
}

resource "google_compute_managed_ssl_certificate" "ui-alb-cert" {
  project = local.project_id
  name    = "${local.name_prefix}-ui-xlb-cert"
  managed {
    domains = [var.domain[var.environment]]
  }
}

############################################################################

# Internal Load Balancer between Apigee and Cloud Run
# Create a proxy-only subnetwork for internal load balancer
resource "google_compute_subnetwork" "proxy_only_subnetwork" {
  project       = local.project_id
  name          = "${local.name_prefix}-loadbalancer-proxy-only-subnetwork"
  ip_cidr_range = var.ilb_proxy_only_subnetwork_range
  region        = var.region
  network       = google_compute_network.psc_network.id
  purpose       = "INTERNAL_HTTPS_LOAD_BALANCER"
  role          = "ACTIVE"
}

# Create a private subnetwork for the forwarding rule
resource "google_compute_subnetwork" "private_subnetwork" {
  project       = local.project_id
  name          = "${local.name_prefix}-forward-rule-private-subnetwork"
  ip_cidr_range = var.ilb_private_subnetwork_range
  region        = var.region
  network       = google_compute_network.psc_network.id
  purpose       = "PRIVATE"
}

# Create a backend service for each Cloud Run service
resource "google_compute_region_backend_service" "internal_lb_backend_service" {
  project               = local.project_id
  name                  = "${google_compute_region_network_endpoint_group.publish_service_serverless_neg.name}-backend"
  region                = var.region
  load_balancing_scheme = "INTERNAL_MANAGED"
  protocol              = "HTTP"
  backend {
    group           = google_compute_region_network_endpoint_group.publish_service_serverless_neg.id
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }
}

# Create a URL map for the backend services
resource "google_compute_region_url_map" "internal_lb_url_map" {
  project         = local.project_id
  name            = "${local.name_prefix}-url-map"
  region          = var.region
  default_service = google_compute_region_backend_service.internal_lb_backend_service.self_link
  host_rule {
    hosts        = ["*"]
    path_matcher = "${local.name_prefix}-path-matcher"
  }
  path_matcher {
    name            = "${local.name_prefix}-path-matcher"
    default_service = google_compute_region_backend_service.internal_lb_backend_service.self_link
    path_rule {
      paths   = ["/dtros/*"]
      service = google_compute_region_backend_service.internal_lb_backend_service.self_link
    }
  }
}

# Create a target HTTP proxy for the URL maps
resource "google_compute_region_target_http_proxy" "internal_lb_target_http_proxy" {
  project = local.project_id
  name    = "${local.name_prefix}-http-proxy"
  region  = var.region
  url_map = google_compute_region_url_map.internal_lb_url_map.self_link
}

# Create a regional forwarding rule for the internal load balancer
resource "google_compute_forwarding_rule" "internal_lb_forwarding_rule" {
  project               = local.project_id
  name                  = "${local.name_prefix}-forwarding-rule"
  region                = var.region # Ensure this is regional
  load_balancing_scheme = "INTERNAL_MANAGED"
  port_range            = "80"
  target                = google_compute_region_target_http_proxy.internal_lb_target_http_proxy.id
  network               = google_compute_network.psc_network.id
  subnetwork            = google_compute_subnetwork.private_subnetwork.id
}

# Private Service Connect
resource "google_compute_network" "psc_network" {
  project                 = local.project_id
  name                    = "${local.name_prefix}-psc-network"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "psc_private_subnetwork" {
  project       = local.project_id
  name          = "${local.name_prefix}psc-private-subnetwork"
  ip_cidr_range = var.psc_private_subnetwork_range
  region        = var.region
  network       = google_compute_network.psc_network.id
  purpose       = "PRIVATE"
}

resource "google_compute_subnetwork" "psc_subnetwork" {
  project       = local.project_id
  name          = "${local.name_prefix}-psc-subnetwork"
  ip_cidr_range = var.psc_subnetwork_range
  region        = var.region
  network       = google_compute_network.psc_network.id
  purpose       = "PRIVATE_SERVICE_CONNECT"
}

resource "google_compute_address" "psc_address" {
  project      = local.project_id
  name         = "${local.name_prefix}-psc-ip"
  region       = var.region
  address_type = "INTERNAL"
  subnetwork   = google_compute_subnetwork.psc_private_subnetwork.id
}

resource "google_compute_service_attachment" "psc_attachment" {
  project               = local.project_id
  name                  = "${local.name_prefix}-psc-attachment"
  region                = var.region
  enable_proxy_protocol = false
  connection_preference = "ACCEPT_AUTOMATIC" # TODO Change this value to only accept connections from apigee project
  nat_subnets           = [google_compute_subnetwork.psc_subnetwork.id]
  target_service        = google_compute_forwarding_rule.internal_lb_forwarding_rule.self_link
}

# Endpoint attachment in apigee project
resource "google_apigee_endpoint_attachment" "apigee_endpoint_attachment" {
  org_id                 = google_apigee_organization.apigee_org.id
  endpoint_attachment_id = "${local.name_prefix}-ep-attach-${var.environment}"
  location               = var.region
  service_attachment     = google_compute_service_attachment.psc_attachment.id
}

############################################################################

# Internal Load Balancer between Cloud Run CSO UI and Apigee
# Create a proxy-only subnetwork for internal load balancer

resource "google_compute_network" "ui_ilb_network" {
  project                 = local.project_id
  name                    = "${local.name_prefix}-ui-ilb-network"
  auto_create_subnetworks = false
}

# Proxy only subnetwork for source address for ui_ilb_subnetwork
resource "google_compute_subnetwork" "proxy_only_ui_subnetwork" {
  project       = local.project_id
  name          = "${local.name_prefix}-loadbalancer-proxy-only-ui-subnetwork"
  ip_cidr_range = var.ui_ilb_proxy_only_subnetwork_range
  region        = var.region
  network       = google_compute_network.ui_ilb_network.id
  purpose       = "REGIONAL_MANAGED_PROXY"
  role          = "ACTIVE"
}

# Create a private subnetwork to apigee for the forwarding rule
resource "google_compute_subnetwork" "ui_ilb_subnetwork" {
  project       = local.project_id
  name          = "${local.name_prefix}-ui-ilb-subnetwork"
  ip_cidr_range = var.ui_ilb_private_subnetwork_range
  region        = var.region
  network       = google_compute_network.ui_ilb_network.id
  purpose       = "PRIVATE"
}

resource "google_compute_address" "ui_ilb_address" {
  project      = local.project_id
  name         = "${local.name_prefix}-ui-ilb-ip"
  region       = var.region
  address_type = "INTERNAL"
  subnetwork   = google_compute_subnetwork.ui_ilb_subnetwork.id
  purpose      = "SHARED_LOADBALANCER_VIP"
}

# Create a regional forwarding rule for the internal load balancer
resource "google_compute_forwarding_rule" "ui_ilb_forwarding_rule" {
  project               = local.project_id
  name                  = "${local.name_prefix}-ui-ilb-forwarding-rule"
  region                = var.region
  load_balancing_scheme = "INTERNAL_MANAGED"
  port_range            = "80"
  target                = google_compute_region_target_http_proxy.ui_ilb_target_http_proxy.id
  network               = google_compute_network.ui_ilb_network.id
  subnetwork            = google_compute_subnetwork.ui_ilb_subnetwork.id
}

# Create a target HTTP proxy for the URL maps
resource "google_compute_region_target_http_proxy" "ui_ilb_target_http_proxy" {
  project = local.project_id
  name    = "${local.name_prefix}-ui-http-proxy"
  region  = var.region
  url_map = google_compute_region_url_map.internal_ui_lb_url_map.self_link
}

# Create a URL map for the backend services
resource "google_compute_region_url_map" "internal_ui_lb_url_map" {
  project         = local.project_id
  name            = "${local.name_prefix}-ui-url-map"
  region          = var.region
  default_service = google_compute_region_backend_service.apigee_backend_service.self_link
  host_rule {
    hosts        = ["*"]
    path_matcher = "${local.name_prefix}-path-matcher"
  }
  path_matcher {
    name            = "${local.name_prefix}-path-matcher"
    default_service = google_compute_region_backend_service.apigee_backend_service.self_link
    path_rule {
      paths   = ["/dtros/*"] #TODO: Is this correct for DTRO?
      service = google_compute_region_backend_service.apigee_backend_service.self_link
    }
  }
}

# Create a backend service for each Cloud Run service
resource "google_compute_region_backend_service" "apigee_backend_service" {
  project               = local.project_id
  name                  = "${local.apigee-mig}-backend-service"
  region                = var.region
  load_balancing_scheme = "INTERNAL_MANAGED"
  protocol              = "HTTP"
  health_checks         = [google_compute_region_health_check.ui_ilb_health_check.id]
  backend {
    group           = google_compute_region_instance_group_manager.ui_apigee_mig.instance_group
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
    max_utilization = var.cpu_max_utilization
  }
}

resource "google_compute_region_health_check" "ui_ilb_health_check" {
  project = local.project_id
  name    = "${local.name_prefix}-ui-ilb-health-check"
  region  = "europe-west1"
  http_health_check {
    port_specification = "USE_SERVING_PORT"
  }
}

resource "google_compute_firewall" "ui_ilb_firewall_rule" {
  project     = local.project_id
  name        = "${local.name_prefix}-ui-ilb-firewall-rule"
  network     = google_compute_network.ui_ilb_network.id
  description = "Allow incoming from Cloud Run on ssh to Apigee Proxy"
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["allow-ssh", local.apigee-mig-proxy]
}

resource "google_compute_firewall" "ui_ilb_allow_proxy_firewall_rule" {
  project     = local.project_id
  name        = "${local.name_prefix}-ui-ilb-allow-proxy-firewall-rule"
  network     = google_compute_network.ui_ilb_network.id
  description = "Allow incoming from Proxy"
  allow {
    protocol = "tcp"
    ports    = ["80", "443", "8080"]
  }
  source_ranges = [var.ui_ilb_proxy_only_subnetwork_range]
  target_tags   = ["allow-proxy", "load-balanced-backend", local.apigee-mig-proxy]
}

resource "google_compute_firewall" "health_check_firewall_rule" {
  project     = local.project_id
  name        = "${local.name_prefix}-ui-health-check-firewall-rule"
  network     = google_compute_network.ui_ilb_network.id
  description = "Allow health check for apigee"
  allow {
    protocol = "tcp"
  }
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16", "35.235.240.0/20"]
  target_tags   = ["load-balanced-backend", local.apigee-mig-proxy]
}

# Endpoint attachment in the Cloud Run CSO Service UI project
resource "google_vpc_access_connector" "ui_vpc_connector" {
  name   = "cloud-run-connector"
  region = var.region
  subnet {
    project_id = data.google_project.project.project_id
    name       = google_compute_subnetwork.ui_ilb_subnetwork.name
  }
}

####

# Managed Instance Group for Apigee from UI
resource "google_compute_subnetwork" "ui_apigee_mig" {
  project                  = local.project_id
  name                     = "${local.ui-apigee-mig}-subnetwork"
  ip_cidr_range            = var.ui_apigee_ip_range
  region                   = var.region
  network                  = google_compute_network.ui_ilb_network.id
  private_ip_google_access = true
}

resource "google_compute_instance_template" "ui_apigee_mig" {
  project      = local.project_id
  name         = "${local.ui-apigee-mig}-template"
  machine_type = var.default_machine_type
  tags         = ["http-server", local.apigee-mig-proxy, "gke-apigee-proxy"]
  disk {
    source_image = "projects/debian-cloud/global/images/family/debian-11"
    auto_delete  = true
    boot         = true
    disk_size_gb = 20
  }
  network_interface {
    network    = google_compute_network.ui_ilb_network.id
    subnetwork = google_compute_subnetwork.ui_apigee_mig.id
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

resource "google_compute_region_instance_group_manager" "ui_apigee_mig" {
  project            = local.project_id
  name               = "${local.ui-apigee-mig}-proxy"
  region             = var.region
  base_instance_name = "${local.ui-apigee-mig}-proxy"
  target_size        = 1
  version {
    name              = "appserver-canary"
    instance_template = google_compute_instance_template.ui_apigee_mig.self_link_unique
  }
  named_port {
    name = "http"
    port = 80
  }
}

resource "google_compute_region_autoscaler" "ui_apigee_autoscaler" {
  count   = 0
  project = local.project_id
  name    = "${local.ui-apigee-mig}-autoscaler"
  region  = var.region
  target  = google_compute_region_instance_group_manager.ui_apigee_mig.id
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
