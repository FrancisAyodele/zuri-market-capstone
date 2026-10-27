# Stage 1: build the React app
FROM node:22-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci --ignore-scripts
COPY . .
# "." makes the app call ./api/... on whatever host served it (same origin), so one image
# works behind Compose's nginx proxy and the Kubernetes Ingress. An empty value would make
# App.jsx fall back to http://localhost:5001, which only works on a developer laptop.
ARG VITE_API_URL=.
ARG VITE_STORE_NAME="Zuri Market"
ENV VITE_API_URL=$VITE_API_URL VITE_STORE_NAME=$VITE_STORE_NAME
RUN npm run build

# Stage 2: serve the static files
FROM nginxinc/nginx-unprivileged:stable-alpine
USER root
# pull the fixed brotli/curl versions
RUN apk upgrade --no-cache
# back to the image's non-root nginx user
USER 101
COPY --chmod=0644 nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 8080
