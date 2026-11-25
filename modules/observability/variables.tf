variable "name_prefix" {
  description = "Prefijo de entorno para contenedores y volúmenes (ej. practica2-prod)."
  type        = string
}

variable "public_network_name" {
  description = "Red pública (DMZ) para publicar la interfaz web de Prometheus en 127.0.0.1."
  type        = string
}

variable "internal_network_name" {
  description = "Red interna aislada donde se recolectan métricas y logs."
  type        = string
}

variable "nginx_container_name" {
  description = "Nombre DNS interno del balanceador Nginx a monitorizar."
  type        = string
}

variable "bind_ip" {
  description = "IP local del host donde se exponen las interfaces de monitorización."
  type        = string
  default     = "127.0.0.1"
}

variable "prometheus_port" {
  description = "Puerto de Prometheus en el host (9090 en prod, 9091 en dev)."
  type        = number
}

variable "enable_extended_metrics" {
  description = "Activa las métricas de PostgreSQL y contenedores. Redis se incluye cuando el entorno configura su caché."
  type        = bool
  default     = false
}

variable "db_dsn" {
  description = "Cadena de conexión PostgreSQL para postgres_exporter."
  type        = string
  default     = ""
  sensitive   = true
}

variable "cache_container_name" {
  description = "Nombre DNS interno del contenedor Redis/Cache."
  type        = string
  default     = ""
}

variable "docker_socket_gid" {
  description = "GID del socket de Docker que usa Telegraf para consultar el host."
  type        = number
  default     = null
}

variable "additional_container_patterns" {
  description = "Patrones de nombres Docker del entorno que no empiezan por name_prefix."
  type        = list(string)
  default     = []
}

variable "web_container_name" {
  description = "Nombre base de las réplicas usado en las consultas de ejemplo de Telegraf."
  type        = string
  default     = null
}
