# syntax=docker/dockerfile:1.7

# --- build stage: install deps into a venv, no compiler in final image ---
FROM python:3.12-slim AS build

WORKDIR /build

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN python -m venv /venv \
    && /venv/bin/pip install --no-cache-dir --upgrade pip \
    && /venv/bin/pip install --no-cache-dir -r requirements.txt

# --- runtime stage: minimal, non-root, no build tools ---
FROM python:3.12-slim AS runtime

# Root cause note (see docs/CHANGES.md): original image ran as root and
# had no resource ceiling on the process, contributing to noisy-neighbour
# and privilege-escalation risk during the incident's restart storm.
RUN groupadd --gid 10001 settle \
    && useradd --uid 10001 --gid settle --no-create-home --shell /usr/sbin/nologin settle

WORKDIR /app

COPY --from=build /venv /venv
COPY --chown=settle:settle . .

ENV PATH="/venv/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    # Cap gunicorn workers here; the real ceiling used for DB-connection
    # math lives in deploy/k8s/deployment.yaml + hpa.yaml — see
    # docs/CHANGES.md "DB connection budget".
    GUNICORN_WORKERS=4

USER settle

EXPOSE 8000

# Liveness/readiness are defined at the k8s level (NOT here) so that a
# slow Postgres dependency cannot fail a container-level HEALTHCHECK and
# get the runtime restarted by the container engine outside of k8s'
# readiness/liveness separation. See deploy/k8s/deployment.yaml.

ENTRYPOINT ["gunicorn", "settle_api.main:app", \
    "--worker-class", "uvicorn.workers.UvicornWorker", \
    "--workers", "4", \
    "--bind", "0.0.0.0:8000", \
    "--timeout", "30", \
    "--graceful-timeout", "30", \
    "--access-logfile", "-", \
    "--error-logfile", "-", \
    "--log-level", "info"]
