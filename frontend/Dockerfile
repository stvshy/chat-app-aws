# Etap 1: Budowanie aplikacji
FROM node:20-alpine AS builder
 # Używamy obrazu Node.js 20 (Alpine) i nadajemy mu alias "builder"
WORKDIR /app
 # Ustawiamy katalog roboczy na /app


# Kopiujemy pliki konfiguracyjne i instalujemy zależności
COPY package*.json ./
 # Kopiujemy pliki package.json i package-lock.json do katalogu /app
RUN npm install
# Instalujemy zależności określone w package.json

# Kopiujemy resztę plików i budujemy aplikację (produkcja)
COPY . .
# Kopiujemy cały pozostały kod źródłowy do katalogu /app
RUN npm run build
 # Budujemy aplikację (wynik trafia do katalogu "dist")

# Etap 2: Serwowanie statycznych plików za pomocą serve
FROM node:20-alpine
# Używamy ponownie obrazu Node.js 20 (Alpine) jako bazowego dla uruchomienia aplikacji
RUN npm install -g serve
# Instalujemy globalnie pakiet "serve" do serwowania statycznych plików
COPY --from=builder /app/dist /app/dist
# Kopiujemy folder "dist" z etapu "builder" do katalogu /app/dist w nowym obrazie
ENV PORT=3000
# Ustawiamy zmienną środowiskową PORT na 3000
EXPOSE 3000
# Deklarujemy, że aplikacja nasłuchuje na porcie 3000 (informacja dla użytkowników i narzędzi)
CMD ["serve", "-s", "/app/dist", "-l", "3000"]
# Uruchamiamy serwer "serve", który serwuje pliki z katalogu /app/dist na porcie 3000
