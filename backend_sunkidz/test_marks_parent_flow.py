"""Server-side checks for the Admin -> Parent Marks Card flow.

Run: python -m pytest test_marks_parent_flow.py -q

No live database: the role gates fire before any DB access, and the read/query
logic is exercised against a tiny fake session. The point of these tests is the
authorization contract:

  * only a parent may call the parent marks endpoint;
  * a parent only ever receives cards for *their own linked* children that have
    actually been sent (``sent_to_parent_at`` set);
  * there is no parent route that takes a ``student_id`` -- a parent cannot ask
    for another child's card by changing an id;
  * "send to parent" is admin-only and 404s until the card has been saved;
  * the JSONB ``data`` blob is returned to the parent unchanged.
"""
import os
import sys
import types
import uuid
from datetime import datetime, date, timedelta, timezone

import pytest
from fastapi.testclient import TestClient

sys.path.insert(0, ".")

from app.main import app  # noqa: E402
from app.core.auth import get_current_user  # noqa: E402
from app.core.database import get_db  # noqa: E402
from app.models import (  # noqa: E402
    ParentStudentLink,
    MarksCard,
    Student,
    Branch,
    Class,
    BranchAssignment,
)
from app.api import marks as marks_api  # noqa: E402
from app.api import teacher as teacher_api  # noqa: E402
from app.services import marks_card as marks_card_service  # noqa: E402
from app.services.marks_card import card_recency_key  # noqa: E402

API = "/api/v1"

# 1x1 transparent PNG bytes — `save_marks_signature` only stores the file, so
# the exact contents don't matter beyond being non-empty.
_PNG_1PX = bytes.fromhex(
    "89504e470d0a1a0a0000000d494844520000000100000001080600000"
    "01f15c4890000000a49444154789c6360000002000100" "05" "0001" "0a2db4"
    "0000000049454e44ae426082"
)
_JPG_BYTES = b"\xff\xd8\xff\xe0\x00\x10JFIF" + b"\x00" * 64 + b"\xff\xd9"

# A representative saved card, matching the free-form JSONB the Admin form writes
# (attendance string, nested scholastic cells as strings, co-scholastic grades,
# remarks, passed_to). It must round-trip to the parent byte-for-byte.
SAMPLE_DATA = {
    "attendance": "182 / 210",
    "english": {"Writing": {"pt1": "18", "ca1": "A+", "hy": "17"}},
    "co_discipline_t1": "A+",
    "co_confidence_t2": "B-",
    "remarks": "Consistent effort throughout the year.",
    "passed_to": "IG3",
}


def _fake_user(role: str):
    return types.SimpleNamespace(
        id=uuid.uuid4(), role=role, is_active="true", full_name=f"{role} user"
    )


def _noop_db():
    yield types.SimpleNamespace()


class _FakeQuery:
    def __init__(self, rows):
        self._rows = list(rows)

    def filter(self, *a, **k):
        return self

    def order_by(self, *a, **k):
        return self

    def all(self):
        return list(self._rows)

    def first(self):
        return self._rows[0] if self._rows else None


class _FakeSession:
    """Dispatches ``query(Model)`` to a preset list of rows per model."""

    def __init__(self, mapping):
        self._mapping = mapping

    def query(self, model):
        return _FakeQuery(self._mapping.get(model, []))

    # send-to-parent mutates + commits the single row it found
    def commit(self):
        pass

    def refresh(self, _obj):
        pass

    def delete(self, _obj):
        pass

    def add(self, _obj):
        pass


def _db_override(session):
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


def _student(sid, *, father="Sample Father", mother="Sample Mother", linked_parent=None):
    links = []
    if linked_parent is not None:
        links = [
            types.SimpleNamespace(user=types.SimpleNamespace(full_name=linked_parent))
        ]
    return types.SimpleNamespace(
        id=sid,
        name="Sample Child",
        admission_number="SS-001",
        branch_id=uuid.uuid4(),
        class_id=uuid.uuid4(),
        father_name=father,
        mother_name=mother,
        date_of_birth=date(2021, 5, 4),
        parent_links=links,
    )


def _card(sid, *, sent):
    return types.SimpleNamespace(
        id=uuid.uuid4(),
        student_id=sid,
        academic_year="2026-27",
        data=dict(SAMPLE_DATA),
        sent_to_parent_at=datetime(2026, 6, 1, tzinfo=timezone.utc) if sent else None,
    )


# ---- parent endpoint: authentication + role -----------------------------------

def test_parent_marks_cards_requires_auth(client):
    assert client.get(f"{API}/parent/marks-cards").status_code == 401


@pytest.mark.parametrize("role", ["admin", "teacher", "coordinator", "bus_staff"])
def test_parent_marks_cards_forbidden_for_non_parent(client, role):
    _as(role)
    try:
        assert client.get(f"{API}/parent/marks-cards").status_code == 403
    finally:
        app.dependency_overrides.pop(get_current_user, None)


# ---- parent only sees their own linked + sent cards ---------------------------

def test_parent_sees_linked_sent_card_with_unchanged_jsonb(client):
    sid = uuid.uuid4()
    link = types.SimpleNamespace(user_id=uuid.uuid4(), student_id=sid)
    session = _FakeSession(
        {
            ParentStudentLink: [link],
            MarksCard: [_card(sid, sent=True)],
            Student: [_student(sid)],
            Branch: [types.SimpleNamespace(id=uuid.uuid4(), name="Marathahalli")],
            Class: [types.SimpleNamespace(id=uuid.uuid4(), name="IG2")],
        }
    )
    app.dependency_overrides[get_db] = _db_override(session)
    _as("parent")
    try:
        r = client.get(f"{API}/parent/marks-cards")
        assert r.status_code == 200, r.text
        body = r.json()["marks_cards"]
        assert len(body) == 1
        assert body[0]["student_id"] == str(sid)
        # JSONB structure preserved exactly, no coercion / transformation.
        assert body[0]["data"] == SAMPLE_DATA
        assert body[0]["sent_at"] is not None
        # Father / Mother names come straight from the student record.
        assert body[0]["father_name"] == "Sample Father"
        assert body[0]["mother_name"] == "Sample Mother"
    finally:
        app.dependency_overrides.pop(get_current_user, None)
        app.dependency_overrides[get_db] = _noop_db


def test_parent_name_falls_back_to_linked_account_when_student_has_no_names(client):
    sid = uuid.uuid4()
    link = types.SimpleNamespace(user_id=uuid.uuid4(), student_id=sid)
    session = _FakeSession(
        {
            ParentStudentLink: [link],
            MarksCard: [_card(sid, sent=True)],
            Student: [
                _student(sid, father=None, mother=None, linked_parent="Priya Sharma")
            ],
            Branch: [types.SimpleNamespace(id=uuid.uuid4(), name="Marathahalli")],
            Class: [types.SimpleNamespace(id=uuid.uuid4(), name="IG2")],
        }
    )
    app.dependency_overrides[get_db] = _db_override(session)
    _as("parent")
    try:
        r = client.get(f"{API}/parent/marks-cards")
        assert r.status_code == 200, r.text
        card = r.json()["marks_cards"][0]
        assert card["father_name"] is None
        assert card["mother_name"] is None
        # The card can still show a real name via the linked parent account.
        assert card["parent_name"] == "Priya Sharma"
    finally:
        app.dependency_overrides.pop(get_current_user, None)
        app.dependency_overrides[get_db] = _noop_db


def test_parent_with_no_linked_children_sees_nothing(client):
    session = _FakeSession({ParentStudentLink: []})
    app.dependency_overrides[get_db] = _db_override(session)
    _as("parent")
    try:
        r = client.get(f"{API}/parent/marks-cards")
        assert r.status_code == 200, r.text
        assert r.json() == {"marks_cards": []}
    finally:
        app.dependency_overrides.pop(get_current_user, None)
        app.dependency_overrides[get_db] = _noop_db


# ---- a parent cannot READ another student's card by id ----------------------

def _parent_marks_routes():
    out = []
    for r in app.routes:
        path = getattr(r, "path", "")
        if path.startswith(f"{API}/parent") and "marks" in path:
            out.append((path, set(getattr(r, "methods", []) or [])))
    return out


def test_no_parent_GET_route_accepts_a_student_id_for_marks(client):
    """Reading marks is only the id-less collection endpoint — nothing for a
    parent to tamper with by swapping a student id. The single id-taking route
    (signature upload) is a POST guarded by a ParentStudentLink check and never
    returns another child's card."""
    routes = _parent_marks_routes()
    getters = [p for p, methods in routes if "GET" in methods]
    assert getters == [f"{API}/parent/marks-cards"]
    id_taking = [(p, methods) for p, methods in routes if "{" in p]
    assert id_taking == [
        (f"{API}/parent/marks-cards/{{student_id}}/signature", {"POST"})
    ]


def test_parent_cannot_upload_signature_for_an_unlinked_student(client):
    session = _FakeSession({ParentStudentLink: []})  # no link
    app.dependency_overrides[get_db] = _db_override(session)
    _as("parent")
    try:
        r = client.post(
            f"{API}/parent/marks-cards/{uuid.uuid4()}/signature",
            data={"academic_year": "2026-27"},
            files={"file": ("sig.png", _PNG_1PX, "image/png")},
        )
        assert r.status_code == 403
    finally:
        app.dependency_overrides.pop(get_current_user, None)
        app.dependency_overrides[get_db] = _noop_db


# ---- send-to-parent: admin only, save required -------------------------------

def test_send_to_parent_requires_auth(client):
    assert (
        client.post(f"{API}/admin/marks/{uuid.uuid4()}/send-to-parent").status_code
        == 401
    )


@pytest.mark.parametrize("role", ["parent", "teacher", "coordinator"])
def test_send_to_parent_forbidden_for_non_admin(client, role):
    _as(role)
    try:
        r = client.post(f"{API}/admin/marks/{uuid.uuid4()}/send-to-parent")
        assert r.status_code == 403
    finally:
        app.dependency_overrides.pop(get_current_user, None)


def test_send_to_parent_404_until_card_is_saved(client):
    session = _FakeSession({MarksCard: []})
    app.dependency_overrides[get_db] = _db_override(session)
    _as("admin")
    try:
        r = client.post(f"{API}/admin/marks/{uuid.uuid4()}/send-to-parent")
        assert r.status_code == 404
    finally:
        app.dependency_overrides.pop(get_current_user, None)
        app.dependency_overrides[get_db] = _noop_db


def test_send_to_parent_marks_saved_card_sent_without_duplicating(client, monkeypatch):
    monkeypatch.setattr(marks_api, "post_event_message", lambda *a, **k: None)
    sid = uuid.uuid4()
    card = _card(sid, sent=False)
    session = _FakeSession(
        {
            MarksCard: [card],
            Student: [_student(sid)],
            ParentStudentLink: [],
        }
    )
    app.dependency_overrides[get_db] = _db_override(session)
    _as("admin")
    try:
        r = client.post(f"{API}/admin/marks/{sid}/send-to-parent")
        assert r.status_code == 200, r.text
        body = r.json()
        # Same row, now stamped — no second record was created.
        assert body["id"] == str(card.id)
        assert body["sent_to_parent_at"] is not None
        assert card.sent_to_parent_at is not None
    finally:
        app.dependency_overrides.pop(get_current_user, None)
        app.dependency_overrides[get_db] = _noop_db


# ---- one current version per student: repeated update -> save -> send --------

class _RowQ:
    """Ordered query over an in-memory row list. Understands only the one
    filter the Marks Card endpoints use: ``sent_to_parent_at IS NOT NULL``."""

    def __init__(self, rows, order_key=None):
        self._rows = list(rows)
        self._order_key = order_key

    def filter(self, *clauses):
        rows = self._rows
        for c in clauses:
            if "sent_to_parent_at IS NOT NULL" in str(c):
                rows = [r for r in rows if getattr(r, "sent_to_parent_at", None) is not None]
        return _RowQ(rows, self._order_key)

    def order_by(self, *a):
        return self

    def all(self):
        rows = list(self._rows)
        if self._order_key:
            rows.sort(key=self._order_key, reverse=True)
        return rows

    def first(self):
        rows = self.all()
        return rows[0] if rows else None


class _MarksDb:
    """Stateful fake DB that enforces nothing but *records* every marks row, so a
    test can assert how many exist after repeated writes."""

    def __init__(self, student, links, assignments=None):
        self.marks = []
        self._student = student
        self._links = links
        self._assignments = assignments or []
        self._t = 0

    def _now(self):
        self._t += 1
        return datetime(2026, 1, 1, tzinfo=timezone.utc) + timedelta(seconds=self._t)

    def query(self, model):
        name = getattr(model, "__name__", "")
        if name == "MarksCard":
            return _RowQ(self.marks, order_key=card_recency_key)
        if name == "Student":
            return _RowQ([self._student])
        if name == "ParentStudentLink":
            return _RowQ(self._links)
        if name == "BranchAssignment":
            return _RowQ(self._assignments)
        return _RowQ([])

    def add(self, obj):
        if getattr(obj, "id", None) is None:
            obj.id = uuid.uuid4()
        obj.created_at = self._now()
        obj.updated_at = obj.created_at
        self.marks.append(obj)

    def delete(self, obj):
        self.marks = [r for r in self.marks if r is not obj]

    def commit(self):
        for r in self.marks:  # emulate onupdate=func.now()
            r.updated_at = self._now()

    def refresh(self, _obj):
        pass


def _plain_student(sid, class_id):
    return types.SimpleNamespace(
        id=sid,
        name="Sample Child",
        admission_number="SS-001",
        branch_id=None,
        class_id=class_id,
        father_name="Sample Father",
        mother_name="Sample Mother",
        date_of_birth=date(2021, 5, 4),
        parent_links=[],
    )


def _marks_db_for(sid):
    """A fake DB wired for one student reachable by both an admin and a teacher
    (the teacher owns the student's class) and linked to one parent."""
    class_id = uuid.uuid4()
    return _MarksDb(
        _plain_student(sid, class_id),
        [types.SimpleNamespace(user_id=uuid.uuid4(), student_id=sid)],
        assignments=[types.SimpleNamespace(user_id=uuid.uuid4(), class_id=class_id)],
    )


def _edit_url(editor: str, sid) -> str:
    return f"{API}/{editor}/marks/{sid}"


@pytest.mark.parametrize("editor", ["admin", "teacher"])
def test_repeated_update_save_send_keeps_one_latest_version(client, monkeypatch, editor):
    """Regression: edit -> save -> send, over and over. There must always be
    exactly one row, and the editing staff role AND the parent must both load
    that newest version — never a stale sent copy."""
    monkeypatch.setattr(marks_api, "post_event_message", lambda *a, **k: None)
    monkeypatch.setattr(teacher_api, "post_event_message", lambda *a, **k: None)
    sid = uuid.uuid4()
    db = _marks_db_for(sid)
    app.dependency_overrides[get_db] = _db_override(db)

    def payload(rev):
        return {
            "academic_year": "2026-27",
            "data": {"english": {"Writing": {"pt1": str(rev)}}, "rev": rev},
        }

    try:
        for rev in range(1, 8):  # any number of update/send cycles
            _as(editor)
            assert (
                client.put(_edit_url(editor, sid), json=payload(rev)).status_code == 200
            )
            assert (
                client.post(f"{_edit_url(editor, sid)}/send-to-parent").status_code == 200
            )

            # never more than one stored version
            assert len(db.marks) == 1, f"rev {rev}: {len(db.marks)} rows"

            # The editing staff role loads the latest
            staff_card = client.get(_edit_url(editor, sid)).json()
            assert staff_card["data"]["rev"] == rev

            # Parent loads the same latest — exactly one card, no older copies
            _as("parent")
            body = client.get(f"{API}/parent/marks-cards").json()["marks_cards"]
            assert len(body) == 1
            assert body[0]["data"]["rev"] == rev
    finally:
        app.dependency_overrides.pop(get_current_user, None)
        app.dependency_overrides[get_db] = _noop_db


def test_admin_and_teacher_edits_share_one_current_version(client, monkeypatch):
    """Admin and Teacher edit the same student through their own endpoints;
    every save/send updates the one shared current card, and all three roles
    (admin, teacher, parent) always retrieve that newest revision."""
    monkeypatch.setattr(marks_api, "post_event_message", lambda *a, **k: None)
    monkeypatch.setattr(teacher_api, "post_event_message", lambda *a, **k: None)
    sid = uuid.uuid4()
    db = _marks_db_for(sid)
    app.dependency_overrides[get_db] = _db_override(db)

    def payload(rev):
        return {"academic_year": "2026-27", "data": {"rev": rev}}

    # who edits on each successive cycle
    editors = ["admin", "teacher", "teacher", "admin", "teacher", "admin"]
    try:
        for rev, editor in enumerate(editors, start=1):
            _as(editor)
            assert client.put(_edit_url(editor, sid), json=payload(rev)).status_code == 200
            assert client.post(f"{_edit_url(editor, sid)}/send-to-parent").status_code == 200
            assert len(db.marks) == 1

            for reader in ("admin", "teacher"):
                _as(reader)
                assert client.get(_edit_url(reader, sid)).json()["data"]["rev"] == rev

            _as("parent")
            body = client.get(f"{API}/parent/marks-cards").json()["marks_cards"]
            assert len(body) == 1
            assert body[0]["data"]["rev"] == rev
    finally:
        app.dependency_overrides.pop(get_current_user, None)
        app.dependency_overrides[get_db] = _noop_db


def test_pre_existing_duplicate_rows_are_healed_and_only_latest_is_served(
    client, monkeypatch
):
    """If stale duplicate rows already exist (e.g. table built without the
    unique index), the parent still only sees the newest, and the next admin
    save collapses them to one row."""
    monkeypatch.setattr(marks_api, "post_event_message", lambda *a, **k: None)
    sid = uuid.uuid4()
    db = _marks_db_for(sid)

    def _row(rev, when):
        ts = datetime(2026, when, 1, tzinfo=timezone.utc)
        return types.SimpleNamespace(
            id=uuid.uuid4(),
            student_id=sid,
            academic_year="2026-27",
            data={"rev": rev},
            sent_to_parent_at=ts,
            created_at=ts,
            updated_at=ts,
        )

    db.marks = [_row("old", 3), _row("new", 6)]  # both were sent
    app.dependency_overrides[get_db] = _db_override(db)

    try:
        _as("parent")
        body = client.get(f"{API}/parent/marks-cards").json()["marks_cards"]
        assert len(body) == 1
        assert body[0]["data"] == {"rev": "new"}  # not the stale "old" one

        _as("admin")
        r = client.put(
            f"{API}/admin/marks/{sid}",
            json={"academic_year": "2026-27", "data": {"rev": "newer"}},
        )
        assert r.status_code == 200
        assert len(db.marks) == 1
        assert db.marks[0].data == {"rev": "newer"}

        _as("parent")
        body = client.get(f"{API}/parent/marks-cards").json()["marks_cards"]
        assert len(body) == 1
        assert body[0]["data"] == {"rev": "newer"}
    finally:
        app.dependency_overrides.pop(get_current_user, None)
        app.dependency_overrides[get_db] = _noop_db


# ══ Signature image upload ═══════════════════════════════════════════════════

@pytest.fixture
def sig_dir(tmp_path, monkeypatch):
    d = tmp_path / "uploads" / "marks_signatures"
    monkeypatch.setattr(marks_card_service, "SIGNATURE_DIR", str(d))
    return d


def _seed_card(db, sid, data=None):
    now = datetime(2026, 5, 1, tzinfo=timezone.utc)
    row = types.SimpleNamespace(
        id=uuid.uuid4(), student_id=sid, academic_year="2026-27",
        data=dict(data or {}), sent_to_parent_at=None,
        created_at=now, updated_at=now,
    )
    db.marks.append(row)
    return row


def _post_sig(client, url, *, role=None, ext="png", content=None):
    data = {"academic_year": "2026-27"}
    if role is not None:
        data["role"] = role
    return client.post(
        url,
        data=data,
        files={
            "file": (f"sign.{ext}", content or _PNG_1PX, "application/octet-stream")
        },
    )


def test_admin_uploads_signature_persisted_to_current_card(client, sig_dir):
    sid = uuid.uuid4()
    db = _marks_db_for(sid)
    _seed_card(db, sid, {"remarks": "good"})
    app.dependency_overrides[get_db] = _db_override(db)
    _as("admin")
    try:
        for role in ("parent", "class_teacher", "principal"):
            r = _post_sig(client, f"{API}/admin/marks/{sid}/signature", role=role)
            assert r.status_code == 200, r.text
            body = r.json()
            assert body["role"] == role
            assert body["data"][f"sig_{role}"] == body["path"]
            assert os.path.exists(
                os.path.join(str(sig_dir), os.path.basename(body["path"]))
            )
        assert db.marks[0].data["remarks"] == "good"   # marks untouched
        assert len(db.marks) == 1                       # still one current card
    finally:
        app.dependency_overrides.pop(get_current_user, None)
        app.dependency_overrides[get_db] = _noop_db


def test_replacing_a_signature_deletes_the_old_file(client, sig_dir):
    sid = uuid.uuid4()
    db = _marks_db_for(sid)
    _seed_card(db, sid)
    app.dependency_overrides[get_db] = _db_override(db)
    _as("admin")
    try:
        p1 = _post_sig(
            client, f"{API}/admin/marks/{sid}/signature", role="parent"
        ).json()["path"]
        p2 = _post_sig(
            client, f"{API}/admin/marks/{sid}/signature", role="parent",
            ext="jpg", content=_JPG_BYTES,
        ).json()["path"]
        assert p1 != p2
        assert db.marks[0].data["sig_parent"] == p2
        assert not os.path.exists(
            os.path.join(str(sig_dir), os.path.basename(p1))
        )
        assert os.path.exists(
            os.path.join(str(sig_dir), os.path.basename(p2))
        )
    finally:
        app.dependency_overrides.pop(get_current_user, None)
        app.dependency_overrides[get_db] = _noop_db


def test_signature_rejects_bad_role_and_bad_extension(client, sig_dir):
    sid = uuid.uuid4()
    db = _marks_db_for(sid)
    _seed_card(db, sid)
    app.dependency_overrides[get_db] = _db_override(db)
    _as("admin")
    try:
        base = f"{API}/admin/marks/{sid}/signature"
        assert _post_sig(client, base, role="teacher").status_code == 400
        assert _post_sig(client, base, role="parent", ext="gif").status_code == 400
        assert _post_sig(client, base, role="parent", ext="pdf").status_code == 400
    finally:
        app.dependency_overrides.pop(get_current_user, None)
        app.dependency_overrides[get_db] = _noop_db


def test_signature_requires_a_saved_card(client, sig_dir):
    sid = uuid.uuid4()
    db = _marks_db_for(sid)          # no card seeded
    app.dependency_overrides[get_db] = _db_override(db)
    _as("admin")
    try:
        r = _post_sig(client, f"{API}/admin/marks/{sid}/signature", role="parent")
        assert r.status_code == 404
    finally:
        app.dependency_overrides.pop(get_current_user, None)
        app.dependency_overrides[get_db] = _noop_db


@pytest.mark.parametrize("role", ["parent", "teacher", "coordinator"])
def test_admin_signature_endpoint_is_admin_only(client, role):
    _as(role)
    try:
        r = _post_sig(
            client, f"{API}/admin/marks/{uuid.uuid4()}/signature", role="parent"
        )
        assert r.status_code == 403
    finally:
        app.dependency_overrides.pop(get_current_user, None)


def test_marks_save_preserves_uploaded_signatures(client, sig_dir):
    sid = uuid.uuid4()
    db = _marks_db_for(sid)
    _seed_card(db, sid, {"remarks": "r1"})
    app.dependency_overrides[get_db] = _db_override(db)
    try:
        _as("admin")
        sig = _post_sig(
            client, f"{API}/admin/marks/{sid}/signature", role="class_teacher"
        ).json()["path"]

        # a normal Admin marks Save that doesn't carry the signature key
        r = client.put(
            f"{API}/admin/marks/{sid}",
            json={"academic_year": "2026-27", "data": {"remarks": "r2"}},
        )
        assert r.status_code == 200
        assert r.json()["data"]["remarks"] == "r2"
        assert r.json()["data"]["sig_class_teacher"] == sig   # survived

        # a Teacher marks Save preserves it too
        _as("teacher")
        r = client.put(
            f"{API}/teacher/marks/{sid}",
            json={"academic_year": "2026-27", "data": {"remarks": "r3"}},
        )
        assert r.status_code == 200
        assert r.json()["data"]["sig_class_teacher"] == sig
    finally:
        app.dependency_overrides.pop(get_current_user, None)
        app.dependency_overrides[get_db] = _noop_db


def test_teacher_uploads_signature_for_own_class_student(client, sig_dir):
    sid = uuid.uuid4()
    db = _marks_db_for(sid)
    _seed_card(db, sid)
    app.dependency_overrides[get_db] = _db_override(db)
    _as("teacher")
    try:
        r = _post_sig(
            client, f"{API}/teacher/marks/{sid}/signature", role="principal"
        )
        assert r.status_code == 200, r.text
        assert db.marks[0].data["sig_principal"] == r.json()["path"]
    finally:
        app.dependency_overrides.pop(get_current_user, None)
        app.dependency_overrides[get_db] = _noop_db


def test_parent_uploads_only_the_parent_signature(client, sig_dir):
    sid = uuid.uuid4()
    db = _marks_db_for(sid)
    _seed_card(db, sid)
    app.dependency_overrides[get_db] = _db_override(db)
    _as("parent")
    try:
        url = f"{API}/parent/marks-cards/{sid}/signature"
        r = _post_sig(client, url)                    # no role field accepted
        assert r.status_code == 200, r.text
        assert r.json()["role"] == "parent"
        assert db.marks[0].data["sig_parent"] == r.json()["path"]

        # a smuggled role field is ignored — parent can only ever write sig_parent
        r = _post_sig(client, url, role="principal")
        assert r.status_code == 200
        assert r.json()["role"] == "parent"
        assert "sig_principal" not in db.marks[0].data
    finally:
        app.dependency_overrides.pop(get_current_user, None)
        app.dependency_overrides[get_db] = _noop_db


def test_parent_cannot_upload_signature_for_an_unlinked_student(client, sig_dir):
    session = _FakeSession({ParentStudentLink: []})   # no link
    app.dependency_overrides[get_db] = _db_override(session)
    _as("parent")
    try:
        r = _post_sig(
            client, f"{API}/parent/marks-cards/{uuid.uuid4()}/signature"
        )
        assert r.status_code == 403
    finally:
        app.dependency_overrides.pop(get_current_user, None)
        app.dependency_overrides[get_db] = _noop_db


def test_uploaded_signature_reaches_the_parent_marks_cards_feed(
    client, sig_dir, monkeypatch
):
    monkeypatch.setattr(marks_api, "post_event_message", lambda *a, **k: None)
    sid = uuid.uuid4()
    db = _marks_db_for(sid)
    _seed_card(db, sid, {"remarks": "ok"})
    app.dependency_overrides[get_db] = _db_override(db)
    try:
        _as("admin")
        sig = _post_sig(
            client, f"{API}/admin/marks/{sid}/signature", role="parent"
        ).json()["path"]
        assert client.post(
            f"{API}/admin/marks/{sid}/send-to-parent"
        ).status_code == 200

        _as("parent")
        body = client.get(f"{API}/parent/marks-cards").json()["marks_cards"]
        assert len(body) == 1
        assert body[0]["data"]["sig_parent"] == sig
    finally:
        app.dependency_overrides.pop(get_current_user, None)
        app.dependency_overrides[get_db] = _noop_db
