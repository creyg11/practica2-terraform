variable "container_name" {
  description = "Nombre del contenedor MinIO en Docker."
  type        = string
}

variable "network_name" {
  description = "Nombre de la red Docker interna del entorno."
  type        = string
}

variable "minio_host" {
  description = "Alias de MinIO en la red interna que usan los clientes para conectarse."
  type        = string
}

variable "minio_api_port" {
  description = "Puerto S3-compatible en el que MinIO atiende peticiones de la aplicación."
  type        = number
  default     = 9000
}

variable "minio_console_port" {
  description = "Puerto de la consola web de administración de MinIO."
  type        = number
  default     = 9001
}

variable "minio_root_user" {
  description = "Usuario administrador (access key) de MinIO."
  type        = string
}

variable "minio_root_password" {
  description = "Contraseña administradora (secret key) de MinIO. Mínimo 8 caracteres."
  type        = string
  sensitive   = true
}

variable "volume_name" {
  description = "Nombre del volumen Docker donde MinIO persiste los objetos."
  type        = string
}

variable "restart" {
  description = "Política de reinicio del contenedor."
  type        = string
  default     = "no"
}

variable "images_dir" {
  description = "Directorio de imágenes que se carga en el bucket de este entorno."
  type        = string
}
