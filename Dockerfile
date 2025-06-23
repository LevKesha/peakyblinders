# database/Dockerfile
FROM postgres:16-alpine
# Environment (user/db/pass) is set via docker-compose or helm
EXPOSE 5432
