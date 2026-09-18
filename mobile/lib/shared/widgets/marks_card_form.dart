import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/branch_system.dart';

/// Reusable, editable Sun Kidz PERFORMANCE PROFILE / marks card.
///
/// Used by the admin Marks Card screen and the teacher marks entry screen.
/// Every value shown here is data-driven:
///   * student identity fields (name / parents / DOB / class) come from the
///     selected student record and are shown read-only (editing those means
///     editing the student database, which is out of scope for this screen);
///   * attendance, all scholastic assessment values, co-scholastic grades,
///     the class-teacher remark and the "passed to" grade are editable and
///     persisted into [MarksCard.data] (a free-form JSON blob) via [onSave].
///
/// The subject / activity list and the co-scholastic categories below are a
/// *structure template* modelled on the school's printed report card. They are
/// layout scaffolding, not a particular student's results — no sample marks,
/// names or remarks are hard-coded.
class MarksCardForm extends StatefulWidget {
  final Map<String, dynamic> student;
  final String academicYear;
  final Map<String, dynamic> initialData;

  /// Persists the edited card. Required unless [readOnly] is true.
  final Future<void> Function(Map<String, dynamic> data)? onSave;
  final String? error;

  /// When true the card is rendered as a static, read-only PERFORMANCE PROFILE:
  /// every editable control (attendance / scholastic / co-scholastic / remarks /
  /// "passed to" fields and the "Save Marks" button) is replaced by plain text.
  /// The layout, columns, sections, legend and data model are identical to the
  /// editable card — this is the parent's view of the exact card Admin saved.
  final bool readOnly;

  /// School address printed under the "Sun Kidz" heading.
  final String schoolAddress;

  /// Uploads a signature image for [role] ('parent' | 'class_teacher' |
  /// 'principal'). Returns the stored path (relative, e.g.
  /// `uploads/marks_signatures/x.png`) on success, or null on failure. When set
  /// (with the role also listed in [signatureUploadRoles]) an
  /// "Upload / Replace" control appears in that signature slot — this works even
  /// in [readOnly] mode so a parent can sign an otherwise read-only card.
  final Future<String?> Function(String role, Uint8List bytes, String filename)?
  onUploadSignature;

  /// Signature roles the current user is allowed to upload. Empty = view only.
  final Set<String> signatureUploadRoles;

  /// Base URL (no trailing slash) used to turn a stored signature path into a
  /// loadable image URL.
  final String? signatureBaseUrl;

  const MarksCardForm({
    super.key,
    required this.student,
    required this.academicYear,
    required this.initialData,
    this.onSave,
    this.readOnly = false,
    this.error,
    this.schoolAddress =
        'No 66, 3rd Cross, Ashwathnagar, Marathahalli, Bangalore 560037',
    this.onUploadSignature,
    this.signatureUploadRoles = const {},
    this.signatureBaseUrl,
  }) : assert(
         readOnly || onSave != null,
         'onSave is required unless readOnly is true',
       );

  @override
  State<MarksCardForm> createState() => _MarksCardFormState();
}

class _MarksCardFormState extends State<MarksCardForm> {
  late Map<String, dynamic> _data;
  bool _saving = false;

  /// Column headers for the scholastic table, in printed order. "Term 1"
  /// (PT1 + CA1 + HY), "Term 2" (PT2 + CA2 + AN) and "Total" (Term 1 + Term 2)
  /// are derived, read-only cells.
  static const _scholasticHeaders = [
    'PT1',
    'CA1',
    'HY',
    'Term 1',
    'PT2',
    'CA2',
    'AN',
    'Term 2',
    'Total',
  ];

  /// Subject → activity rows. Structure template based on the school report
  /// card; not a student's data.
  static const Map<String, List<String>> _subjects = {
    'English': [
      'Writing',
      'Dictation',
      'Reading',
      'Rhymes',
      'Conversation',
      'Story Telling',
    ],
    'Kannada': ['Writing', 'Dictation', 'Reading'],
    'Hindi': ['Writing', 'Dictation', 'Reading'],
    'Mathematics': ['Writing', 'Dictation', 'Counting'],
    'General Knowledge': ['Oral', 'Writing'],
  };

  static const List<String> _coScholastic = [
    'Drawing and Coloring',
    'Emotional Stability',
    'Adaptability',
    'Confidence',
    'Hygiene & Cleanliness',
    'Discipline',
  ];

  static const List<List<String>> _gradeLegend = [
    ['90 to 100', 'A+'],
    ['75 to 89', 'A'],
    ['60 to 74', 'B+'],
    ['50 to 59', 'B'],
    ['35 to 49', 'C+'],
  ];

  /// One persistent controller / focus node per editable text field, keyed by a
  /// stable string. Owned by the State (not by the `TextFormField` widgets), so
  /// typing survives the full-form rebuild that every keystroke triggers — the
  /// scholastic/co-scholastic fields live inside `Table`s, whose cell elements
  /// are re-reconciled on each rebuild and would otherwise drop the field's
  /// internal controller + focus (the "can't type in the field" symptom).
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};

  /// One [ValueNotifier] per scholastic row, holding that row's derived totals
  /// as `(term1, term2, total)`. Editing a mark updates only the matching
  /// notifier — never `setState` on the whole form — so the [TextField] being
  /// typed into is not torn down and rebuilt on every keystroke (that rebuild
  /// storm is what silently dropped keystrokes / stopped the field accepting
  /// input in the running app).
  final Map<String, ValueNotifier<(int, int, int)>> _termTotals = {};

  /// Signature roles with an upload currently in flight (drives the per-slot
  /// spinner). Signature image paths themselves live in [_data] under
  /// `sig_parent` / `sig_class_teacher` / `sig_principal`.
  final Set<String> _sigUploading = {};

  ValueNotifier<(int, int, int)> _termTotalFor(String subject, String item) {
    final key = '$subject|$item';
    return _termTotals[key] ??= ValueNotifier<(int, int, int)>(
      _rowTotals(subject, item),
    );
  }

  TextEditingController _controllerFor(String key, String seed) {
    final existing = _controllers[key];
    if (existing != null) return existing;
    return _controllers[key] = TextEditingController(text: seed);
  }

  FocusNode _focusFor(String key) =>
      _focusNodes[key] ??= FocusNode(debugLabel: 'marks:$key');

  void _disposeFieldObjects() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final f in _focusNodes.values) {
      f.dispose();
    }
    for (final n in _termTotals.values) {
      n.dispose();
    }
    _controllers.clear();
    _focusNodes.clear();
    _termTotals.clear();
  }

  @override
  void initState() {
    super.initState();
    _data = Map<String, dynamic>.from(widget.initialData);
  }

  @override
  void didUpdateWidget(MarksCardForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.student['id'] != widget.student['id'] ||
        oldWidget.academicYear != widget.academicYear) {
      _data = Map<String, dynamic>.from(widget.initialData);
      // New student / year → the seeded field values change; rebuild the
      // controllers from the new data on the next build.
      _disposeFieldObjects();
    }
  }

  @override
  void dispose() {
    _disposeFieldObjects();
    super.dispose();
  }

  String _getStr(String key, [String def = '']) =>
      _data[key]?.toString() ?? def;

  /// Writes a value straight into [_data]. No `setState`: nothing visible is
  /// derived from these keys, and each editable field keeps its own text via a
  /// persistent controller, so a rebuild is neither needed nor wanted here
  /// (rebuilding on every keystroke is what dropped field focus before).
  void _set(String key, dynamic value) => _data[key] = value;

  void _setNested(String subject, String item, String col, String raw) {
    // Rebuild the nested maps as `Map<String, dynamic>` before writing: data
    // loaded from the backend (or seeded in tests) can arrive as `Map<String,
    // int>`, which would reject a String value.
    final subj =
        _data[subject] is Map
            ? Map<String, dynamic>.from(_data[subject] as Map)
            : <String, dynamic>{};
    final row =
        subj[item] is Map
            ? Map<String, dynamic>.from(subj[item] as Map)
            : <String, dynamic>{};
    // Store EXACTLY what was typed — a plain String, no parsing, no coercion,
    // no restriction. A scholastic cell may hold "18", "A+", "AB12+" or
    // "Excellent!" — whatever the user enters.
    row[col] = raw;
    subj[item] = row;
    _data[subject] = subj;
    // Refresh ONLY this row's derived Term 1 / Term 2 / Total cells via its
    // notifier. No `setState`: rebuilding the whole form on every keystroke
    // tears down and re-inflates every TextField, which drops keyboard input in
    // the running app (the "can't type in a mark field" bug).
    _termTotalFor(subject, item).value = _rowTotals(subject, item);
  }

  /// The raw stored string for a scholastic cell (empty string if unset).
  /// Values are stored verbatim, so this is the single source of truth for
  /// both the field's text and the derived Term 1 total.
  String _rawNested(String subject, String item, String col) {
    try {
      final v = ((_data[subject] as Map?)?[item] as Map?)?[col];
      return v?.toString() ?? '';
    } catch (_) {
      return '';
    }
  }

  /// Best-effort numeric reading of a scholastic cell for the derived
  /// Term 1 / Term 2 / Total cells only. Non-numeric entries (letter grades,
  /// words, symbols) count as 0 here but are still stored and displayed exactly
  /// as typed.
  int _numNested(String subject, String item, String col) =>
      int.tryParse(_rawNested(subject, item, col).trim()) ?? 0;

  int _sumCols(String subject, String item, List<String> cols) {
    var total = 0;
    for (final c in cols) {
      total += _numNested(subject, item, c);
    }
    return total;
  }

  /// `(term1, term2, total)` for a row.
  ///   Term 1 = PT1 + CA1 + HY
  ///   Term 2 = PT2 + CA2 + AN
  ///   Total  = Term 1 + Term 2
  (int, int, int) _rowTotals(String subject, String item) {
    final t1 = _sumCols(subject, item, const ['pt1', 'ca1', 'hy']);
    final t2 = _sumCols(subject, item, const ['pt2', 'ca2', 'an']);
    return (t1, t2, t1 + t2);
  }

  Future<void> _save() async {
    final onSave = widget.onSave;
    if (onSave == null) return;
    setState(() => _saving = true);
    try {
      await onSave(_data);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Marks saved')));
      }
    } catch (_) {
      // The parent surfaces errors through widget.error.
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.student;
    final dob = s['date_of_birth']?.toString();
    final dobStr = dob != null && dob.isNotEmpty ? dob.split('T').first : '—';
    final className = s['class_name']?.toString();
    final branchName = s['branch_name']?.toString();
    final classLabel =
        '${className != null && className.isNotEmpty ? canonicalGradeLabel(className) : '—'}'
        '${(branchName ?? '').isNotEmpty ? '  •  $branchName' : ''}';

    // Father Name and Mother Name each come strictly from their OWN student
    // field — `father_name` / `mother_name`. Never fall back to, or copy from,
    // the other parent or the linked-account name (that made both cells show
    // the same value). A genuinely empty field shows the "—" placeholder.
    String? ownName(String key) {
      final v = s[key]?.toString().trim();
      return (v != null && v.isNotEmpty) ? v : null;
    }

    return KeyedSubtree(
      key: ValueKey('${s['id']}_${widget.academicYear}'),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade400),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(),
            const SizedBox(height: 14),
            _sectionTitle('PERFORMANCE PROFILE'),
            const SizedBox(height: 8),
            _studentInfo(
              name: s['name']?.toString() ?? '—',
              father: ownName('father_name'),
              mother: ownName('mother_name'),
              dob: dobStr,
              classLabel: classLabel,
            ),
            const SizedBox(height: 18),
            _sectionTitle('SCHOLASTIC AREA'),
            const SizedBox(height: 8),
            _scholasticTable(),
            const SizedBox(height: 14),
            _legendAndAbbreviations(),
            const SizedBox(height: 18),
            _sectionTitle('CO-SCHOLASTIC AREA'),
            const SizedBox(height: 8),
            _coScholasticTable(),
            const SizedBox(height: 18),
            _remarksAndPassedTo(),
            const SizedBox(height: 20),
            _signatures(),
            if (widget.error != null) ...[
              const SizedBox(height: 12),
              Text(
                widget.error!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
            if (!widget.readOnly) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _saving ? null : _save,
                child:
                    _saving
                        ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Text('Save Marks'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _header() => Column(
    children: [
      Text(
        'Sun Kidz',
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        widget.schoolAddress,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
      ),
      const SizedBox(height: 2),
      Text(
        'Academic Year ${widget.academicYear}',
        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
      ),
    ],
  );

  Widget _sectionTitle(String text) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
    color: AppColors.primary.withValues(alpha: 0.10),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 13,
        letterSpacing: 1,
      ),
    ),
  );

  // ── Student information ───────────────────────────────────────────────────

  Widget _studentInfo({
    required String name,
    required String? father,
    required String? mother,
    required String dob,
    required String classLabel,
  }) {
    return Table(
      border: TableBorder.all(color: Colors.grey.shade300),
      columnWidths: const {
        0: FlexColumnWidth(1),
        1: FlexColumnWidth(1.3),
        2: FlexColumnWidth(1),
        3: FlexColumnWidth(1.3),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          children: [
            _infoLabel('Student Name'),
            _infoValue(name),
            _infoLabel('Mother Name'),
            _infoValue(mother ?? '—'),
          ],
        ),
        TableRow(
          children: [
            _infoLabel('Father Name'),
            _infoValue(father ?? '—'),
            _infoLabel('Attendance'),
            _attendanceField(),
          ],
        ),
        TableRow(
          children: [
            _infoLabel('Date of Birth'),
            _infoValue(dob),
            _infoLabel('Class'),
            _infoValue(classLabel),
          ],
        ),
      ],
    );
  }

  Widget _infoLabel(String text) => Container(
    color: Colors.grey.shade100,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
    child: Text(
      text,
      style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
    ),
  );

  Widget _infoValue(String text) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
    child: Text(
      text,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    ),
  );

  Widget _attendanceField() {
    if (widget.readOnly) {
      final v = _getStr('attendance');
      return _infoValue(v.isEmpty ? '—' : v);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: TextField(
        key: const ValueKey('attendance'),
        controller: _controllerFor('attendance', _getStr('attendance')),
        focusNode: _focusFor('attendance'),
        decoration: const InputDecoration(
          isDense: true,
          hintText: 'e.g. 182 / 210',
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        ),
        style: const TextStyle(fontSize: 12),
        onChanged: (v) => _set('attendance', v),
      ),
    );
  }

  /// A static value cell used for every editable position when [readOnly] —
  /// same padding / alignment / font as its editable counterpart, no border,
  /// no interaction.
  Widget _readOnlyCell(
    String value, {
    double fontSize = 11,
    EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
  }) => Padding(
    padding: padding,
    child: Text(
      value.isEmpty ? '—' : value,
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: fontSize),
    ),
  );

  // ── Scholastic table ──────────────────────────────────────────────────────

  Widget _scholasticTable() {
    const labelWidth = 150.0;
    const cellWidth = 52.0;
    final totalWidth = labelWidth + cellWidth * _scholasticHeaders.length;

    final rows = <TableRow>[
      TableRow(
        decoration: BoxDecoration(color: Colors.grey.shade200),
        children: [
          _headerCell('Subject / Activity', align: TextAlign.left),
          ..._scholasticHeaders.map((h) => _headerCell(h)),
        ],
      ),
    ];

    _subjects.forEach((subject, activities) {
      final key = _subjectKey(subject);
      rows.add(
        TableRow(
          decoration: BoxDecoration(color: Colors.grey.shade100),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Text(
                subject,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
            ...List.filled(_scholasticHeaders.length, const SizedBox()),
          ],
        ),
      );
      for (final activity in activities) {
        rows.add(
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.only(
                  left: 20,
                  right: 8,
                  top: 6,
                  bottom: 6,
                ),
                child: Text(activity, style: const TextStyle(fontSize: 11.5)),
              ),
              _markInput(key, activity, 'pt1'),
              _markInput(key, activity, 'ca1'),
              _markInput(key, activity, 'hy'),
              _derivedTotalCell(key, activity, (t) => t.$1), // Term 1
              _markInput(key, activity, 'pt2'),
              _markInput(key, activity, 'ca2'),
              _markInput(key, activity, 'an'),
              _derivedTotalCell(key, activity, (t) => t.$2), // Term 2
              _derivedTotalCell(key, activity, (t) => t.$3), // Total
            ],
          ),
        );
      }
    });

    return _horizontalScroll(
      width: totalWidth,
      child: Table(
        border: TableBorder.all(color: Colors.grey.shade300, width: 0.6),
        columnWidths: {
          0: const FixedColumnWidth(labelWidth),
          for (var i = 1; i <= _scholasticHeaders.length; i++)
            i: const FixedColumnWidth(cellWidth),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: rows,
      ),
    );
  }

  Widget _headerCell(String text, {TextAlign align = TextAlign.center}) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Text(
          text,
          textAlign: align,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
        ),
      );

  /// A scholastic assessment cell — a completely unrestricted free-text field.
  /// No `keyboardType`, no `inputFormatters`, no `digitsOnly`, no regex, no
  /// validator, no `maxLength`, no allowed-values list. Whatever the user types
  /// (digits, letters, `A+`, `AB12+`, `Excellent!`, spaces, symbols) is stored
  /// verbatim through [_setNested]. Same State-owned controller / focus node as
  /// every other field, so typing never rebuilds or disconnects it.
  Widget _markInput(String subject, String item, String col) {
    final fieldKey = '$subject.$item.$col';
    if (widget.readOnly) {
      return _readOnlyCell(_rawNested(subject, item, col));
    }
    return Padding(
      padding: const EdgeInsets.all(3),
      child: TextField(
        key: ValueKey(fieldKey),
        controller: _controllerFor(fieldKey, _rawNested(subject, item, col)),
        focusNode: _focusFor(fieldKey),
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 11),
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 2, vertical: 6),
          border: OutlineInputBorder(),
        ),
        onChanged: (val) => _setNested(subject, item, col, val),
      ),
    );
  }

  /// A derived, read-only scholastic total cell (Term 1 / Term 2 / Total).
  /// Rebuilds only when this row's `(term1, term2, total)` notifier changes, so
  /// it never disturbs the mark [TextField] being typed into.
  Widget _derivedTotalCell(
    String subject,
    String item,
    int Function((int, int, int) totals) pick,
  ) => ValueListenableBuilder<(int, int, int)>(
    valueListenable: _termTotalFor(subject, item),
    builder: (context, totals, _) => _derivedCell(pick(totals)),
  );

  Widget _derivedCell(int value) => Container(
    color: Colors.grey.shade100,
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(
      value == 0 ? '—' : '$value',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Colors.grey.shade700,
      ),
    ),
  );

  // ── Legend + abbreviations ────────────────────────────────────────────────

  Widget _legendAndAbbreviations() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Scholastic Grade', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: Table(
            border: TableBorder.all(color: Colors.grey.shade300),
            columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1)},
            children: [
              TableRow(
                decoration: BoxDecoration(color: Colors.grey.shade200),
                children: [
                  _headerCell('Marks %', align: TextAlign.left),
                  _headerCell('Grade'),
                ],
              ),
              ..._gradeLegend.map(
                (r) => TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Text(r[0], style: const TextStyle(fontSize: 11.5)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        r[1],
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'PT = Periodic Test    CA = Class Assessment\n'
          'HY = Half Yearly    AN = Annual',
          style: TextStyle(fontSize: 10.5, color: Colors.grey.shade700),
        ),
      ],
    );
  }

  // ── Co-scholastic ─────────────────────────────────────────────────────────

  Widget _coScholasticTable() {
    const labelWidth = 200.0;
    const cellWidth = 90.0;
    // Fluid columns (no horizontal `Scrollable`): only three columns, two of
    // them inline grade fields. A scroll view here would put a horizontal drag
    // recognizer in front of the field taps and they would misbehave in the
    // running app. Flex widths keep the same 200 : 90 : 90 proportions and the
    // 380-wide cap matches the previous fixed layout on a phone.
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: labelWidth + cellWidth * 2),
        child: Table(
          border: TableBorder.all(color: Colors.grey.shade300, width: 0.6),
          columnWidths: const {
            0: FlexColumnWidth(labelWidth / cellWidth),
            1: FlexColumnWidth(1),
            2: FlexColumnWidth(1),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            TableRow(
              decoration: BoxDecoration(color: Colors.grey.shade200),
              children: [
                _headerCell('Area', align: TextAlign.left),
                _headerCell('Term 1'),
                _headerCell('Term 2'),
              ],
            ),
            ..._coScholastic.map((area) {
              final slug = area.toLowerCase().replaceAll(
                RegExp(r'[^a-z0-9]'),
                '_',
              );
              return TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    child: Text(area, style: const TextStyle(fontSize: 11.5)),
                  ),
                  _coGradeCell('co_${slug}_t1'),
                  _coGradeCell('co_${slug}_t2'),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  /// Co-scholastic grade cell — a completely unrestricted free-text field.
  /// No input formatter, keyboard type, validation or allowed-values list: the
  /// raw string the user types is stored verbatim in [_data] (letters, digits,
  /// symbols, spaces, whole words — anything). Uses the State-owned controller /
  /// focus node like every other field here, and writes through [_set] (no
  /// `setState`), so typing never rebuilds or disconnects the field.
  Widget _coGradeCell(String key) {
    if (widget.readOnly) {
      return _readOnlyCell(_getStr(key), fontSize: 12);
    }
    return Padding(
      padding: const EdgeInsets.all(4),
      child: TextField(
        key: ValueKey(key),
        controller: _controllerFor(key, _getStr(key)),
        focusNode: _focusFor(key),
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12),
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          border: OutlineInputBorder(),
        ),
        onChanged: (v) => _set(key, v),
      ),
    );
  }

  // ── Remarks / passed to ───────────────────────────────────────────────────

  Widget _remarksAndPassedTo() {
    if (widget.readOnly) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _readOnlyField('Class Teacher Remarks', _getStr('remarks')),
          const SizedBox(height: 12),
          _readOnlyField('Passed to', _getStr('passed_to')),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const ValueKey('remarks'),
          controller: _controllerFor('remarks', _getStr('remarks')),
          focusNode: _focusFor('remarks'),
          decoration: const InputDecoration(
            labelText: 'Class Teacher Remarks',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          maxLines: 3,
          onChanged: (v) => _set('remarks', v),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('passed_to'),
          controller: _controllerFor('passed_to', _getStr('passed_to')),
          focusNode: _focusFor('passed_to'),
          decoration: const InputDecoration(
            labelText: 'Passed to',
            hintText: 'Promoted grade, e.g. IG3',
            border: OutlineInputBorder(),
          ),
          onChanged: (v) => _set('passed_to', v),
        ),
      ],
    );
  }

  /// Read-only label + boxed value, mirroring the outlined text-field look of
  /// the editable "remarks" / "passed to" fields without any interaction.
  Widget _readOnlyField(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
      ),
      const SizedBox(height: 4),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          value.isEmpty ? '—' : value,
          style: const TextStyle(fontSize: 13),
        ),
      ),
    ],
  );

  // ── Signatures ────────────────────────────────────────────────────────────

  Widget _signatures() => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Expanded(child: _signatureSlot('Parent', 'parent')),
      const SizedBox(width: 14),
      Expanded(child: _signatureSlot('Class Teacher', 'class_teacher')),
      const SizedBox(width: 14),
      Expanded(child: _signatureSlot('Principal', 'principal')),
    ],
  );

  Widget _signatureSlot(String label, String role) {
    final dataKey = 'sig_$role';
    return _SignatureSlot(
      key: ValueKey(dataKey),
      label: label,
      imageUrl: _signatureUrl(_getStr(dataKey)),
      canUpload:
          widget.onUploadSignature != null &&
          widget.signatureUploadRoles.contains(role),
      uploading: _sigUploading.contains(role),
      onPick: () => _pickAndUploadSignature(role),
    );
  }

  /// Turns a stored signature path into a loadable URL. Absolute URLs and empty
  /// values pass straight through.
  String? _signatureUrl(String path) {
    if (path.isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final base = widget.signatureBaseUrl;
    if (base == null || base.isEmpty) return null;
    return '${base.endsWith('/') ? base.substring(0, base.length - 1) : base}/$path';
  }

  Future<void> _pickAndUploadSignature(String role) async {
    final upload = widget.onUploadSignature;
    if (upload == null || _sigUploading.contains(role)) return;

    FilePickerResult? res;
    try {
      res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['png', 'jpg', 'jpeg'],
        withData: true,
      );
    } catch (_) {
      res = null;
    }
    if (res == null || res.files.isEmpty) return;
    final f = res.files.single;
    final bytes = f.bytes;
    final ext = (f.extension ?? '').toLowerCase();
    if (bytes == null || !const ['png', 'jpg', 'jpeg'].contains(ext)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Choose a PNG, JPG or JPEG image')),
        );
      }
      return;
    }

    setState(() => _sigUploading.add(role));
    try {
      final path = await upload(role, bytes, f.name);
      if (!mounted) return;
      if (path != null && path.isNotEmpty) {
        setState(() => _data['sig_$role'] = path);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Signature upload failed')),
        );
      }
    } finally {
      if (mounted) setState(() => _sigUploading.remove(role));
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _subjectKey(String subject) =>
      subject.toLowerCase().replaceAll(RegExp(r'\s+'), '_');

  /// Wraps a fixed-width [child] (a report-card table) in a horizontal scroll
  /// view so it is fully reachable on a phone-width screen without crushing
  /// columns. Deliberately plain: no [Scrollbar]/[ScrollController] wrapper —
  /// a second scrollbar layer on top of the outer page scroll was fragile on
  /// web (shared-controller assertions) and is not needed for drag/trackpad
  /// scrolling. Pointer events pass straight through to the table's fields.
  Widget _horizontalScroll({required double width, required Widget child}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sized = SizedBox(width: width, child: child);
        // Only introduce a horizontal `Scrollable` when the table genuinely
        // overflows. A scroll view here adds a horizontal drag recognizer that
        // competes in the gesture arena with the taps that open the inline
        // grade dropdowns / focus the mark fields; skipping it when everything
        // already fits (tablets, wide phones, landscape) makes those taps land
        // reliably. Layout is visually identical at rest either way.
        if (constraints.maxWidth.isFinite && constraints.maxWidth >= width) {
          return Align(alignment: Alignment.centerLeft, child: sized);
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: sized,
        );
      },
    );
  }
}

/// One signature column: an image preview above the ruled line, the role label
/// below it, and (when [canUpload]) an Upload / Replace control. The line +
/// label layout is unchanged from the printed-card design; the preview simply
/// occupies the space above the line that a hand signature would.
class _SignatureSlot extends StatelessWidget {
  const _SignatureSlot({
    super.key,
    required this.label,
    required this.imageUrl,
    required this.canUpload,
    required this.uploading,
    required this.onPick,
  });

  final String label;
  final String? imageUrl;
  final bool canUpload;
  final bool uploading;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: hasImage ? 46 : 28,
          child:
              hasImage
                  ? Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Image.network(
                      imageUrl!,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  )
                  : null,
        ),
        Container(height: 1, color: Colors.grey.shade500),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
        ),
        if (canUpload) ...[
          const SizedBox(height: 2),
          uploading
              ? const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
              : TextButton.icon(
                onPressed: onPick,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: const Size(0, 26),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                icon: Icon(
                  hasImage ? Icons.autorenew : Icons.upload_file,
                  size: 15,
                ),
                label: Text(
                  hasImage ? 'Replace' : 'Upload',
                  style: const TextStyle(fontSize: 10.5),
                ),
              ),
        ],
      ],
    );
  }
}
