FROM nginxinc/nginx-unprivileged:mainline-alpine
# Parches de seguridad del SO (detectados por Trivy)
USER 0
# hadolint ignore=DL3017,DL3018
RUN apk upgrade --no-cache
USER 101
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY src/ /usr/share/nginx/html/
EXPOSE 8080
