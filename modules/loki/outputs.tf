output "container_name" {
  value = docker_container.loki.name
}

output "url" {
  description = "Dirección HTTP de Loki dentro de la red del entorno."
  value       = "http://${docker_container.loki.name}:3100"
}
