output "apigee_org" {
  value = google_apigee_organization.apigee_org.id
}

output "apigee_instance_id" {
  value = google_apigee_instance.apigee_instance.id
}

output "apigee_instance_host" {
  value = google_apigee_instance.apigee_instance.host
}

output "apigee_mig_instance_group" {
  value = google_compute_region_instance_group_manager.apigee_mig.instance_group
}
