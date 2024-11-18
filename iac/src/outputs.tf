output "backend_endpoint" {
  description = "Endpoint that the API Gateway will be available"
  value       = "https://${var.backend_subdomain}.${var.domain}"
}

output "frontend_endpoint" {
  description = "Endpoint frontend website will be available"
  value       = "https://${var.frontend_subdomain}.${var.domain}"
}