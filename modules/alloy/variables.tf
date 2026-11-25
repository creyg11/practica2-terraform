variable "container_name" {
  type = string
}

variable "internal_network_name" {
  description = "Red Docker del entorno. Alloy descubre los contenedores conectados a ella."
  type        = string
}

variable "loki_url" {
  description = "Dirección interna que publica el módulo Loki."
  type        = string
}
