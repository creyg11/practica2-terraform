variable "web_internal_port" {
  description = "Puerto en el que escucha la aplicación dentro del contenedor."
  type        = number
}

variable "web_replica_count" {
  description = "Número de contenedores Flask entre los que Nginx reparte las peticiones."
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

variable "db_host" {
  description = "Nombre o alias de PostgreSQL en la red compartida con la web."
  type        = string
}

variable "db_port" {
  description = "Puerto interno de PostgreSQL al que se conecta la aplicación."
  type        = number
}

variable "postgres_db" {
  description = "Nombre de la base de datos de la aplicación."
  type        = string
}

variable "postgres_user" {
  description = "Usuario con el que la aplicación se conecta a PostgreSQL."
  type        = string
}

variable "postgres_password" {
  description = "Contraseña del usuario de PostgreSQL."
  type        = string
  sensitive   = true
}
