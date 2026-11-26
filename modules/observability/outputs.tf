output "prometheus_name" {
  description = "Nombre con el que Grafana puede localizar Prometheus dentro de Docker."
  value       = docker_container.prometheus.name
}

output "container_names" {
  description = "Contenedores de métricas desplegados en este entorno, incluidos los exporters opcionales."
  value = concat(
    [docker_container.prometheus.name, docker_container.nginx_exporter.name],
    docker_container.postgres_exporter[*].name,
    docker_container.redis_exporter[*].name,
    docker_container.telegraf[*].name,
  )
}
