variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "secondary_region" {
  description = "Region to place the global table replica in."
  type        = string
}

variable "billing_mode" {
  type    = string
  default = "PAY_PER_REQUEST"
}

variable "tags" {
  type    = map(string)
  default = {}
}
