variable "alert_email" {
  description = "Servidor SMTP y destinatario de las alertas de prod. Rellenar en terraform.tfvars local."
  type = object({
    host          = string
    from          = string
    to            = string
    user          = string
    password_file = string
  })
  sensitive = true
  default   = null
}

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

variable "redis_host" {
  description = "Alias de Redis en la red de producción que Flask usa para conectarse."
  type        = string
}

variable "redis_port" {
  description = "Puerto interno en el que escucha Redis."
  type        = number
}

variable "minio_host" {
  description = "Alias de MinIO en la red interna que usan los clientes S3."
  type        = string
}

variable "minio_api_port" {
  description = "Puerto S3 de MinIO en la red interna."
  type        = number
  default     = 9000
}

variable "minio_console_port" {
  description = "Puerto de la consola web de MinIO en la red interna."
  type        = number
  default     = 9001
}

variable "minio_root_user" {
  description = "Usuario administrador (access key) de MinIO."
  type        = string
}

variable "minio_root_password" {
  description = "Contraseña administradora (secret key) de MinIO."
  type        = string
  sensitive   = true
}

variable "docker_socket_gid" {
  description = "Grupo propietario de /var/run/docker.sock en el host de producción."
  type        = number
}

variable "grafana_port" {
  description = "Puerto de localhost para abrir la interfaz de Grafana en prod."
  type        = number
}

variable "grafana_admin_password" {
  description = "Contraseña inicial del usuario admin de Grafana en prod."
  type        = string
  sensitive   = true
}
