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

variable "volume_name" {
  description = "Nombre del volumen persistente de este entorno."
  type        = string
}

variable "init_dir" {
  description = "Directorio de scripts SQL para inicializar un volumen vacío."
  type        = string
}

variable "db_host" {
  description = "Alias de PostgreSQL en la red."
  type        = string
}

variable "db_port" {
  description = "Puerto interno de PostgreSQL."
  type        = number
}

variable "postgres_db" {
  description = "Nombre de la base de datos."
  type        = string
}

variable "postgres_user" {
  description = "Usuario de PostgreSQL."
  type        = string
}

variable "postgres_password" {
  description = "Contraseña del usuario de PostgreSQL."
  type        = string
  sensitive   = true
}
