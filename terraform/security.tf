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
  default_rule_action                  = "allow"
  type                                 = "CLOUD_ARMOR"
  layer_7_ddos_defense_enable          = true
  layer_7_ddos_defense_rule_visibility = "STANDARD"
  json_parsing                         = "STANDARD"
  log_level                            = "NORMAL"

  pre_configured_rules            = {}
  security_rules                  = {} #TODO: Update this with whitelist IP address for DfT network and CSO's IP
  custom_rules                    = {}
  threat_intelligence_rules       = {}
  adaptive_protection_auto_deploy = { "enable" : false }
}

resource "google_iap_brand" "project_brand" {
  support_email     = var.execution_service_account
  application_title = "${local.name_prefix}-IAP"
  project           = local.project_id
}
