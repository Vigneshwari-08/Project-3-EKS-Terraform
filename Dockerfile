FROM nginx:latest

COPY app/ /usr/share/nginx/html

COPY nginx.conf /etc/nginx/nginx.conf

HEALTHCHECK CMD curl --fail http://localhost || exit 1