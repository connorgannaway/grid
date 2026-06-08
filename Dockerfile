FROM ubuntu:24.04

ARG RUNNER_VERSION="2.334.0"
ARG RUNNER_SHA256="048024cd2c848eb6f14d5646d56c13a4def2ae7ee3ad12122bee960c56f3d271"

ARG DEBIAN_FRONTEND=noninteractive

# Runtime + build deps. The official GitHub Actions runner ships glibc-linked
# dotnet binaries, so Ubuntu (glibc) is the supported base.
# docker-cli only (no daemon): compose.yml mounts /var/run/docker.sock from the host.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        wget \
        git \
        jq \
        unzip \
        sudo \
        gnupg \
        libicu-dev \
        libssl-dev \
        libffi-dev \
        python3 \
        python3-venv \
        python3-pip \
        software-properties-common \
        build-essential \
        libvips-dev \
        pkg-config \
        protobuf-compiler \
    && rm -rf /var/lib/apt/lists/*

# Go (via official PPA for current versions)
RUN add-apt-repository ppa:longsleep/golang-backports -y \
    && apt-get update \
    && apt-get install -y --no-install-recommends golang-go \
    && rm -rf /var/lib/apt/lists/*

# Go-based codegen tools: protoc-gen-go, protoc-gen-go-grpc, sqlc.
# GOBIN=/usr/local/bin makes them globally available without PATH gymnastics.
ENV GOBIN=/usr/local/bin
RUN go install google.golang.org/protobuf/cmd/protoc-gen-go@latest \
    && go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest \
    && go install github.com/sqlc-dev/sqlc/cmd/sqlc@latest

# AWS CLI v2
RUN curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip -q awscliv2.zip \
    && ./aws/install \
    && rm -rf awscliv2.zip aws

# GitHub CLI
RUN mkdir -p -m 755 /etc/apt/keyrings \
    && wget -nv -O /etc/apt/keyrings/githubcli-archive-keyring.gpg https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

# Docker CLI + compose + buildx (no daemon — host socket is bind-mounted)
RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc \
    && chmod a+r /etc/apt/keyrings/docker.asc \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" \
        > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends docker-ce-cli docker-buildx-plugin docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/*

# Create the docker user. The in-container `docker` group GID should match the
# host's docker group GID for /var/run/docker.sock access to work.
# Override at build time with --build-arg DOCKER_GID=$(getent group docker | cut -d: -f3).
ARG DOCKER_GID=999
RUN set -eux; \
    if getent group "${DOCKER_GID}" >/dev/null; then \
        existing=$(getent group "${DOCKER_GID}" | cut -d: -f1); \
        if [ "$existing" != "docker" ]; then groupmod -n docker "$existing"; fi; \
    else \
        groupadd -g "${DOCKER_GID}" docker; \
    fi; \
    useradd -m -s /bin/bash -g docker docker

RUN mkdir -p /var/cache/actions && chown docker:docker /var/cache/actions

# Install the GitHub Actions runner
WORKDIR /home/docker/actions-runner
RUN curl -fsSL -o runner.tar.gz \
        https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz \
    && echo "${RUNNER_SHA256}  runner.tar.gz" | sha256sum -c - \
    && tar xzf runner.tar.gz \
    && rm runner.tar.gz \
    && ./bin/installdependencies.sh \
    && chown -R docker:docker /home/docker

COPY --chown=docker:docker --chmod=755 start.sh /home/docker/start.sh

WORKDIR /home/docker
USER docker

ENTRYPOINT ["./start.sh"]
