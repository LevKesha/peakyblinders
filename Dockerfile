# frontend/Dockerfile
FROM node:20-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci --legacy-peer-deps         # same cmd Jenkins runs
COPY . .
RUN npm run build                     # e.g. generates /dist

# --- runtime image ---
FROM nginx:1.27-alpine
COPY --from=build /app/dist /usr/share/nginx/html   # or /app/build for CRA
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
