# VPC Access Connector is managed externally
# This data source references the existing connector
data "google_vpc_access_connector" "web_connector" {
  count  = var.enable_web_vpc && var.enable_demo_web_app ? 1 : 0
  name   = "${var.project_suffix}-web-connector"
  region = var.region
}
