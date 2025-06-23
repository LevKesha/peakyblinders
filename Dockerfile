# ci-toolchain.Dockerfile  (example)

# --------------------------------------------------
# 1. base OS image
# --------------------------------------------------
FROM ubuntu:22.04

# --------------------------------------------------
# 2. non-interactive apt install of build tools you already had
# --------------------------------------------------
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
        curl git nodejs npm python3 python3-pip maven postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# --------------------------------------------------
# 3. **ADD THE DOCKER CLI**  ⬇️⬇️
#    This installs the official docker-ce client & CLI only
# --------------------------------------------------
RUN curl -fsSL https://get.docker.com | sh
# Optional: keep image small
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# --------------------------------------------------
# 4. entry point (unchanged)
# --------------------------------------------------
CMD ["bash"]
