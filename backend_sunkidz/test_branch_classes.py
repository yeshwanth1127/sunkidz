"""The 4 canonical grade/class options must be present + consistently ordered
for every branch (this is what every dropdown in the app reads).

Run: python -m pytest test_branch_classes.py -q

No live DB: `ensure_standard_classes` is exercised against a tiny fake
session, and `GET /admin/classes` (the shared class source for Daily Reports,
Marks Card, Attendance, ...) is checked with dependency overrides.
"""
import sys
import types
import uuid

import pytest
from fastapi.testclient import TestClient

sys.path.insert(0, ".")

from app.main import app  # noqa: E402
from app.core.auth import get_current_user  # noqa: E402
from app.core.database import get_db  # noqa: E402
from app.models.branch import Branch, Class  # noqa: E402
from app.services.class_provisioning import ensure_standard_classes  # noqa: E402

API = "/api/v1"
CANONICAL = ["Playgroup", "IG1", "IG2", "IG3"]


def _cls(branch_id, name):
    return types.SimpleNamespace(
        id=uuid.uuid4(), branch_id=branch_id, name=name, academic_year="2026-27"
    )


class _Q:
    def __init__(self, rows):
        self._rows = list(rows)

    def filter(self, *a, **k):
        return self

    def all(self):
        return list(self._rows)


class _ProvisionDB:
    """Fake session for ensure_standard_classes: one branch, a mutable class list."""

    def __init__(self, branch_id, class_names):
        self.branch_id = branch_id
        self.classes = [_cls(branch_id, n) for n in class_names]
        self.added = []
        self.commits = 0

    def query(self, model):
        if model is Branch:
            return _Q([types.SimpleNamespace(id=self.branch_id)])
        if model is Class:
            return _Q(self.classes)
        return _Q([])

    def add(self, obj):
        self.added.append(obj)
        self.classes.append(obj)

    def commit(self):
        self.commits += 1


# ── ensure_standard_classes ─────────────────────────────────────────────────

def test_missing_playgroup_is_added_once():
    bid = uuid.uuid4()
    db = _ProvisionDB(bid, ["IG1", "IG2", "IG3"])  # Munekolala's state
    n = ensure_standard_classes(db)
    assert n == 1
    assert [c.name for c in db.added] == ["Playgroup"]
    assert db.commits == 1
    # a second pass is a no-op
    assert ensure_standard_classes(db) == 0


@pytest.mark.parametrize(
    "names",
    [
        ["Playgroup", "IG1", "IG2", "IG3"],          # already complete
        ["Playschool", "IG1", "IG2", "IG3"],         # retired spelling == Playgroup
        ["IG-1", "IG-2", "IG-3", "Playgroup"],       # dash spellings == IG1/2/3
        ["Playgroup", "IG1", "IG2", "IG3", "Special Batch"],  # + a custom class
    ],
)
def test_no_duplicates_and_custom_classes_are_left_alone(names):
    db = _ProvisionDB(uuid.uuid4(), names)
    before = list(db.classes)
    assert ensure_standard_classes(db) == 0
    assert db.added == []
    assert db.classes == before  # nothing removed either


def test_every_branch_is_topped_up():
    class _MultiDB:
        def __init__(self, branch_classes):
            self.branches = [types.SimpleNamespace(id=uuid.uuid4()) for _ in branch_classes]
            self.by_branch = {
                b.id: [_cls(b.id, n) for n in names]
                for b, names in zip(self.branches, branch_classes)
            }
            self.added = []
            self.commits = 0

        def query(self, model):
            if model is Branch:
                return _Q(self.branches)
            if model is Class:
                return _ClassQ(self)
            return _Q([])

        def add(self, obj):
            self.added.append(obj)
            self.by_branch.setdefault(obj.branch_id, []).append(obj)

        def commit(self):
            self.commits += 1

    class _ClassQ:
        def __init__(self, db):
            self._db = db
            self._bid = None

        def filter(self, expr):
            # Class.branch_id == <bid>  -> pull the literal off the BinaryExpression
            try:
                self._bid = expr.right.value
            except Exception:
                self._bid = None
            return self

        def all(self):
            if self._bid is None:
                return [c for rows in self._db.by_branch.values() for c in rows]
            return list(self._db.by_branch.get(self._bid, []))

    db = _MultiDB([["IG1", "IG2", "IG3"], ["Playschool", "IG1", "IG2", "IG3"], []])
    n = ensure_standard_classes(db)
    # branch 1 missing Playgroup (1), branch 2 complete (0), branch 3 empty (4)
    assert n == 5
    for bid, rows in db.by_branch.items():
        from app.core.class_names import normalize_class_name
        have = {normalize_class_name(c.name) for c in rows}
        assert set(CANONICAL).issubset(have)


# ── the shared class source: GET /admin/classes ────────────────────────────

class _ListClassesDB:
    def __init__(self, rows):
        self._rows = rows

    def query(self, model):
        return _Q(self._rows)


@pytest.fixture
def client():
    app.dependency_overrides[get_current_user] = lambda: types.SimpleNamespace(
        id=uuid.uuid4(), role="admin", is_active="true", full_name="admin"
    )
    yield TestClient(app)
    app.dependency_overrides.clear()


def test_admin_classes_lists_playgroup_first_in_canonical_order(client):
    bid = uuid.uuid4()
    # deliberately unsorted, includes the freshly-added Playgroup row
    rows = [_cls(bid, n) for n in ["IG3", "Playgroup", "IG1", "IG2"]]

    def _db():
        yield _ListClassesDB(rows)

    app.dependency_overrides[get_db] = _db
    try:
        r = client.get(f"{API}/admin/classes", params={"branch_id": str(bid)})
        assert r.status_code == 200, r.text
        assert [c["name"] for c in r.json()] == CANONICAL
    finally:
        app.dependency_overrides.pop(get_db, None)
