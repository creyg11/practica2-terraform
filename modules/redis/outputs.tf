output "container_name" {
  description = "Nombre del contenedor Docker para identificar su healthcheck en Grafana."
  value       = docker_container.redis.name
}

output "host" {
  description = "Alias que usa Flask en la red del entorno."
  value       = var.redis_host
  # Flask recibe el alias cuando el contenedor ha pasado su healthcheck (wait = true).
  depends_on = [docker_container.redis]
}
