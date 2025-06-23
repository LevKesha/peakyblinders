# database/Dockerfile
FROM postgres:16-alpine
# Optionally copy init SQL files
COPY sql/ /docker-entrypoint-initdb.d/
# Environment (user/db/pass) is set via docker-compose or helm
EXPOSE 5432
