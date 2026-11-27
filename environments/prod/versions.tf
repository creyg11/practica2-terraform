terraform {
  # La carga inicial de MinIO usa terraform_data, disponible desde Terraform 1.4.
  required_version = ">= 1.4.0, < 2.0.0"

  required_providers {
    docker = {
      # Docker Engine 29.1.3 exige la API 1.44 como mínimo; el proveedor de clase usaba la 1.41.
      source  = "kreuzwerker/docker"
      version = "~> 4.6.0"
    }
  }
}
