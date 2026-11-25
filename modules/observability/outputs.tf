output "prometheus_name" {
  description = "Nombre con el que Grafana puede localizar Prometheus dentro de Docker."
  value       = docker_container.prometheus.name
}
