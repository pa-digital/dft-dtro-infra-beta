output "apigee_org" {
  value = google_apigee_organization.apigee_org.id
}

output "apigee_instance_id" {
  value = google_apigee_instance.apigee_instance.id
}

output "apigee_instance_host" {
  value = google_apigee_instance.apigee_instance.host
}
