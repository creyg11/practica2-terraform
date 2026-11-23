variable "container_name" {
  description = "Nombre del contenedor en Docker."
  type        = string
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

variable "web_external_port" {
  description = "Puerto publicado en la máquina."
  type        = number
}

variable "web_bind_ip" {
  description = "IP de la máquina donde se publica la web."
  type        = string
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
