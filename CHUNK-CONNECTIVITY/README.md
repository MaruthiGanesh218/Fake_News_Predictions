# NEWS CHUNK Connectivity Suite

This chunk adds a repeatable workflow to verify the frontend↔backend bridge for the News Chunk project. The tooling probes the FastAPI backend, validates `/check-news`, inspects CORS configuration, and records actionable recommendations in `CONNECTIVITY-RESULT.json`.

## Files
- `CHUNK-CONNECTIVITY/verify-connection.sh` – wrapper that executes the root script for convenience.
- `scripts/verify-connection.sh` – Bash implementation that performs the checks and writes artifacts.
- `scripts/verify-connection.ps1` – PowerShell implementation tailored for Windows terminals without Bash.
- `frontend/src/services/verify_client.js` – optional helper to trigger the connectivity test from the browser console.
- `backend/logs/connectivity-debug.log` – verbose log captured by the script.
- `CONNECTIVITY-RESULT.json` – machine-readable result summary produced after each run.

## Prerequisites
- Running backend (`uvicorn`) instance reachable on the configured port (defaults to `8000`).
- Running Vite dev server on port `5173` if you want live e2e verification.
- CLI dependencies: `curl`, `python3` (3.10+), `node`, `npm`, and ideally `uvicorn` on PATH.
- Use Git Bash/WSL for the Bash script or Windows PowerShell 7+ for the PowerShell version.

## Usage
1. Start the backend in one terminal: `cd backend && uvicorn app.main:app --reload --port 8000`.
2. Start the frontend in another terminal: `cd frontend && npm run dev -- --port 5173`.
3. From a Bash or PowerShell environment, run:
   ```bash
   ./scripts/verify-connection.sh
   ```
   or use the wrapper:
   ```bash
   ./CHUNK-CONNECTIVITY/verify-connection.sh
   ```
   On Windows PowerShell, run:
   ```powershell
   pwsh ./scripts/verify-connection.ps1
   ```
4. Inspect `CONNECTIVITY-RESULT.json` for structured results and `backend/logs/connectivity-debug.log` for verbose traces.

When running on Windows, open Git Bash (bundled with Git for Windows) or any WSL distro and execute the script from there. The script exits with code `0` on success and `1` when issues are detected.
