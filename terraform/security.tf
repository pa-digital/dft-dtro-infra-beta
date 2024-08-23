module "dtro_security_policy" {
  count  = 0
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
  adaptive_protection_auto_deploy = {}
}

module "service_ui_security_policy" {
  count  = 0
  source = "GoogleCloudPlatform/cloud-armor/google"

  project_id                           = local.project_id
  name                                 = "${local.name_prefix}-service-UI-security-policy"
  description                          = "Cloud Armor security policy for Service UI"
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
  adaptive_protection_auto_deploy = {}
}