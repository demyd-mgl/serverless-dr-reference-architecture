variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "enable_replication_time_control" {
  type    = bool
  default = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
