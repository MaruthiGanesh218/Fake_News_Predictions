# NEWS CHUNK 10 — Deployment & Verification Automation
# Author: GPT-5 Codecs (acting as a 30-40 year experienced software engineer)
# Behavior: Full write access. Create files, run checks, save results.

# syntax=docker/dockerfile:1.6

##############################
# Build stage: compile the production bundle
FROM node:18-alpine AS build

ENV NODE_ENV=production

WORKDIR /frontend

# Install build dependencies
COPY package.json package-lock.json* /frontend/
RUN npm ci --prefer-offline --no-audit --fund=false

COPY . /frontend
RUN npm run build

##############################
# Runtime stage: serve static assets via nginx
FROM nginx:stable-alpine

ENV NODE_ENV=production

# Remove default configuration and replace with hardened variant
RUN rm -f /etc/nginx/conf.d/default.conf

COPY --from=build /frontend/dist /usr/share/nginx/html

RUN cat <<'NGINX' > /etc/nginx/conf.d/default.conf
server {
    listen       8080;
    listen       [::]:8080;
    server_name  _;

    root   /usr/share/nginx/html;
    index  index.html;

    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options SAMEORIGIN;
    add_header X-XSS-Protection "1; mode=block";
    add_header Referrer-Policy "strict-origin-when-cross-origin";
    add_header Content-Security-Policy "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self'";

    gzip on;
    gzip_types text/plain application/json text/css application/javascript application/x-javascript text/xml application/xml application/xml+rss text/javascript;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location = /health {
        default_type application/json;
        return 200 '{"status":"ok"}';
    }
}
NGINX

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://127.0.0.1:8080/health || exit 1
