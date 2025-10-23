# NEWS CHUNK 10 — Deployment & Verification Automation
# Author: GPT-5 Codecs (acting as a 30-40 year experienced software engineer)
# Behavior: Full write access. Create files, run checks, save results.

## Overview
NEWS CHUNK 10 delivers production deployment tooling for the Fake News Prediction stack. The backend and frontend now ship Dockerfiles, a Cloud Run deployment script, smoke-test tooling, a CI/CD pipeline, and runbook documentation. Follow the instructions below to deploy using your Google Cloud credits and verify the system end-to-end.

## Completed checklist
- [x] Add Dockerfiles for frontend & backend (multi-stage, secure).
- [x] Add `deploy/gcloud_deploy.sh` with clear commands and environment variable usage.
- [x] Add `.github/workflows/ci-cd.yml` for CI/CD with manual deploy approval.
- [x] Add smoke tests and final-report generation.
- [x] Create `CHUNK-10/README.md`, `CHUNK-10/RESULT.json`, and `CHUNK-10/verify-chunk-10.sh`.
- [x] Run verification script and write `CHUNK-10/RESULT.json` (deployment steps marked as skipped where required).
- [x] Generate `FINAL-REPORT.json` summarizing all chunk results.

## Prerequisites
1. **Google Cloud account with billing credits** (the free tier or promotional credits are sufficient).
2. **Google Cloud SDK (`gcloud`)** installed locally and authenticated: `gcloud auth login`.
3. **Docker** installed locally for building/testing images.
4. Optional: **Terraform** if you prefer infrastructure-as-code (stub provided in `deploy/terraform`).

## Service account & IAM setup
1. Select (or create) a Cloud project and set it as default:
   ```bash
   gcloud config set project <PROJECT_ID>
   ```
2. Enable required services:
   ```bash
   gcloud services enable run.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com
   ```
3. Create a dedicated service account for CI/CD:
   ```bash
   gcloud iam service-accounts create fake-news-deployer \
     --display-name "Fake News CI/CD Deployer"
   ```
4. Grant least-privilege roles:
   ```bash
   gcloud projects add-iam-policy-binding <PROJECT_ID> \
     --member="serviceAccount:fake-news-deployer@<PROJECT_ID>.iam.gserviceaccount.com" \
     --role="roles/run.admin"

   gcloud projects add-iam-policy-binding <PROJECT_ID> \
     --member="serviceAccount:fake-news-deployer@<PROJECT_ID>.iam.gserviceaccount.com" \
     --role="roles/iam.serviceAccountUser"

   gcloud projects add-iam-policy-binding <PROJECT_ID> \
     --member="serviceAccount:fake-news-deployer@<PROJECT_ID>.iam.gserviceaccount.com" \
     --role="roles/cloudbuild.builds.editor"
   ```
5. Generate a JSON key (store securely, **never commit it**):
   ```bash
   gcloud iam service-accounts keys create sa-key.json \
     --iam-account fake-news-deployer@<PROJECT_ID>.iam.gserviceaccount.com
   ```
6. Configure GitHub secrets for CI/CD:
   - `GCP_SA_KEY`: contents of `sa-key.json`.
   - `GCP_PROJECT`: your project ID.
   Optionally define an Actions environment secret/variable `GCP_REGION` (defaults to `us-central1`).
   Remove the downloaded `sa-key.json` after uploading to GitHub.

## Local deployment with `deploy/gcloud_deploy.sh`
1. Ensure your `.env` files contain production settings:
   - Backend: `backend/.env.production`
   - Frontend: `frontend/.env.production`
   (The script converts these into `--set-env-vars` when present.)
2. Make scripts executable once (`chmod +x deploy/gcloud_deploy.sh deploy/smoke_tests/smoke_test.sh`).
3. Execute deployment:
   ```bash
   GCP_PROJECT=<PROJECT_ID> GCP_REGION=us-central1 ./deploy/gcloud_deploy.sh
   ```
   The script:
   - Builds backend and frontend images via Cloud Build.
   - Deploys to Cloud Run (`fake-news-backend` and `fake-news-frontend`).
   - Prints the service URLs.
   - Runs smoke tests hitting `/health`, `/ready`, `/check-news`, and the frontend root HTML.
4. Monitor Cloud Run usage in the Google Cloud Console to stay within credit limits. Delete services when finished:
   ```bash
   gcloud run services delete fake-news-backend --region us-central1
   gcloud run services delete fake-news-frontend --region us-central1
   ```

## GitHub Actions CI/CD (`.github/workflows/ci-cd.yml`)
- **Triggers:** push to `main`, pull requests, and manual `workflow_dispatch` runs.
- **build-and-test job:**
  - Installs backend deps & runs `pytest`.
  - Installs frontend deps & runs `vitest` suite.
  - Builds Docker images to ensure Dockerfiles stay valid.
  - Publishes Docker metadata as an artifact.
- **deploy job:**
  - Requires branch `main`, depends on `build-and-test` success.
  - Uses environment `production` (add manual approval in GitHub settings).
  - Authenticates with `GCP_SA_KEY` and runs `deploy/gcloud_deploy.sh` using GitHub-hosted runners.
  - Skips automatically when secrets are absent (safe for forks/PRs).

To trigger deployment from GitHub once secrets are configured, run the workflow manually from the Actions tab or push to `main` and approve the `production` environment.

## Smoke tests
`deploy/smoke_tests/smoke_test.sh` accepts the deployed URLs and verifies:
- Frontend root responds with expected branding (`Fake News` in the HTML).
- Backend `/health` and `/ready` return success (200).
- Backend `/check-news` accepts POST JSON and returns a payload containing `verdict`.

Run manually:
```bash
./deploy/smoke_tests/smoke_test.sh --frontend https://<frontend-url> --backend https://<backend-url>
```

## Security and operations notes
- Never commit service account keys; use GitHub secrets and local `.env` files kept out of version control.
- Rotate service account keys regularly and delete stale deployments to control spend.
- Consider adding Cloud Logging alerts and Cloud Monitoring uptime checks targeting `/ready` for production hardening.
- Review the generated Docker images periodically with `gcloud artifacts docker images list` or vulnerability scanners (`gcloud artifacts docker images describe --show-package-vulnerability`).

## Verification summary
- `CHUNK-10/verify-chunk-10.sh` performs local static validation (Dockerfile presence, workflow syntax, optional Docker build, final report aggregation).
- `CHUNK-10/RESULT.json` captures outcomes; deployment is marked as `skip` pending live credentials.
- `FINAL-REPORT.json` aggregates all chunk statuses and highlights remaining manual deployment steps.
