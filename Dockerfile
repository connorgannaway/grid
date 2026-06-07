FROM alpine:3.20

ARG RUNNER_VERSION="2.323.0"

# Runtime + build deps. gcompat + libstdc++ are required because the official
# GitHub Actions runner ships glibc-linked dotnet binaries.
# docker-cli only (no daemon): compose.yml mounts /var/run/docker.sock from the host.
RUN apk add --no-cache \
        bash \
        ca-certificates \
        curl \
        wget \
        git \
        jq \
        unzip \
        sudo \
        shadow \
        icu-libs \
        libffi \
        openssl \
        krb5-libs \
        zlib \
        libstdc++ \
        gcompat \
        python3 \
        py3-pip \
        go \
        docker-cli \
        docker-cli-compose \
        docker-cli-buildx \
        github-cli \
        aws-cli

# Create the docker user. Note: the GID of the in-container `docker` group should
# match the host's docker group GID for /var/run/docker.sock access to work.
# Override at build time with --build-arg DOCKER_GID=$(getent group docker | cut -d: -f3).
ARG DOCKER_GID=999
RUN addgroup -g ${DOCKER_GID} docker \
    && adduser -D -h /home/docker -s /bin/bash -G docker docker

# Install the GitHub Actions runner
WORKDIR /home/docker/actions-runner
RUN curl -fsSL -o runner.tar.gz \
        https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz \
    && tar xzf runner.tar.gz \
    && rm runner.tar.gz \
    && chown -R docker:docker /home/docker

COPY --chown=docker:docker --chmod=755 start.sh /home/docker/start.sh

WORKDIR /home/docker
USER docker

ENTRYPOINT ["./start.sh"]
