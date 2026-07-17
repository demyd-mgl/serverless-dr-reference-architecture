variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "region_name" {
  description = "Human-readable region tag used in resource names (e.g. 'primary', 'secondary')."
  type        = string
}

variable "lambda_source_dir" {
  type = string
}

variable "lambda_runtime" {
  type    = string
  default = "python3.12"
}

variable "lambda_timeout" {
  type    = number
  default = 10
}

variable "lambda_memory_size" {
  type    = number
  default = 128
}

variable "dynamodb_table_name" {
  type = string
}

variable "dynamodb_table_arn" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
