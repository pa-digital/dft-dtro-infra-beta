module "postgres_db" {
  source  = "GoogleCloudPlatform/sql-db/google//modules/postgresql"
  version = "20.1.0"

  project_id        = local.project_id
  region            = var.region
  availability_type = var.database_availability_type

  database_version = "POSTGRES_15"
  tier             = var.database_environment_configuration[var.environment].tier

  name      = "${local.name_prefix}-postgres"
  db_name   = local.database_name
  user_name = local.database_username

  deletion_protection         = var.environment != "prod" ? false : true
  deletion_protection_enabled = var.environment != "prod" ? false : true

  disk_size                      = var.database_environment_configuration[var.environment].disk_size
  disk_type                      = "PD_SSD"
  disk_autoresize                = true
  disk_autoresize_limit          = var.database_environment_configuration[var.environment].disk_autoresize_limit
  enable_random_password_special = true

  insights_config = {
    query_string_length     = 1024
    record_application_tags = false
    record_client_address   = true
  }

  ip_configuration = {
    allocated_ip_range                            = module.cloudsql_private_service_access.google_compute_global_address_name
    authorized_networks                           = []
    enable_private_path_for_google_cloud_services = true
    ipv4_enabled                                  = false
    private_network                               = module.backend_vpc_network.network_self_link
    require_ssl                                   = true
    ssl_mode                                      = "TRUSTED_CLIENT_CERTIFICATE_REQUIRED"
  }

  maintenance_window_day          = 7
  maintenance_window_hour         = 3
  maintenance_window_update_track = "stable"

  database_flags = [
    {
      name  = "max_connections"
      value = var.database_environment_configuration[var.environment].max_connections
    }
  ]

  # Basic, single region backups
  backup_configuration = {
    enabled                        = true
    location                       = var.region
    start_time                     = "23:00" # Before maintenance window
    point_in_time_recovery_enabled = var.database_backups_pitr_enabled
    transaction_log_retention_days = var.database_backups_pitr_days
    retained_backups               = var.database_backups_number_of_stored_backups
    retention_unit                 = "COUNT"
  }

  module_depends_on = [module.cloudsql_private_service_access.peering_completed]
}
