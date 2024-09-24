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
      src_ip_ranges = var.gmh_src_ip_ranges
    }
    "allow_pa_addresses" = {
      action        = "allow"
      priority      = 60
      description   = "Allow access from PA offices"
      src_ip_ranges = var.pa_src_ip_ranges
    }
    "allow_non_pa_devices_from_pa_offices" = {
      action        = "allow"
      priority      = 70
      description   = "Allow access from non-PA devices from PA offices"
      src_ip_ranges = var.non_pa_src_ip_ranges
    }
    "all_home_addresses" = {
      action        = "allow"
      priority      = 80
      description   = "Allow access from home"
      src_ip_ranges = var.homesrc_ip_ranges
    }
  }
  pre_configured_rules            = {}
  custom_rules                    = {}
  threat_intelligence_rules       = {}
  adaptive_protection_auto_deploy = { "enable" : false }
}
