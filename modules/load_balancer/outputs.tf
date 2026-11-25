output "container_name" {
  description = "Nombre del contenedor Docker para identificar su healthcheck en Grafana."
  value       = docker_container.load_balancer.name
}
