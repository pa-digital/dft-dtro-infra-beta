# Core D-TRO variables
variable "tf_state_bucket" {
  type        = string
  description = "Name of bucket where Terraform stores it's state file."
}

variable "environment" {
  type        = string
  description = "GCP environment to which resources will be deployed."
  default     = "dev"
}

variable "integration_prefix" {
  type        = string
  description = "Prefix to denote if deployment is for integration instance. Left blank if for test instance"
  default     = ""
}

variable "region" {
  type        = string
  description = "GCP region to which resources will be deployed."
  default     = "europe-west1"
}

variable "organisation" {
  type        = string
  description = "GCP Organisation for DfT."
  default     = "dft.gov.uk"
}

variable "organisation_id" {
  type        = string
  description = "ID of the GCP Organisation for DfT."
  default     = "251335196181"
}

variable "project_id" {
  type        = string
  description = "GCP project ID to which resources will be deployed."
  default     = "dft-dtro-dev-01"
}

variable "org_domain" {
  type        = string
  description = "DfT's main domain."
  default     = "dft.gov.uk"
}

variable "domain" {
  type        = map(string)
  description = "Name of the domain where the DTRO is published"
  default = {
    dev  = "dtro-integration.dft.gov.uk"
    test = "dtro-integration.dft.gov.uk"
    int  = "dtro-integration.dft.gov.uk"
    prod = "dtro-integration.dft.gov.uk"
  }
}

variable "dtro_service_domain" {
  type        = string
  description = "Name of the domain where the DTRO is published"
  default     = "dtro.dft.gov.uk"
}

variable "application_name" {
  type        = string
  description = "The name the application."
  default     = "dtro"
}

variable "default_machine_type" {
  type        = string
  description = "Defualt machine type to use for non-application Compute Engines."
  default     = "e2-micro"
}

variable "wip_service_account" {
  type        = string
  description = "Service account from Workflow Identity Provider for Terraform to deploy resources."
}

variable "execution_service_account" {
  type        = string
  description = "Service account for executing GCP applications."
}

variable "dtro_service_image" {
  type        = string
  description = "The name of an image being pushed for publish service."
  default     = "dft-dtro-beta"
}

variable "tag" {
  type        = string
  description = "The tag of the image to run."
  default     = "latest"
}

variable "cloud_run_max_concurrency" {
  type        = string
  description = "Maximum number of requests that each serving instance can receive."
  default     = "50"
}

variable "cloud_run_min_instance_count" {
  type        = string
  description = "Minimum number of serving instances DTRO application should have."
  default     = "1"
}

variable "allowed_ips" {
  description = "IPs permitted to access the prototype"
  type        = list(any)
  default     = []
}

variable "db_connections_per_cloud_run_instance" {
  type        = number
  default     = 2
  description = "Maximum size of DB connection pool for each Cloud Run instance"
}

variable "logs_retention_in_days" {
  type        = number
  description = "Retention time of the application logs"
  default     = 180
}

# variable "emails_to_notify" {
#   type        = set(string)
#   description = "Emails to notify about infrastructure issues"
# }

variable "access_level_members" {
  type        = string
  description = "Users to be part of the Access Context Manager"
}

variable "feature_enable_redis_cache" {
  type        = bool
  description = "Feature flag, when enabled MemoryStore (Redis) cache instance is configured and used by the app"
  default     = false
}

variable "database_availability_type" {
  type        = string
  description = "Availability of Postgres database instance"
  default     = "REGIONAL"
}

variable "database_backups_pitr_enabled" {
  type        = bool
  description = "Enables point-in-time recovery for Postgres database"
  default     = true
}

variable "database_backups_pitr_days" {
  type        = string
  description = "Retention policy that determines how many days of transaction logs are stored for point-in-time recovery"
  default     = 2
}

variable "database_backups_number_of_stored_backups" {
  type        = string
  description = "Retention policy that determines how many daily backups of Postgres database are stored"
  default     = 14
}
# Machine types for Cloud SQL Enterprise edition instances (https://cloud.google.com/sql/docs/postgres/create-instance)
# Default value for database_max_connections is depended on Memory on largest instance (https://cloud.google.com/sql/docs/postgres/flags#postgres-m)
variable "database_environment_configuration" {
  type = map(object({
    tier                  = string
    disk_size             = number
    disk_autoresize_limit = number
    max_connections       = number
  }))
  description = "Configuration of Postgres DB for each environment"
  default = {
    dev = {
      tier                  = "db-custom-1-3840" # vCPU:1  RAM MB:3840
      disk_size             = 100
      disk_autoresize_limit = 200
      max_connections       = 100
    }
    test = {
      tier                  = "db-custom-2-7680" # vCPU:2  RAM MB:7680
      disk_size             = 1000
      disk_autoresize_limit = 500
      max_connections       = 400
    }
    prod = {
      tier                  = "db-custom-16-61440" # vCPU:16  RAM MB:61440
      disk_size             = 10000
      disk_autoresize_limit = 0 # The default value is 0, which specifies that there is no limit.(https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_database_instance#disk_autoresize_limit)
      max_connections       = 800
    }
  }
}

variable "serverless_connector_config" {
  type = object({
    machine_type  = string
    min_instances = number
    max_instances = number
  })
  description = "Configuration of Serverless VPC Access connector"
  default = {
    machine_type  = "e2-micro"
    min_instances = 2
    max_instances = 3
  }

  validation {
    condition     = var.serverless_connector_config.min_instances > 1 && var.serverless_connector_config.max_instances > var.serverless_connector_config.min_instances
    error_message = "At least 2 instances must be configured and max instances count must be greater than min instances count."
  }
}

variable "int_backend_vpc_ip_range" {
  type        = string
  description = "IP range for Backend VPC"
  default     = "12.0.0.0/28"
#   default     = "10.70.0.0/28"
}

#TODO: REMOVE
variable "int_serverless_connector_ip_range" {
  type        = string
  description = "IP range for Serverless VPC Access Connector"
  default     = "12.200.0.0/28" # CIDR block with "/28" netmask is required
#   default     = "10.250.0.0/28" # CIDR block with "/28" netmask is required
}

variable "int_apigee_ip_range" {
  type        = string
  description = "IP range for Apigee"
#   default     = "12.10.0.0/16"
  default     = "10.80.0.0/16"
}

variable "int_ui_apigee_ip_range" {
  type        = string
  description = "IP range for Apigee"
  default     = "13.20.0.0/16"
#   default     = "10.85.0.0/16"
}

variable "int_ui_apigee_ip_range_2" {
  type        = string
  description = "IP range for Apigee"
  default     = "13.25.0.0/16"
  #   default     = "10.85.0.0/16"
}

#TODO: REMOVE
variable "int_google_compute_global_address_range" {
  type        = string
  description = "IP range for the Google global address to manage private VPC connection with Apigee"
  default     = "12.8.0.0"
#   default     = "10.88.0.0"
}

variable "int_ilb_proxy_only_subnetwork_range" {
  type        = string
  description = "IP range for the internal ALB proxy only subnetwork"
#   default     = "12.3.0.0/26"
  default     = "10.90.0.0/26"
}

variable "int_ui_ilb_proxy_only_subnetwork_range" {
  type        = string
  description = "IP range for the internal ALB proxy only subnetwork"
#   default     = "13.3.0.0/26"
  default     = "10.95.0.0/26"
}

variable "int_ilb_private_subnetwork_range" {
  type        = string
  description = "IP range for internal ALB private subnetwork"
  default     = "12.2.1.0/24"
#   default     = "10.100.1.0/24"
}

variable "int_ui_ilb_private_subnetwork_range" {
  type        = string
  description = "IP range for internal ALB private subnetwork"
  default     = "13.2.1.0/28"
#   default     = "10.105.1.0/28"
}

variable "int_psc_private_subnetwork_range" {
  type        = string
  description = "IP range for Private Service Connect private subnetwork"
  default     = "12.20.1.0/24"
#   default     = "10.110.1.0/24"
}

variable "int_psc_subnetwork_range" {
  type        = string
  description = "IP range for Private Service Connect subnetwork"
  default     = "12.3.1.0/24"
#   default     = "10.115.1.0/24"
}

variable "google_compute_global_address_prefix_length" {
  type        = number
  description = "Prefix length of the google_compute_global_address_range"
  default     = 16
}

variable "cpu_max_utilization" {
  type        = number
  description = "Maximum utilisation of each CE before auto scaler steps in"
  default     = 0.75
}

variable "redis_memory_size" {
  type        = string
  description = "Redis memory size in GiB"
  default     = 1
}

variable "postgres_host" {
  type        = string
  description = "Postgres database host"
  default     = "127.0.0.1"
}

variable "postgres_password" {
  type        = string
  description = "The password for the database user"
  default     = "Zl\"\"UHXAP{mp?igR"
}

variable "postgres_port" {
  type        = string
  description = "The port on which the Database accepts connections"
  default     = "5432"
}

variable "postgres_use_ssl" {
  type        = string
  description = "Whether or not to use SSL for the connection"
  default     = "true"
}