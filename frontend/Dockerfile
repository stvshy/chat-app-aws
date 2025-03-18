# Używamy lekkiego obrazu Node (np. wersja 20 na Alpine)
FROM node:20-alpine

# Ustawiamy katalog roboczy
WORKDIR /app

# Kopiujemy pliki package.json i package-lock.json – dzięki temu warstwa zależności będzie cachowana
COPY package*.json ./

# Instalujemy zależności
RUN npm install

# Kopiujemy cały kod źródłowy do kontenera
COPY . .

# Ustawiamy zmienną środowiskową dla portu (opcjonalnie)
ENV PORT=5173

# Uruchamiamy serwer developerski Vite, który oferuje hot reload
CMD ["npm", "run", "dev"]
