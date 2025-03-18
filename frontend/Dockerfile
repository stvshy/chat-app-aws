FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build
RUN npm install -g serve
EXPOSE 5173
CMD ["npm", "run", "preview", "--", "--host", "0.0.0.0"]
ENV PORT=5173
