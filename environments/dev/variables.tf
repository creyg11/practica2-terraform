variable "web_internal_port" {
  description = "Puerto en el que escucha la aplicación dentro del contenedor."
  type        = number
}

variable "web_external_port" {
  description = "Puerto publicado en la máquina para acceder a la web."
  type        = number
}

variable "web_bind_ip" {
  description = "Dirección IP de la máquina donde se publica el puerto de la web."
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
