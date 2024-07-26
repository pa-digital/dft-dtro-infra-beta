import {
  id = var.project_id
  to = google_apigee_organization.apigee_org
}

import {
  id = "${var.organisation_id}/${var.application_name}-apigee-instance"
  to = google_apigee_instance.apigee_instance
}
