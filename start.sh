#!/bin/bash
set -euo pipefail

: "${TOKEN:?TOKEN env var required}"
: "${REPO:?REPO env var required (owner/repo)}"

ACCESS_TOKEN=$TOKEN

fetch_runner_token() {
    local kind=$1  # registration-token or remove-token
    curl -fsSL -X POST \
        -H "Authorization: Bearer ${ACCESS_TOKEN}" \
        -H "Accept: application/vnd.github+json" \
        "https://api.github.com/repos/${REPO}/actions/runners/${kind}" \
        | jq -r .token
}

REG_TOKEN=$(fetch_runner_token registration-token)
if [ -z "$REG_TOKEN" ] || [ "$REG_TOKEN" = "null" ]; then
    echo "Failed to fetch registration token. Check TOKEN scopes and REPO." >&2
    exit 1
fi

cd /home/docker/actions-runner

./config.sh --url "https://github.com/${REPO}" --token "${REG_TOKEN}" --unattended --replace

cleanup() {
    echo "Removing runner..."
    REMOVE_TOKEN=$(fetch_runner_token remove-token || echo "")
    if [ -n "$REMOVE_TOKEN" ] && [ "$REMOVE_TOKEN" != "null" ]; then
        ./config.sh remove --unattended --token "${REMOVE_TOKEN}" || true
    else
        echo "Could not obtain remove token; runner may need manual cleanup." >&2
    fi
}

trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

./run.sh & wait $!
