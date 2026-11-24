variable "container_name" {
  description = "Nombre del contenedor Nginx de este entorno."
  type        = string
}

variable "public_network_name" {
  description = "Red pública (DMZ) desde donde Nginx expone el puerto al host"
  type        = string
}

variable "internal_network_name" {
  description = "Red privada aislada donde se comunican los servicios internos"
  type        = string
}

variable "nombres_replicas" {
  description = "Nombres Docker que la plantilla escribe en el grupo de servidores Flask."
  type        = list(string)
}

variable "web_internal_port" {
  description = "Puerto en el que escucha la aplicación dentro del contenedor."
  type        = number
}

variable "nginx_port" {
  description = "Puerto de escucha de Nginx, publicado con el mismo número en la máquina."
  type        = number
}

variable "nginx_bind_ip" {
  description = "IP de la máquina donde Docker publica el puerto de Nginx."
  type        = string
}

variable "minio_host_port" {
  description = "Nombre DNS y puerto de la API de MinIO en la red interna."
  type        = string
}

variable "images_bucket" {
  description = "Bucket que Nginx consulta para las peticiones a /static/images/."
  type        = string
}
