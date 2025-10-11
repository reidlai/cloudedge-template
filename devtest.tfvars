client  = "yourclient"
project = "yourproject"
env     = "devtest"
cloud   = "gcp"
region  = "us-central1"
domain  = "example.com"

ingress_vpc_cidr = "10.0.0.0/16"
egress_vpc_cidr = "10.1.0.0/16"

# For GCP
gcp_project_id = "your-gcp-project-id"

# For Azure
resource_group_name = "your-resource-group-name"
azure_subscription_id = "your-azure-subscription-id"

# For AWS
# No specific variables needed here for basic setup, as they are handled by the adapter module.
