# Etap 1: Budowanie aplikacji
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

# Etap 2: Serwowanie statycznych plików za pomocą serve
FROM node:20-alpine
# Zainstaluj `serve` i `gettext` (dostarcza `envsubst`)
RUN apk add --no-cache gettext
RUN npm install -g serve

WORKDIR /app

COPY --from=builder /app/dist ./dist
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh                # Upewnij się, że jest wykonywalny

# PORT jest już ustawiany przez Elastic Beanstalk, ale możemy zdefiniować domyślny
ENV PORT=3000
EXPOSE 3000

ENTRYPOINT ["/entrypoint.sh"]
