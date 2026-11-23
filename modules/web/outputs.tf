output "nombres_replicas" {
  description = "Nombres Docker de todas las réplicas que se escribirán en el upstream de Nginx."
  value       = docker_container.web[*].name
}
