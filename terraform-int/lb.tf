locals {
  int-apigee-mig    = "int-apigee-mig"
  apigee-mig-proxy  = "apigee-mig-proxy"
  int-ui-apigee-mig = "int-ui-apigee-mig"
}

# External Load Balancer for D-TRO
module "loadbalancer" {
  source  = "GoogleCloudPlatform/lb-http/google"
  version = "~> 10.0.0"
  name    = "${local.name_prefix}-xlb"
  project = local.project_id

  target_tags       = [local.apigee-mig-proxy]
  firewall_networks = [data.google_compute_network.alb_vpc_network.id]

  backends = {
    dtro = {
      description          = "${var.dtro_service_image} service"
      protocol             = "HTTPS"
      port_name            = "https"
      security_policy      = module.dtro_cloud_armor.policy.self_link
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
          group           = data.terraform_remote_state.primary_default_tfstate.outputs.apigee_mig_instance_group
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
  ssl_policy                      = google_compute_ssl_policy.ssl_policy.self_link

  depends_on = [google_compute_global_address.external_ipv4_address, google_compute_managed_ssl_certificate.alb-cert, google_compute_ssl_policy.ssl_policy]
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

resource "google_compute_ssl_policy" "ssl_policy" {
  name            = "${local.name_prefix}-ssl-policy"
  profile         = "MODERN"
  min_tls_version = "TLS_1_2"
}

# Managed Instance Group for Apigee
resource "google_compute_subnetwork" "apigee_mig" {
  project                  = local.project_id
  name                     = "${local.int-apigee-mig}-subnetwork"
  ip_cidr_range            = var.int_apigee_ip_range
  region                   = var.region
  network                  = data.google_compute_network.alb_vpc_network.id
  private_ip_google_access = true
}

# External Load Balancer for CSO Portal UI
module "ui_loadbalancer" {
  source  = "GoogleCloudPlatform/lb-http/google//modules/serverless_negs"
  version = "~> 11.1.0"
  name    = "${local.name_prefix}-ui-xlb"
  project = local.project_id

  backends = {
    ui = {
      description     = "D-TRO CSO Service UI"
      timeout_sec     = 302
      enable_cdn      = false
      security_policy = module.service_ui_cloud_armor.policy.self_link

      groups = [
        {
          group = google_compute_region_network_endpoint_group.service_ui_serverless_neg.id
        }
      ]

      iap_config = {
        enable               = true
        oauth2_client_id     = var.iap_config_client_id
        oauth2_client_secret = var.iap_config_client_secret
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
  ssl_certificates                = [google_compute_managed_ssl_certificate.ui-alb-ssl-cert.id]
  managed_ssl_certificate_domains = []
  create_url_map                  = true
  ssl_policy                      = google_compute_ssl_policy.ui_ssl_policy.self_link

  depends_on = [google_compute_global_address.ui_external_ipv4_address, google_compute_managed_ssl_certificate.ui-alb-ssl-cert, google_compute_ssl_policy.ui_ssl_policy]
}

# Create IPV4 HTTPS IP Address for the UI
resource "google_compute_global_address" "ui_external_ipv4_address" {
  project    = local.project_id
  name       = "${local.name_prefix}-ui-xlb-ipv4-address"
  ip_version = "IPV4"
}

resource "google_compute_managed_ssl_certificate" "ui-alb-ssl-cert" {
  project = local.project_id
  name    = "${local.name_prefix}-ui-xlb-ssl-cert"
  managed {
    domains = [var.ui_domain[var.environment]]
  }
}

resource "google_compute_ssl_policy" "ui_ssl_policy" {
  name            = "${local.name_prefix}-ui-xlb-ssl-policy"
  profile         = "MODERN"
  min_tls_version = "TLS_1_2"
}

############################################################################

# Internal Load Balancer between Apigee and Cloud Run
# Create a proxy-only subnetwork for internal load balancer
resource "google_compute_subnetwork" "proxy_only_subnetwork" {
  project                  = local.project_id
  name                     = "${local.name_prefix}-loadbalancer-proxy-only-subnetwork"
  ip_cidr_range            = var.int_ilb_proxy_only_subnetwork_range
  region                   = var.region
  network                  = google_compute_network.psc_network.id
  purpose                  = "INTERNAL_HTTPS_LOAD_BALANCER"
  role                     = "ACTIVE"
  private_ip_google_access = true
}

# Create a private subnetwork for the forwarding rule
resource "google_compute_subnetwork" "private_subnetwork" {
  project                  = local.project_id
  name                     = "${local.name_prefix}-forward-rule-private-subnetwork"
  ip_cidr_range            = var.int_ilb_private_subnetwork_range
  region                   = var.region
  network                  = google_compute_network.psc_network.id
  purpose                  = "PRIVATE"
  private_ip_google_access = true

  log_config {
    aggregation_interval = "INTERVAL_10_MIN"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
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
  project                  = local.project_id
  name                     = "${local.name_prefix}psc-private-subnetwork"
  ip_cidr_range            = var.int_psc_private_subnetwork_range
  region                   = var.region
  network                  = google_compute_network.psc_network.id
  purpose                  = "PRIVATE"
  private_ip_google_access = true

  log_config {
    aggregation_interval = "INTERVAL_10_MIN"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_subnetwork" "psc_subnetwork" {
  project                  = local.project_id
  name                     = "${local.name_prefix}-psc-subnetwork"
  ip_cidr_range            = var.int_psc_subnetwork_range
  region                   = var.region
  network                  = google_compute_network.psc_network.id
  purpose                  = "PRIVATE_SERVICE_CONNECT"
  private_ip_google_access = true

  log_config {
    aggregation_interval = "INTERVAL_10_MIN"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
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
  org_id                 = data.terraform_remote_state.primary_default_tfstate.outputs.apigee_org
  endpoint_attachment_id = "${local.name_prefix}-ep-attach-${var.environment}"
  location               = var.region
  service_attachment     = google_compute_service_attachment.psc_attachment.id
}

resource "google_apigee_target_server" "apigee_target_server" {
  name        = "${local.name_prefix}-target-server"
  description = "D-TRO ${var.environment} Apigee Target Server"
  protocol    = "HTTP"
  host        = google_apigee_endpoint_attachment.apigee_endpoint_attachment.host
  port        = 80
  env_id      = google_apigee_environment.apigee_env.id
  s_sl_info {
    enabled                  = false
    ignore_validation_errors = true
  }
}
