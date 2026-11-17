# Práctica 2: infraestructura como código con Terraform

Migración progresiva de la [práctica 1](https://github.com/creyg11/practica1-docker)
de Docker Compose a Terraform, utilizando el provider de Docker para desplegar
los servicios en local.

La aplicación de partida es una web de la selección española de fútbol,
desarrollada con Flask, PostgreSQL y Redis. Reutilizaremos la aplicación y sus
Dockerfiles, trasladando la definición de la infraestructura a archivos `.tf`.

## Estado actual

Repositorio inicial preparado. La aplicación y la infraestructura Terraform
todavía no se han incorporado; aún no hay un despliegue ejecutable ni pruebas
de servicios realizadas en este repositorio.

## Forma de trabajo

Cada avance tendrá un objetivo pequeño: explicar el cambio, implementarlo,
comprobarlo y realizar su commit y push. La documentación se actualizará con
los comandos y resultados realmente verificados.

## Pasos previstos

1. Preparar el repositorio público y las exclusiones de Git.
2. Incorporar el código de la aplicación y la inicialización de la base de datos.
3. Configurar el provider de Docker y migrar red, volumen, PostgreSQL y web
   en pasos separados.
4. Organizar módulos reutilizables y los entornos `dev` y `pro`, con configuración
   mediante `terraform.tfvars` y recursos independientes.
5. Añadir Redis, réplicas web y un balanceador de carga.
6. Incorporar almacenamiento compartido para estáticos, preferiblemente MinIO.
7. Añadir monitorización, logs centralizados y alertas.
8. Completar el Makefile, las pruebas, el diagrama y la guía de demostración.

## Objetivo de los entornos

Ambos entornos deberán funcionar simultáneamente y desplegar todos los servicios.

| Requisito | Desarrollo (`dev`) | Producción (`pro`) |
| --- | --- | --- |
| Instancias web detrás del balanceador | 2 | Al menos 3 |
| Identificación de instancia en la UI | Sí | Sí |
| Base de datos, caché y almacenamiento compartido | Sí | Sí |
| Monitorización de contenedores, CPU y memoria | Sí | Sí |
| Logs centralizados consultables | Sí | Sí |
| Alertas y demostración de un fallo | No obligatorio | Sí |
| Alta disponibilidad del servicio web | No obligatoria | Sí |

La práctica anterior utiliza `prod`; en este repositorio usaremos `pro`, como
en el enunciado. La adaptación de la configuración de la aplicación se hará
durante la migración.

## Archivos locales

Los estados y planes de Terraform, la carpeta `.terraform/` y los archivos con
configuración privada se excluyen de Git. Se podrán publicar plantillas
`*.tfvars.example` y `.env.example` con valores de ejemplo. El archivo
`.terraform.lock.hcl` sí se versionará cuando se inicialice el provider.
