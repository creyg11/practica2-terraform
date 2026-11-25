variable "container_name" {
  type = string
}

variable "public_network_name" {
  type = string
}

variable "internal_network_name" {
  type = string
}

variable "bind_ip" {
  type = string
}

variable "external_port" {
  type = number
}

variable "prometheus_name" {
  description = "Nombre del contenedor de Prometheus en este entorno."
  type        = string
}

variable "admin_password" {
  description = "Contraseña inicial del administrador. Grafana la guarda al crear su base de datos."
  type        = string
  sensitive   = true
}

variable "web_replicas" {
  description = "Nombres de las réplicas Flask del entorno que mostramos en Grafana."
  type        = list(string)
}

variable "health_services" {
  description = "Contenedores de la aplicación además de las réplicas web: base de datos, MinIO, Nginx y caché si existe."
  type        = list(string)
}
