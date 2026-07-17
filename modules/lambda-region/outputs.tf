output "function_name" {
  value = aws_lambda_function.this.function_name
}

output "function_url" {
  value = aws_lambda_function_url.this.function_url
}

output "function_url_hostname" {
  description = "Bare hostname of the function URL, used as the Route53 health-check target."
  value       = replace(replace(aws_lambda_function_url.this.function_url, "https://", ""), "/", "")
}
