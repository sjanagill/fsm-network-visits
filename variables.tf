variable "project_id" {
  type    = string
  default = "fsm-project"
}

variable "location" {
  type    = string
  default = "EU"
}

variable "region" {
  type    = string
  default = "europe-west2"
}

variable "zone" {
  type    = string
  default = "europe-west2-a"
}

variable "service_account_email" {
  type    = string
  default = "your-service-account-email@your-project-id.iam.gserviceaccount.com"

}
