output "host" {
  description = "Alias que usa Flask en la red del entorno."
  value       = var.redis_host
  # Flask recibe el alias cuando el contenedor ha pasado su healthcheck (wait = true).
  depends_on = [docker_container.redis]
}
