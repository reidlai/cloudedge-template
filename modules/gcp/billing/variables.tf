variable "project_id" {
  description = "The GCP Project ID."
  type        = string
}

variable "billing_account" {
  description = "The GCP Billing Account ID."
  type        = string
}

variable "budget_amount" {
  description = "The budget amount in HKD."
  type        = number
  default     = 1000
}
