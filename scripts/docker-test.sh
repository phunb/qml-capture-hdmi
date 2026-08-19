#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
docker compose build test
docker compose run --rm test
