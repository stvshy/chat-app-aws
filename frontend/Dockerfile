FROM node:20-alpine

WORKDIR /app

# kopiujemy TYLKO package.json, BEZ package-lock.json
COPY package.json ./

# instalujemy zależności
RUN npm install

# kopiujemy resztę plików (kod i ewentualny package-lock, jeśli jednak chcesz)
COPY . .

ENV PORT=5173
EXPOSE 5173

CMD ["npm", "run", "dev", "--", "--host", "0.0.0.0", "--port", "5173"]
