output "container_name" {
  description = "Nombre del contenedor Docker para identificar su healthcheck en Grafana."
  value       = docker_container.db.name
}

output "host" {
  description = "Alias que usa Flask en la red del entorno."
  value       = var.db_host
  # Flask recibe el alias cuando el contenedor ha pasado su healthcheck (wait = true).
  depends_on = [docker_container.db]
}
