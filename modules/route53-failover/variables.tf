variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "primary_endpoint_hostname" {
  type = string
}

variable "secondary_endpoint_hostname" {
  type = string
}

variable "hosted_zone_id" {
  type    = string
  default = null
}

variable "dns_record_name" {
  type    = string
  default = null
}

variable "failure_threshold" {
  type    = number
  default = 3
}

variable "request_interval" {
  type    = number
  default = 10
}

variable "record_ttl" {
  type    = number
  default = 30
}

variable "alarm_notification_email" {
  type    = string
  default = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
