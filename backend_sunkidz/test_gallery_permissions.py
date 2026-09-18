"""Focused checks for the Gallery module's server-side authorization.

Run: python -m pytest test_gallery_permissions.py -q

These tests avoid a live database. The role gate (`_require_upload_role`)
and the authentication requirement (`get_current_user`) both fire before any
DB access, so they can be exercised with FastAPI dependency overrides only.
Branch-scoping helpers are tested directly against a tiny fake session.
"""
import io
import sys
import types
import uuid

import pytest
from fastapi.testclient import TestClient

sys.path.insert(0, ".")

from app.main import app  # noqa: E402
from app.core.auth import get_current_user  # noqa: E402
from app.core.database import get_db  # noqa: E402
from app.api import gallery as gallery_api  # noqa: E402
from app.services import class_access  # noqa: E402


def _fake_user(role: str):
    return types.SimpleNamespace(id=uuid.uuid4(), role=role, is_active="true", full_name=f"{role} user")


def _noop_db():
    yield types.SimpleNamespace()


def _db_override(session):
    """Return a generator-function dependency that yields ``session``."""
    def _gen():
        yield session
    return _gen


@pytest.fixture
def client():
    app.dependency_overrides[get_db] = _noop_db
    yield TestClient(app)
    app.dependency_overrides.clear()


def _as(role):
    app.dependency_overrides[get_current_user] = lambda: _fake_user(role)


def _tiny_png() -> bytes:
    # 1x1 transparent PNG
    return bytes.fromhex(
        "89504e470d0a1a0a0000000d494844520000000100000001080600000"
        "01f15c4890000000a49444154789c6360000002000100" "05" "0001" "0a2db4"
        "0000000049454e44ae426082"
    )


# ---- authentication is required -------------------------------------------------

def test_upload_requires_auth(client):
    r = client.post(
        "/api/v1/gallery/items",
        data={"branch_id": str(uuid.uuid4())},
        files={"file": ("x.png", io.BytesIO(_tiny_png()), "image/png")},
    )
    assert r.status_code == 401


def test_list_requires_auth(client):
    assert client.get("/api/v1/gallery/items").status_code == 401


# ---- only admin / coordinator / teacher may upload or manage --------------------

@pytest.mark.parametrize("role", ["parent", "toddlers", "daycare", "bus_staff"])
def test_upload_forbidden_for_non_staff(client, role):
    _as(role)
    r = client.post(
        "/api/v1/gallery/items",
        data={"branch_id": str(uuid.uuid4())},
        files={"file": ("x.png", io.BytesIO(_tiny_png()), "image/png")},
    )
    assert r.status_code == 403
    app.dependency_overrides.pop(get_current_user, None)


@pytest.mark.parametrize("role", ["parent", "toddlers", "daycare", "bus_staff"])
def test_delete_forbidden_for_non_staff(client, role):
    _as(role)
    r = client.delete(f"/api/v1/gallery/items/{uuid.uuid4()}")
    assert r.status_code == 403
    app.dependency_overrides.pop(get_current_user, None)


class _ListFakeQuery:
    def filter(self, *a, **k):
        return self

    def order_by(self, *a, **k):
        return self

    def all(self):
        return []


class _ListFakeSession:
    def query(self, model):
        return _ListFakeQuery()


def test_parent_can_view_gallery(client):
    """Parents get a read-only view: listing items and branch options is
    allowed even though every write path is not."""
    app.dependency_overrides[get_db] = _db_override(_ListFakeSession())
    _as("parent")
    try:
        items = client.get("/api/v1/gallery/items")
        assert items.status_code == 200, items.text
        assert items.json() == []
        opts = client.get("/api/v1/gallery/branch-options")
        assert opts.status_code == 200, opts.text
    finally:
        app.dependency_overrides.pop(get_current_user, None)
        app.dependency_overrides[get_db] = _noop_db


@pytest.mark.parametrize("role", ["toddlers", "daycare", "bus_staff"])
def test_other_non_staff_see_empty_gallery(client, role):
    """Roles with their own galleries can't see this one's contents."""
    app.dependency_overrides[get_db] = _db_override(_ListFakeSession())
    _as(role)
    try:
        r = client.get("/api/v1/gallery/items")
        assert r.status_code == 200
        assert r.json() == []
    finally:
        app.dependency_overrides.pop(get_current_user, None)
        app.dependency_overrides[get_db] = _noop_db


def test_require_upload_role_direct():
    for role in ("admin", "coordinator", "teacher"):
        gallery_api._require_upload_role(_fake_user(role))  # no raise
    for role in ("parent", "toddlers", "daycare", "bus_staff", "random"):
        with pytest.raises(Exception):
            gallery_api._require_upload_role(_fake_user(role))


# ---- branch-scoping helpers ----------------------------------------------------

class _FakeQuery:
    def __init__(self, rows):
        self._rows = rows

    def filter(self, *a, **k):
        return self

    def all(self):
        return self._rows


class _FakeSession:
    def __init__(self, by_model):
        self._by_model = by_model

    def query(self, model):
        return _FakeQuery(self._by_model.get(model, []))


def test_get_user_branch_ids_scopes_by_role():
    from app.models.branch import BranchAssignment
    from app.models.student import ParentStudentLink, Student

    b1, b2 = uuid.uuid4(), uuid.uuid4()

    # admin / toddlers / daycare -> None (all branches)
    for role in ("admin", "toddlers", "daycare"):
        assert class_access.get_user_branch_ids(_FakeSession({}), _fake_user(role)) is None

    # coordinator / teacher -> their assigned branches
    sess = _FakeSession({
        BranchAssignment: [types.SimpleNamespace(branch_id=b1), types.SimpleNamespace(branch_id=b2)],
    })
    for role in ("coordinator", "teacher"):
        got = set(class_access.get_user_branch_ids(sess, _fake_user(role)))
        assert got == {b1, b2}

    # parent -> children's branches
    sid = uuid.uuid4()
    sess = _FakeSession({
        ParentStudentLink: [types.SimpleNamespace(student_id=sid)],
        Student: [types.SimpleNamespace(branch_id=b1)],
    })
    assert class_access.get_user_branch_ids(sess, _fake_user("parent")) == [b1]

    # bus_staff -> nothing
    assert class_access.get_user_branch_ids(_FakeSession({}), _fake_user("bus_staff")) == []


def test_can_manage_branch_gallery(monkeypatch):
    b1, b2 = uuid.uuid4(), uuid.uuid4()

    assert class_access.can_manage_branch_gallery(None, _fake_user("admin"), b1) is True
    assert class_access.can_manage_branch_gallery(None, _fake_user("parent"), b1) is False

    monkeypatch.setattr(class_access, "get_user_branch_ids", lambda db, user: [b1])
    assert class_access.can_manage_branch_gallery(None, _fake_user("coordinator"), b1) is True
    assert class_access.can_manage_branch_gallery(None, _fake_user("teacher"), b2) is False


def test_media_kind_classification():
    from app.services.media_files import media_kind_for_filename

    assert media_kind_for_filename("photo.jpg") == "image"
    assert media_kind_for_filename("clip.mp4") == "video"
    assert media_kind_for_filename("clip.MOV") == "video"
    assert media_kind_for_filename("doc.pdf") not in ("image", "video")


# ---- happy path: admin / coordinator / teacher upload image AND video ----------

class _UploadFakeSession:
    """Minimal session supporting exactly what upload_item + _serialize do."""

    def __init__(self, branch, user):
        self._branch = branch
        self._user = user
        self.added = []

    def query(self, model):
        from app.models.branch import Branch
        from app.models.user import User

        rows = []
        if model is Branch:
            rows = [self._branch]
        elif model is User:
            rows = [self._user]
        return _UploadFakeQuery(rows)

    def add(self, obj):
        self.added.append(obj)

    def commit(self):
        pass

    def refresh(self, obj):
        import datetime as _dt
        if getattr(obj, "id", None) is None:
            obj.id = uuid.uuid4()
        if getattr(obj, "created_at", None) is None:
            obj.created_at = _dt.datetime.now(_dt.timezone.utc)


class _UploadFakeQuery:
    def __init__(self, rows):
        self._rows = rows

    def filter(self, *a, **k):
        return self

    def first(self):
        return self._rows[0] if self._rows else None


def _fake_mp4() -> bytes:
    return b"\x00\x00\x00\x20ftypisom" + b"\x00" * 70000


@pytest.mark.parametrize("role", ["admin", "coordinator", "teacher"])
@pytest.mark.parametrize(
    "fname,content,ctype,expected_kind",
    [
        ("pic.png", None, "image/png", "image"),
        ("clip.mp4", "mp4", "video/mp4", "video"),
    ],
)
def test_staff_can_upload_image_and_video(monkeypatch, role, fname, content, ctype, expected_kind, tmp_path):
    branch = types.SimpleNamespace(id=uuid.uuid4(), name="Test Branch")
    user = _fake_user(role)

    monkeypatch.setattr(gallery_api, "GALLERY_ITEMS_DIR", str(tmp_path))
    monkeypatch.setattr(gallery_api, "can_manage_branch_gallery", lambda db, u, bid: True)

    fake_session = _UploadFakeSession(branch, user)
    app.dependency_overrides[get_current_user] = lambda: user
    app.dependency_overrides[get_db] = _db_override(fake_session)
    try:
        payload = _fake_mp4() if content == "mp4" else _tiny_png()
        r = TestClient(app).post(
            "/api/v1/gallery/items",
            data={"branch_id": str(branch.id), "title": "Sports day"},
            files={"file": (fname, io.BytesIO(payload), ctype)},
        )
        assert r.status_code == 200, r.text
        body = r.json()
        assert body["media_type"] == expected_kind
        assert body["branch_id"] == str(branch.id)
        assert body["title"] == "Sports day"
        assert body["can_manage"] is True
    finally:
        app.dependency_overrides.pop(get_current_user, None)
        app.dependency_overrides.pop(get_db, None)


def test_staff_without_branch_access_cannot_upload(monkeypatch, tmp_path):
    branch = types.SimpleNamespace(id=uuid.uuid4(), name="Other Branch")
    user = _fake_user("teacher")
    monkeypatch.setattr(gallery_api, "GALLERY_ITEMS_DIR", str(tmp_path))
    monkeypatch.setattr(gallery_api, "can_manage_branch_gallery", lambda db, u, bid: False)

    fake_session = _UploadFakeSession(branch, user)
    app.dependency_overrides[get_current_user] = lambda: user
    app.dependency_overrides[get_db] = _db_override(fake_session)
    try:
        r = TestClient(app).post(
            "/api/v1/gallery/items",
            data={"branch_id": str(branch.id)},
            files={"file": ("x.png", io.BytesIO(_tiny_png()), "image/png")},
        )
        assert r.status_code == 403
    finally:
        app.dependency_overrides.pop(get_current_user, None)
        app.dependency_overrides.pop(get_db, None)


def test_routes_registered():
    paths = {r.path for r in app.routes}
    assert "/api/v1/gallery/items" in paths
    assert "/api/v1/gallery/branch-options" in paths
    assert "/api/v1/gallery/items/{item_id}" in paths
    assert "/api/v1/gallery/items/{item_id}/file" in paths
    # existing class gallery still mounted, untouched
    assert "/api/v1/gallery/upload" in paths
