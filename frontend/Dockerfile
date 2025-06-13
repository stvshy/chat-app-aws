# Etap 1: Budowanie aplikacji
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
# Ta komenda usunie plik .env i użyje względnych ścieżek
RUN npm run build

# Etap 2: Serwowanie statycznych plików za pomocą serve
FROM node:20-alpine
# Zainstaluj tylko `serve`
RUN npm install -g serve

WORKDIR /app

# Kopiuj tylko zbudowaną aplikację i nowy, prosty entrypoint
COPY --from=builder /app/dist ./dist
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENV PORT=3000
EXPOSE 3000

ENTRYPOINT ["/entrypoint.sh"]