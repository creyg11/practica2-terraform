output "url" {
  description = "Dirección HTTP de Loki dentro de la red del entorno."
  value       = "http://${docker_container.loki.name}:3100"
}
