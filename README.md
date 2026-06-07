# GitHub Runners in Docker

Run multiple self-hosted GitHub Actions runners for a single repo on one host using Docker.

You can scale to as many runners as you want via `--scale`. Each runner is allotted 2 CPU cores and 256 MB of RAM by default (see `compose.yml`).

# Setup

1. Generate a GitHub PAT (classic) with the `repo` and `workflow` scopes.
2. Run `./setup.sh` and provide the target repo (as `owner/repo`) and your PAT. This writes a local `.env` file (gitignored).

# How to Use

[Make sure Docker is installed.](https://docs.docker.com/engine/install/)

Run `docker compose up --build --scale runner=4`.

To force a fresh build run `docker compose build --no-cache`.

# Setting up as a Service

See `platform-runner.service` for an example systemd unit. Replace `<USER>` and `<PATH>` before installing.
