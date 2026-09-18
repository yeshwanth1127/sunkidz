# Admission-Document Digitization — n8n Setup

Backend code, DB schema and Flutter UI for this feature are implemented (see
"What's implemented" below). **n8n itself does not exist yet in this
deployment** — this document is the manual setup required on the n8n side
before uploaded admission forms will actually get OCR'd. Nothing here has
been deployed or run against a live server.

## How the pieces fit together

```
Flutter (admin/teacher/coordinator)
   │ POST /api/v1/documents  (multipart: branch_id, file)
   ▼
Backend                                            n8n (you configure this)
   │ saves file, creates ingestion_documents row
   │ status="pending"
   │──── background POST to N8N_WEBHOOK_URL ───────▶ [1] Webhook node
   │      {document_id, file_url, doc_type,             receives the job
   │       branch_id}                                │
   │                                                  ▼
   │ ◀──── GET /documents/{id}/file ────────────── [2] HTTP Request node
   │       header: X-Service-Token: <secret>            fetches the file
   │                                                  │
   │                                                  ▼
   │                                              [3] OCR/AI node
   │                                                  extracts fields
   │                                                  │
   │                                                  ▼
   │ ◀──── PATCH /documents/{id}/ocr-result ──────[4] HTTP Request node
   │       header: X-Service-Token: <secret>            posts structured
   │       body: {extracted_data, confidence_scores,    JSON back
   │              raw_ocr_data, status}
   │
   │ status="needs_review"
   ▼
Flutter review screen → admin/teacher/coordinator confirms → POST /apply
   → writes to students / users / parent_student_links
```

n8n **never** writes to the SunKidz database directly. It only ever reads the
file and posts JSON back to `/documents/{id}/ocr-result`. A human always
reviews and explicitly applies the result — see "Risks" in the earlier design
map for why.

## 1. Stand up n8n

Not present in this repo/infra today. Options, pick one:

- **n8n Cloud** (fastest to start, hosted by n8n) — https://n8n.io
- **Self-hosted** — Docker: `docker run -it --rm -p 5678:5678 n8nio/n8n`, or
  add it as another PM2/Docker service alongside the backend on the same VPS
  referenced in `deploy/`. A production instance needs its own persistent
  volume for workflow data and its own HTTPS endpoint (nginx site, same
  pattern as `deploy/nginx/`).

Whoever provisions it needs to decide hosting, backups, and who has admin
access to the n8n UI — none of that is a code change, it's ops decision-making
outside this repo.

## 2. Generate the shared secret

This is the `X-Service-Token` n8n and the backend will trust each other with.
Generate one securely, e.g.:

```bash
openssl rand -hex 32
```

Put the **same value** in two places:

- Backend `backend_sunkidz/.env` → `N8N_SERVICE_TOKEN=<value>`
- Every n8n HTTP Request node that calls the backend (see below) → header
  `X-Service-Token: <value>`

Treat it like a password — it is the entire authentication for the
GET-file and PATCH-ocr-result endpoints (there is no JWT/login involved on
that side, by design, since n8n is not a human user).

## 3. Backend `.env` values to set

Already added as settings (`app/core/config.py`) and documented in
`backend_sunkidz/.env.example`; nothing else in the backend needs editing —
just fill these in on the server that runs the backend:

```
BACKEND_PUBLIC_BASE_URL=https://<your-backend-domain>     # no trailing slash
N8N_WEBHOOK_URL=https://<your-n8n-domain>/webhook/admission-document
N8N_SERVICE_TOKEN=<the value generated in step 2>
```

If `N8N_WEBHOOK_URL` is left blank, uploads still work end-to-end except the
automatic notification step — a document just sits in `status="pending"`
until someone presses "Retry OCR" in the app (`POST /documents/{id}/retry-ocr`),
which is useful for testing the upload/review flow before n8n is wired up.

## 4. Build the n8n workflow

Four nodes, in order:

### Node 1 — Webhook (trigger)
- HTTP Method: `POST`
- Path: `admission-document` (or whatever you put after `/webhook/` in
  `N8N_WEBHOOK_URL` above)
- Response mode: "Immediately" (respond 200 right away; do the real work
  after — OCR can take a while and the backend's webhook call only waits 10s)
- Incoming body: `{ "document_id": "...", "file_url": "https://.../api/v1/documents/{id}/file", "doc_type": "admission_form", "branch_id": "..." }`

### Node 2 — HTTP Request (fetch the file)
- Method: `GET`
- URL: `{{ $json.file_url }}`
- Header: `X-Service-Token: <the shared secret>`
- Response format: **File** (binary), so the next node gets image/PDF bytes

### Node 3 — OCR / AI extraction
No specific OCR provider is wired up yet — pick one and configure its n8n
credential (n8n's credential store, not this repo):
- **Claude** (Anthropic) — n8n has a built-in Anthropic node; use a vision-
  capable model, prompt it to return the admission-form fields as JSON.
- **Google Cloud Vision / Document AI**
- **AWS Textract**
- **Azure Form Recognizer**

Whichever you pick, the node's output must end up as JSON matching this
shape (this is the contract `/documents/{id}/ocr-result` expects) — do the
mapping in an n8n "Set"/"Code" node after the raw OCR call if the provider's
native output doesn't already look like this:

```json
{
  "extracted_data": {
    "name": "string",
    "date_of_birth": "YYYY-MM-DD",
    "gender": "string",
    "place_of_birth": "string",
    "nationality": "string",
    "mother_tongue": "string",
    "religion": "string",
    "blood_group": "string",
    "medical_allergies": "string",
    "medical_surgeries": "string",
    "medical_chronic_illness": "string",
    "residential_address": "string",
    "residential_contact_no": "string",
    "attended_previously": true,
    "school_daycare_name": "string",
    "prev_school_duration": "string",
    "prev_school_class": "string",
    "birth_certificate": true,
    "immunization_record": false,
    "transfer_certificate": false,
    "passport_photos": true,
    "progress_report": false,
    "passport": false,
    "other_medical_report": false,
    "parent_name": "string",
    "parent_contact": "string",
    "father_name": "string",
    "father_occupation": "string",
    "father_contact_no": "string",
    "father_email": "string",
    "mother_name": "string",
    "mother_occupation": "string",
    "mother_contact_no": "string",
    "mother_email": "string",
    "guardian_name": "string",
    "guardian_relation": "string",
    "guardian_contact_no": "string",
    "emergency_contact_name": "string",
    "emergency_contact_phone": "string",
    "transport_required": false
  },
  "confidence_scores": {
    "name": 0.95,
    "date_of_birth": 0.6
  },
  "raw_ocr_data": { "...": "whatever the OCR provider returned, unmodified, for audit" },
  "status": "needs_review"
}
```

Every field in `extracted_data` is optional — the reviewer's form in the app
pre-fills whatever is present and leaves the rest blank for manual entry.
`confidence_scores` is optional too; any field under 0.6 gets a "verify this"
warning in the review screen. If OCR fails outright (unreadable scan, API
error), send `{"status": "failed", "error_message": "..."}` instead.

### Node 4 — HTTP Request (post the result back)
- Method: `PATCH`
- URL: `{{ $('Webhook').item.json.file_url.split('/file')[0] }}/ocr-result`
  (i.e. `{BACKEND_PUBLIC_BASE_URL}/api/v1/documents/{document_id}/ocr-result`
  — simplest is to keep `document_id` from the Webhook node and build the URL
  from it directly rather than string-splitting the file URL)
- Header: `X-Service-Token: <the shared secret>`
- Body: the JSON shape from Node 3

Add n8n's built-in error-workflow / retry-on-fail settings on nodes 2–4 so a
transient network blip doesn't silently strand a document in "pending"
forever (the app's manual "Retry OCR" button is the human-triggered fallback
either way).

## 5. Test the loop end-to-end

1. Set the three env vars (step 3), restart the backend.
2. In the app, log in as admin/teacher/coordinator → drawer → "Admission
   Documents" → Upload → pick a branch and a sample admission form image/PDF.
3. Confirm the webhook fires (n8n execution log shows a new run).
4. Confirm the workflow completes and `PATCH .../ocr-result` succeeds (check
   the document's status flips to `needs_review` in the app).
5. Open the document in the review screen, confirm the fields pre-filled
   look right, adjust anything wrong, press "Apply to Student Record".
6. Verify the new/updated student shows up in Students / Admissions in the
   app as normal.

## What's implemented (code side, already in this repo)

- **DB**: `ingestion_documents` table (migration
  `035_ingestion_documents.py`, model `app/models/document.py`) — staging/
  audit row per uploaded document; never writes to `students`/`users` itself.
- **Backend API** (`app/api/documents.py`, mounted at `/api/v1/documents`):
  upload, list/queue, get, get file, retry-ocr — human JWT, staff roles only;
  `PATCH .../ocr-result` — service-token only (n8n); `apply` / `reject` —
  human JWT, staff roles only, branch-scoped, duplicate-student/duplicate-
  parent detection with an explicit override, single-transaction write.
- **Auth**: `require_service_token` dependency (`app/core/auth.py`) — static
  shared secret via `X-Service-Token`, fails closed if unset.
- **Flutter**: `core/api/documents_api.dart`, `features/documents/` (upload
  screen, review/apply screen with duplicate-conflict dialog, status queue),
  wired into the router and drawer for admin/teacher/coordinator only —
  parents have no route, no API access, no UI entry point for this feature.

## Not done here (needs your decision / a live server)

- Actually running `alembic upgrade head` against the production database —
  not run in this session since the configured `DATABASE_URL` points at a
  live server, not localhost; run it yourself when ready:
  ```bash
  cd backend_sunkidz && python -m alembic upgrade head
  ```
- Provisioning n8n itself (steps 1–4 above).
- Choosing/paying for an OCR/AI provider and its credential in n8n.
- Restarting the backend process with the new `.env` values.
- Any Flutter build/release (`flutter build apk` etc.) — this was
  implemented and analyzed (`flutter analyze`) but not built or run on a
  device this session.
