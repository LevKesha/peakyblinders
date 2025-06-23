# api-gateway/Dockerfile
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev
COPY . .
EXPOSE 3000              # match your server’s port
CMD ["node", "src/index.js"]
