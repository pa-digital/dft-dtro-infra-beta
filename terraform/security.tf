module "dtro_cloud_armor" {
  source = "GoogleCloudPlatform/cloud-armor/google"

  project_id                           = local.project_id
  name                                 = "${local.name_prefix}-security-policy"
  description                          = "Cloud Armor security policy for D-TRO"
  default_rule_action                  = "allow"
  type                                 = "CLOUD_ARMOR"
  layer_7_ddos_defense_enable          = true
  layer_7_ddos_defense_rule_visibility = "STANDARD"
  json_parsing                         = "STANDARD"
  log_level                            = "NORMAL"

  pre_configured_rules            = {}
  security_rules                  = {}
  custom_rules                    = {}
  threat_intelligence_rules       = {}
  adaptive_protection_auto_deploy = { "enable" : false }
}

module "service_ui_cloud_armor" {
  source = "GoogleCloudPlatform/cloud-armor/google"

  project_id                           = local.project_id
  name                                 = "${local.name_prefix}-service-ui-security-policy"
  description                          = "Cloud Armor security policy for Service UI"
  default_rule_action                  = "deny(403)"
  type                                 = "CLOUD_ARMOR"
  layer_7_ddos_defense_enable          = true
  layer_7_ddos_defense_rule_visibility = "STANDARD"
  json_parsing                         = "STANDARD"
  log_level                            = "NORMAL"

  security_rules = {
    "allow_gmh_addresses" = {
      action        = "allow"
      priority      = 50
      description   = "Allow access from Great Minster House"
      src_ip_ranges = ["147.161.225.0/24", "167.98.253.0/24", "172.16.15.0/24"] # TODO: Parameterise this so its different for each env.
    }
    "allow_pa_addresses" = {
      action        = "allow"
      priority      = 60
      description   = "Allow access from PA offices"
      src_ip_ranges = ["12.226.4.157/32", "72.43.134.135/32", "77.233.248.46/32", "80.169.67.48/32", "80.169.67.56/32", "194.75.196.200/32", "194.75.196.216/32", "207.242.146.189/32", "217.38.8.142/32"]
    }
    "allow_non_pa_devices_from_pa_offices" = {
      action        = "allow"
      priority      = 70
      description   = "Allow access from non-PA devices from PA offices"
      src_ip_ranges = ["137.220.80.0/24", "165.225.17.0/24", "165.225.81.0/24", "178.239.194.0/24"]
    }
    "all_home_addresses" = {
      action        = "allow"
      priority      = 80
      description   = "Allow access from home"
      src_ip_ranges = ["192.168.1.0/24"]
    }
    #     "deny_everything_else" = {
    #       action        = "deny(403)"
    #       priority      = 200
    #       description   = "Deny everything else"
    #       src_ip_ranges = ["*"]
    #     }
  }

  pre_configured_rules            = {}
  custom_rules                    = {}
  threat_intelligence_rules       = {}
  adaptive_protection_auto_deploy = { "enable" : false }
}
