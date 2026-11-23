variable "container_name" {
  description = "Nombre del contenedor Nginx de este entorno."
  type        = string
}

variable "network_name" {
  description = "Red Docker que comparten Nginx y las réplicas Flask."
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
