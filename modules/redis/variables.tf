variable "container_name" {
  description = "Nombre del contenedor en Docker."
  type        = string
}

variable "network_name" {
  description = "Nombre de la red Docker del entorno."
  type        = string
}

variable "redis_host" {
  description = "Alias de Redis en la red."
  type        = string
}

variable "redis_port" {
  description = "Puerto interno en el que escucha Redis."
  type        = number
}
