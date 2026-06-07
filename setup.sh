#!/bin/bash
set -e

read -rp "GitHub repo (owner/repo): " repo
read -rsp "GitHub PAT (repo + workflow scopes): " token
echo

docker_gid=$(getent group docker 2>/dev/null | cut -d: -f3 || true)
if [ -z "$docker_gid" ]; then
    echo "Warning: no 'docker' group found on host; defaulting DOCKER_GID=999." >&2
    echo "         If docker.sock access fails inside the runner, rerun setup after installing docker." >&2
    docker_gid=999
fi

umask 077
cat > .env <<EOF
TOKEN=${token}
REPO=${repo}
DOCKER_GID=${docker_gid}
EOF

echo "Wrote .env (DOCKER_GID=${docker_gid}). Now run: docker compose up --build --scale runner=4"
