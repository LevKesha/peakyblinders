# ──────────────────────────────────────────────
# CI tool-chain image for every branch
# • Ubuntu 22.04 LTS
# • Node 18  + npm
# • Python 3.12 + pip
# • OpenJDK 21 + Maven 3.9.x
# • PostgreSQL client
# • Git, curl, jq (helpers)
# ──────────────────────────────────────────────
FROM ubuntu:22.04

# never ask interactive questions
ENV DEBIAN_FRONTEND=noninteractive
ARG NODE_MAJOR=18

# 1. Base OS tooling
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
        ca-certificates gnupg curl git jq \
        build-essential \
        python3 python3-pip python3-venv \
        openjdk-21-jdk-headless maven \
        postgresql-client && \
    rm -rf /var/lib/apt/lists/*

# 2. NodeSource repo → Node LTS
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash - && \
    apt-get update -qq && \
    apt-get install -y --no-install-recommends nodejs && \
    rm -rf /var/lib/apt/lists/*

# 3. Upgrade pip & install common Python helpers
RUN python3 -m pip install --no-cache-dir --upgrade pip setuptools wheel poetry

# 4. Java env vars
ENV JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
ENV MAVEN_OPTS="-Dmaven.repo.local=/tmp/.m2"

# 5. Slim down image a bit
RUN apt-get clean && \
    rm -rf /tmp/* /var/tmp/* && \
    useradd -m -u 1000 ci && \
    mkdir -p /workspace && chown ci:ci /workspace

USER ci
WORKDIR /workspace

# 6. Prove tool-chain
RUN node -v     && \
    npm -v      && \
    python3 --version && \
    pip --version     && \
    mvn -version      && \
    psql --version

CMD ["/bin/bash"]
