# Etap 1: Budowanie aplikacji
FROM node:20-alpine AS builder
WORKDIR /app

# Kopiujemy pliki konfiguracyjne i instalujemy zależności
COPY package*.json ./
RUN npm install

# Kopiujemy resztę plików i budujemy aplikację (produkcja)
COPY . .
RUN npm run build
# Zakładamy, że wynik budowania trafia do katalogu "dist"

# Etap 2: Serwowanie statycznych plików za pomocą serve
FROM node:20-alpine
RUN npm install -g serve
COPY --from=builder /app/dist /app/dist
ENV PORT=3000
EXPOSE 3000
CMD ["serve", "-s", "/app/dist", "-l", "3000"]
