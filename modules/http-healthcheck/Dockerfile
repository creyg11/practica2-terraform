# Estos servicios no traen un cliente HTTP. Reutilizamos el BusyBox estático
# de la imagen de Loki que ya usa la práctica para ejecutar wget como healthcheck.
ARG BASE_IMAGE
FROM grafana/loki:3.5.3 AS herramientas
FROM ${BASE_IMAGE}
COPY --from=herramientas /busybox/busybox /usr/local/bin/busybox
