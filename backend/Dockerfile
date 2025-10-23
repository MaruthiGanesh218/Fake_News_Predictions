# NEWS CHUNK 10 — Deployment & Verification Automation
# Author: GPT-5 Codecs (acting as a 30-40 year experienced software engineer)
# Behavior: Full write access. Create files, run checks, save results.

# syntax=docker/dockerfile:1.6

##############################
# Build stage: install dependencies into a dedicated virtualenv
FROM python:3.11-slim AS build

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /backend

RUN apt-get update \
    && apt-get install --no-install-recommends -y build-essential curl \
    && rm -rf /var/lib/apt/lists/*

RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:${PATH}"

RUN pip install --upgrade pip setuptools wheel

# Copy dependency metadata first for better layer caching
COPY pyproject.toml /backend/
COPY app /backend/app

RUN pip install --no-cache-dir .

##############################
# Runtime stage: minimal image with non-root user
FROM python:3.11-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:${PATH}"

WORKDIR /backend

RUN groupadd --system appuser \
    && useradd --system --gid appuser --create-home --home /home/appuser appuser

COPY --from=build /opt/venv /opt/venv
COPY app /backend/app
COPY pyproject.toml /backend/

EXPOSE 8000

USER appuser

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--proxy-headers"]
