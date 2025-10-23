# FAKE NEWS PREDICTION 
# Author: tejash


# Fake News Prediction (Online Phase)

This repository hosts a staged build-out for a fake news prediction platform. 

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


