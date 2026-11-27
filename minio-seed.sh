#!/usr/bin/env bash
# Sube las imágenes de la aplicación al bucket de MinIO y habilita su descarga pública.
# Terraform pasa el contenedor del entorno. Para repetirlo a mano: bash minio-seed.sh dev
set -euo pipefail

if [[ -z ${MINIO_CONTAINER:-} ]]; then
  case "${1:-prod}" in
    dev|prod) MINIO_CONTAINER="practica2-${1:-prod}-minio" ;;
    *) echo 'Uso: bash minio-seed.sh [dev|prod]' >&2; exit 2 ;;
  esac
fi
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
images_dir=${IMAGES_DIR:-"$script_dir/app/static/images"}
bucket=${IMAGES_BUCKET:-seleccion}

# El tar conserva las rutas relativas, como jugadores/david-raya.avif.
# Tanto los ficheros de paso como la configuración de mc son temporales.
tar -C "$images_dir" -cf - . | docker exec -i "$MINIO_CONTAINER" bash -euc '
  bucket=$1
  work=$(mktemp -d)
  trap '\''rm -rf -- "$work"'\'' EXIT
  mkdir "$work/images"
  tar -xf - -C "$work/images"

  export MC_CONFIG_DIR="$work/mc"
  mc alias set seed "http://127.0.0.1:${MINIO_API_PORT_NUMBER}" \
    "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" >/dev/null
  mc mb --ignore-existing "seed/$bucket"
  mc cp --recursive "$work/images/" "seed/$bucket/"
  mc anonymous set download "seed/$bucket"
' bash "$bucket"
