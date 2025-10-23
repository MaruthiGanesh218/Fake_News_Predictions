# NEWS CHUNK 1 — Project Bootstrap
# Author: GPT-5 Codecs (acting as a 30–40 year experienced software engineer)
# Behavior: You have full write access. Create files, run checks, save results. Prefer correctness, clarity and reproducibility.

# Fake News Prediction (Online Phase)

This repository hosts a staged build-out for a fake news prediction platform. NEWS CHUNK 1 establishes the baseline structure with separate frontend and backend services plus repeatable verification tooling.

## Getting Started

- Clone the repository and install prerequisites (`node`, `npm`, `python`, `pip`).
- Use `.env.example` files in `frontend/` and `backend/` as templates for local configuration.

## Running the Frontend

```bash
cd frontend
npm install
npm run dev
```

## Running the Backend

```bash
cd backend
python -m venv .venv
source .venv/bin/activate  # On Windows use .venv\Scripts\activate
pip install fastapi uvicorn[standard] python-dotenv httpx
uvicorn app.main:app --reload --port 8000
```

## Verification

Each chunk provides verification scripts under `scripts/`. For this chunk run:

```bash
bash scripts/verify-chunk-01.sh
```

Chunk-specific documentation and results are tracked in `CHUNK-01/`.


