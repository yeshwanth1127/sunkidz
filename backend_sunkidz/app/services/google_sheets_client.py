"""Read-only access to the school's Google Sheet.

Auth strategy, in order of preference:

1. Service account  – ``GOOGLE_SERVICE_ACCOUNT_JSON`` (raw JSON) or
   ``GOOGLE_SERVICE_ACCOUNT_FILE`` (path). The sheet stays fully private;
   share it with the service-account email as Viewer. Requires
   ``google-api-python-client`` + ``google-auth``.
2. Public CSV endpoint – used only when no service account is configured and
   the sheet is link-shared ("Anyone with the link can view"). No credentials.

Nothing here is ever exposed to the mobile app.
"""
from __future__ import annotations

import csv
import io
import json
import logging
from typing import List

import requests

from app.core.config import settings

logger = logging.getLogger(__name__)

_SCOPES = ["https://www.googleapis.com/auth/spreadsheets.readonly"]
_GVIZ_URL = (
    "https://docs.google.com/spreadsheets/d/{sid}/gviz/tq"
    "?tqx=out:csv&sheet={tab}"
)


class SheetConfigError(RuntimeError):
    """Raised when the spreadsheet id / credentials are not usable."""


def _service_account_info() -> dict | None:
    raw = (settings.google_service_account_json or "").strip()
    if raw:
        try:
            return json.loads(raw)
        except json.JSONDecodeError as e:  # pragma: no cover - config error path
            raise SheetConfigError(f"GOOGLE_SERVICE_ACCOUNT_JSON is not valid JSON: {e}")
    path = (settings.google_service_account_file or "").strip()
    if path:
        try:
            with open(path, "r", encoding="utf-8") as f:
                return json.load(f)
        except (OSError, json.JSONDecodeError) as e:  # pragma: no cover
            raise SheetConfigError(f"Cannot read GOOGLE_SERVICE_ACCOUNT_FILE ({path}): {e}")
    return None


def _fetch_via_service_account(spreadsheet_id: str, tab_name: str) -> List[List[str]]:
    info = _service_account_info()
    if info is None:
        raise SheetConfigError("no service account configured")

    # Imported lazily so the dependency is only needed when actually used.
    from google.oauth2.service_account import Credentials  # type: ignore
    from googleapiclient.discovery import build  # type: ignore

    creds = Credentials.from_service_account_info(info, scopes=_SCOPES)
    service = build("sheets", "v4", credentials=creds, cache_discovery=False)
    resp = (
        service.spreadsheets()
        .values()
        .get(spreadsheetId=spreadsheet_id, range=f"'{tab_name}'", valueRenderOption="FORMATTED_VALUE")
        .execute()
    )
    return [[str(c) for c in row] for row in resp.get("values", [])]


def _fetch_via_public_csv(spreadsheet_id: str, tab_name: str) -> List[List[str]]:
    url = _GVIZ_URL.format(sid=spreadsheet_id, tab=requests.utils.quote(tab_name))
    r = requests.get(url, timeout=30, allow_redirects=True)
    if r.status_code != 200 or r.text.lstrip().startswith("<"):
        raise SheetConfigError(
            f"public CSV fetch for tab '{tab_name}' failed "
            f"(HTTP {r.status_code}); is the sheet link-shared?"
        )
    reader = csv.reader(io.StringIO(r.text))
    return [list(row) for row in reader]


def fetch_tab_rows(tab_name: str, spreadsheet_id: str | None = None) -> List[List[str]]:
    """Return every row of ``tab_name`` as a list of string cells.

    Ragged rows are returned as-is; the parser is responsible for column
    alignment (it keys off the header, not fixed positions).
    """
    sid = (spreadsheet_id or settings.google_sheets_spreadsheet_id or "").strip()
    if not sid:
        raise SheetConfigError("GOOGLE_SHEETS_SPREADSHEET_ID is not configured")

    if _service_account_info() is not None:
        return _fetch_via_service_account(sid, tab_name)

    logger.warning(
        "No Google service account configured; reading calendar tab '%s' via the "
        "public CSV endpoint. Configure GOOGLE_SERVICE_ACCOUNT_JSON to keep the "
        "sheet private.",
        tab_name,
    )
    return _fetch_via_public_csv(sid, tab_name)
