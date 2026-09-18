from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    # Database
    database_url: str = "postgresql://postgres:postgres@localhost:5432/sunkidz_lms"

    # JWT
    jwt_secret_key: str = "your-super-secret-key-change-in-production"
    jwt_algorithm: str = "HS256"
    jwt_access_token_expire_minutes: int = 60 * 24 * 30  # 30 days

    # Default classes created for each branch, in fixed canonical order.
    # Nursery/LKG/UKG/Playschool are retired legacy names and are
    # intentionally not used here.
    default_branch_classes: tuple[str, ...] = ("Playgroup", "IG1", "IG2", "IG3")
    normal_branch_classes: tuple[str, ...] = ("Playgroup", "IG1", "IG2", "IG3")

    # UltraMsg WhatsApp API
    ultramsg_api_url: str = "https://api.ultramsg.com"
    ultramsg_instance_id: str = ""
    ultramsg_auth_token: str = ""

    # OneSignal
    onesignal_app_id: str = ""
    onesignal_api_key: str = ""

    # Google Sheets school calendar (source of truth for working days /
    # Learning Day numbers). Configured in the backend .env only — never
    # shipped to the mobile app, never committed.
    google_sheets_spreadsheet_id: str = ""
    # Preferred on production: raw service-account JSON (share the sheet with
    # the service-account email as Viewer). Falls back to a file path, then to
    # the sheet's public CSV endpoint if neither is set.
    google_service_account_json: str = ""
    google_service_account_file: str = ""
    school_calendar_base_tab: str = "Base Document"
    school_calendar_cache_ttl_seconds: int = 300
    # Optional JSON mapping of branch_id -> sheet tab name, for branch-specific
    # calendars. Empty = every branch uses the base tab.
    school_calendar_branch_tabs: str = ""

    # n8n admission-document ingestion. `n8n_service_token` is a static shared
    # secret n8n sends back as the `X-Service-Token` header when it calls the
    # backend (fetching the uploaded file, posting OCR results) — there is no
    # human login involved for that direction. `n8n_webhook_url` is the n8n
    # webhook the backend notifies when a new document is uploaded. Both are
    # blank by default; document upload still works with them unset, it just
    # won't be able to notify n8n (see IngestionDocument.status="pending"
    # staying pending until POST /documents/{id}/retry-ocr is called once the
    # workflow is configured).
    n8n_webhook_url: str = ""
    n8n_service_token: str = ""
    # Publicly reachable base URL of THIS backend (no trailing slash), used to
    # build the file-fetch URL sent to n8n in the webhook payload — n8n runs
    # outside this server so a relative path isn't enough. e.g.
    # https://api.sunkidz.example.com
    backend_public_base_url: str = ""


    class Config:
        env_file = ".env"
        extra = "ignore"


settings = Settings()
