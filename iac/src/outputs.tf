output "backend_endpoint" {
  description = "Endpoint that the API Gateway will be available"
  value = "https://${var.backend_subdomain}.${var.domain}"
}