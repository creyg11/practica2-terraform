variable "container_name" {
  description = "Nombre base al que se añade el número de cada réplica."
  type        = string
}

variable "replica_count" {
  description = "Número de contenedores creados a partir de la imagen Flask."
  type        = number
  default     = 2

  validation {
    condition     = var.replica_count >= 1 && floor(var.replica_count) == var.replica_count
    error_message = "El grupo de servidores de Nginx necesita al menos una réplica y la cantidad debe ser entera."
  }
}

variable "network_name" {
  description = "Nombre de la red Docker del entorno."
  type        = string
}

variable "restart" {
  description = "Política de reinicio del contenedor."
  type        = string
  default     = "no"
}

variable "image_name" {
  description = "Nombre y etiqueta de la imagen Flask."
  type        = string
}

variable "build_context" {
  description = "Ruta al directorio compartido de la aplicación."
  type        = string
}

variable "dockerfile" {
  description = "Dockerfile que construye la aplicación de este entorno."
  type        = string
}

variable "web_internal_port" {
  description = "Puerto en el que escucha Flask."
  type        = number
}

variable "env" {
  description = "Variables de entorno que recibe Flask en formato CLAVE=VALOR."
  type        = set(string)
  sensitive   = true
}

variable "aliases" {
  description = "Alias de la web en la red del entorno."
  type        = set(string)
  default     = []
}
