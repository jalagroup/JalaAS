// lib/screens/web/quality_checklist_form_screen.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jala_as/models/quality_models.dart';
import '../../../models/user.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/constants.dart';
import '../../../utils/helpers.dart';
import 'dart:ui' as ui;
import 'dart:io';
import '../../utils/file_utils.dart';
import '../../../services/quality_image_cache.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PendingIssue
// ─────────────────────────────────────────────────────────────────────────────
class PendingIssue {
  final String checkPointId;
  final String checkPointTitle;
  final String formTitle;
  final String assignedTo;
  final String assignedToUsername;
  final String description;
  final DateTime responseDate;
  final List<Uint8List> imageBytes;
  final List<String> imageNames;
  // NEW: carry determinant state at the moment the issue was created
  final Map<String, dynamic> determinantValues;
  final List<Map<String, dynamic>> determinantDefinitions;

  PendingIssue({
    required this.checkPointId,
    required this.checkPointTitle,
    required this.formTitle,
    required this.assignedTo,
    required this.assignedToUsername,
    required this.description,
    required this.responseDate,
    required this.imageBytes,
    required this.imageNames,
    required this.determinantValues,
    required this.determinantDefinitions,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Design tokens
// ─────────────────────────────────────────────────────────────────────────────
class _T {
  static const primary = Color(0xFF1A1F36);
  static const accent = Color(0xFF6C63FF);
  static const accentLight = Color(0xFFEEEDFF);
  static const success = Color(0xFF00C48C);
  static const warning = Color(0xFFFFAB00);
  static const danger = Color(0xFFFF5252);
  static const surface = Color(0xFFFFFFFF);
  static const bg = Color(0xFFF5F6FA);
  static const border = Color(0xFFE8E9F0);
  static const text = Color(0xFF1A1F36);
  static const textMuted = Color(0xFF8F95B2);
  static const textSub = Color(0xFF4E5D78);

  static const radius = 10.0;
  static const radiusSm = 6.0;
  static const radiusLg = 14.0;

  static BoxDecoration card({Color? border, bool shadow = false}) =>
      BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border ?? _T.border),
        boxShadow: shadow
            ? [
                BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ]
            : null,
      );

  static TextStyle get labelSm => const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: textMuted,
      letterSpacing: 0.5);
  static TextStyle get labelMd =>
      const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textSub);
  static TextStyle get title =>
      const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: text);
  static TextStyle get titleLg =>
      const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: text);
  static TextStyle get body =>
      const TextStyle(fontSize: 13, color: textSub, height: 1.5);
}

// ─────────────────────────────────────────────────────────────────────────────
// Create Issue Dialog
// ─────────────────────────────────────────────────────────────────────────────
class _CreateIssueDialog extends StatefulWidget {
  final String checkPointId;
  final String checkPointTitle;
  final String formTitle;
  final List<AppUser> availableUsers;
  final DateTime responseDate;
  final Function(PendingIssue) onIssueCreated;
  // NEW
  final Map<String, dynamic> determinantValues;
  final List<Map<String, dynamic>> determinantDefinitions;

  const _CreateIssueDialog({
    required this.checkPointId,
    required this.checkPointTitle,
    required this.formTitle,
    required this.availableUsers,
    required this.responseDate,
    required this.onIssueCreated,
    required this.determinantValues,
    required this.determinantDefinitions,
  });

  @override
  State<_CreateIssueDialog> createState() => _CreateIssueDialogState();
}

class _CreateIssueDialogState extends State<_CreateIssueDialog> {
  int _step = 0;
  String? _selectedUserId;
  String? _selectedUsername;
  final _descriptionController = TextEditingController();
  final _searchController = TextEditingController();
  final List<Uint8List> _imageBytes = [];
  final List<String> _imageNames = [];
  bool _isPickingImages = false;
  List<AppUser> _filteredUsers = [];

  @override
  void initState() {
    super.initState();
    _filteredUsers = widget.availableUsers;
    _searchController.addListener(_filterUsers);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _filterUsers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredUsers = query.isEmpty
          ? widget.availableUsers
          : widget.availableUsers
              .where((u) =>
                  u.username.toLowerCase().contains(query) ||
                  u.userTypeDisplayText.toLowerCase().contains(query))
              .toList();
    });
  }

  Future<void> _pickImages() async {
    if (_isPickingImages) return;
    setState(() => _isPickingImages = true);
    try {
      final bytes = await FileUtils.instance
          .pickImages()
          .timeout(const Duration(seconds: 60), onTimeout: () => []);
      if (bytes.isEmpty) return;
      setState(() {
        for (int i = 0; i < bytes.length; i++) {
          _imageBytes.add(bytes[i]);
          _imageNames
              .add('issue_${DateTime.now().millisecondsSinceEpoch}_$i.jpg');
        }
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isPickingImages = false);
    }
  }

  void _createPendingIssue() {
    if (_descriptionController.text.trim().isEmpty) {
      Helpers.showSnackBar(context, 'يرجى إدخال وصف المشكلة', isError: true);
      return;
    }
    if (_selectedUserId == null) {
      Helpers.showSnackBar(context, 'يرجى اختيار المستخدم', isError: true);
      return;
    }
    widget.onIssueCreated(PendingIssue(
      checkPointId: widget.checkPointId,
      checkPointTitle: widget.checkPointTitle,
      formTitle: widget.formTitle,
      assignedTo: _selectedUserId!,
      assignedToUsername: _selectedUsername!,
      description: _descriptionController.text.trim(),
      responseDate: widget.responseDate,
      imageBytes: List.from(_imageBytes),
      imageNames: List.from(_imageNames),
      // NEW
      determinantValues: widget.determinantValues,
      determinantDefinitions: widget.determinantDefinitions,
    ));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: _T.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_T.radiusLg)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                  color: _T.danger.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(_T.radiusSm)),
              child:
                  const Icon(Icons.flag_outlined, color: _T.danger, size: 16),
            ),
            const SizedBox(width: 10),
            Text(_step == 0 ? 'اختر المسؤول' : 'تفاصيل المشكلة',
                style: _T.title),
          ],
        ),
        content: SizedBox(
          width: 380,
          child: _step == 0 ? _buildUserStep() : _buildDetailsStep(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child:
                const Text('إلغاء', style: TextStyle(color: _T.textMuted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _T.accent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_T.radiusSm)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: _step == 0
                ? (_selectedUserId == null
                    ? null
                    : () => setState(() => _step = 1))
                : _createPendingIssue,
            child: Text(_step == 0 ? 'التالي' : 'إضافة',
                style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildUserStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        TextField(
          controller: _searchController,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: 'بحث...',
            hintStyle: const TextStyle(color: _T.textMuted, fontSize: 13),
            prefixIcon:
                const Icon(Icons.search, size: 18, color: _T.textMuted),
            filled: true,
            fillColor: _T.bg,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(_T.radiusSm),
                borderSide: const BorderSide(color: _T.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(_T.radiusSm),
                borderSide: const BorderSide(color: _T.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(_T.radiusSm),
                borderSide:
                    const BorderSide(color: _T.accent, width: 1.5)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 260),
          child: _filteredUsers.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('لا توجد نتائج',
                      style:
                          const TextStyle(color: _T.textMuted, fontSize: 13),
                      textAlign: TextAlign.center),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: _filteredUsers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, i) {
                    final u = _filteredUsers[i];
                    final sel = _selectedUserId == u.id;
                    return InkWell(
                      onTap: () => setState(() {
                        _selectedUserId = u.id;
                        _selectedUsername = u.username;
                      }),
                      borderRadius: BorderRadius.circular(_T.radiusSm),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: sel ? _T.accentLight : _T.bg,
                          borderRadius:
                              BorderRadius.circular(_T.radiusSm),
                          border: Border.all(
                              color: sel
                                  ? _T.accent
                                  : Colors.transparent),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor:
                                  sel ? _T.accent : _T.border,
                              child: Text(u.username[0].toUpperCase(),
                                  style: TextStyle(
                                      color: sel
                                          ? Colors.white
                                          : _T.textMuted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(u.username,
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: sel
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: _T.text)),
                                Text(u.userTypeDisplayText,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: _T.textMuted)),
                              ],
                            )),
                            if (sel)
                              const Icon(Icons.check_circle,
                                  color: _T.accent, size: 16),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDetailsStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),

        // NEW: Show selected determinants as a summary card
        if (widget.determinantDefinitions.isNotEmpty &&
            widget.determinantValues.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: _T.accentLight,
              borderRadius: BorderRadius.circular(_T.radiusSm),
              border:
                  Border.all(color: _T.accent.withOpacity(0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.tune_outlined,
                      size: 12, color: _T.accent),
                  const SizedBox(width: 5),
                  Text('بيانات التقييم',
                      style: _T.labelSm.copyWith(color: _T.accent)),
                ]),
                const SizedBox(height: 6),
                ...widget.determinantDefinitions.map((def) {
                  final val =
                      widget.determinantValues[def['id']]?.toString() ??
                          '';
                  if (val.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Row(children: [
                      Text('${def['name']}: ',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _T.textSub)),
                      Expanded(
                        child: Text(val,
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _T.text),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ]),
                  );
                }).toList(),
              ],
            ),
          ),
        ],

        TextField(
          controller: _descriptionController,
          maxLines: 4,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            labelText: 'وصف المشكلة',
            labelStyle:
                const TextStyle(fontSize: 12, color: _T.textMuted),
            filled: true,
            fillColor: _T.bg,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(_T.radiusSm),
                borderSide: const BorderSide(color: _T.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(_T.radiusSm),
                borderSide: const BorderSide(color: _T.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(_T.radiusSm),
                borderSide:
                    const BorderSide(color: _T.accent, width: 1.5)),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _isPickingImages ? null : _pickImages,
          icon: _isPickingImages
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child:
                      CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.add_photo_alternate_outlined,
                  size: 16),
          label: Text(
              _isPickingImages
                  ? 'جارٍ التحميل...'
                  : 'إرفاق صور (اختياري)',
              style: const TextStyle(fontSize: 12)),
          style: OutlinedButton.styleFrom(
            foregroundColor: _T.accent,
            side: const BorderSide(color: _T.border),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_T.radiusSm)),
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
          ),
        ),
        if (_imageBytes.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 64,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _imageBytes.length,
              itemBuilder: (_, i) => Stack(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    margin: const EdgeInsets.only(left: 6),
                    decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(_T.radiusSm),
                        border: Border.all(color: _T.border)),
                    child: ClipRRect(
                        borderRadius:
                            BorderRadius.circular(_T.radiusSm),
                        child: Image.memory(_imageBytes[i],
                            fit: BoxFit.cover)),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _imageBytes.removeAt(i);
                        _imageNames.removeAt(i);
                      }),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                            color: _T.danger,
                            shape: BoxShape.circle),
                        child: const Icon(Icons.close,
                            size: 10, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main Screen
// ─────────────────────────────────────────────────────────────────────────────
class QualityChecklistFormScreen extends StatefulWidget {
  final AppUser user;
  final int checklistId;
  final QualityResponse? existingResponse;
  final bool readOnly;

  const QualityChecklistFormScreen({
    super.key,
    required this.user,
    required this.checklistId,
    this.existingResponse,
    this.readOnly = false,
  });

  @override
  State<QualityChecklistFormScreen> createState() =>
      _QualityChecklistFormScreenState();
}

class _QualityChecklistFormScreenState
    extends State<QualityChecklistFormScreen> {
  bool get _isEditMode => widget.existingResponse != null && !widget.readOnly;
  bool get _isReadOnly => widget.readOnly;

  QualitySession? _currentSession;
  QualityChecklist? _selectedChecklist;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isSubmitting = false;

  final List<PendingIssue> _pendingIssues = [];

  final Map<String, String> _determinantValues = {};
  final Map<String, CheckPointRating> _checkPointRatings = {};
  final Map<String, bool> _showNotesFields = {};
  final Map<String, bool> _showCorrectiveFields = {};
  final Map<String, double> _decimalRatings = {};

  final Map<String, TextEditingController> _ratingControllers = {};
  final Map<String, TextEditingController> _notesControllers = {};
  final Map<String, TextEditingController> _correctiveControllers = {};
  final TextEditingController _mainNotesController = TextEditingController();

  bool _isPickingImages = false;
  final List<XFile> _selectedImages = [];
  final Map<String, List<XFile>> _checkpointImages = {};
  final Map<String, bool> _isPickingCheckpointImages = {};

  Timer? _saveDebouncer;

  final List<String> _arabicMonths = [
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];

  @override
  void initState() {
    super.initState();
    _loadChecklist();
  }

  @override
  void dispose() {
    _saveDebouncer?.cancel();
    for (final c in _ratingControllers.values) c.dispose();
    for (final c in _notesControllers.values) c.dispose();
    for (final c in _correctiveControllers.values) c.dispose();
    _mainNotesController.dispose();
    super.dispose();
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  Future<void> _loadChecklist() async {
    setState(() => _isLoading = true);
    try {
      final checklist =
          await SupabaseService.getQualityChecklistById(widget.checklistId);
      if (checklist == null) throw Exception('Checklist not found');

      _selectedChecklist = checklist;
      _initializeForm();

      if (_isEditMode) {
        _loadResponseData(widget.existingResponse!);
      } else {
        final session = await SupabaseService.getActiveSession(
          groupId: _selectedChecklist!.groupId,
          userId: widget.user.id,
          checklistId: _selectedChecklist!.id,
        );
        if (session != null) {
          _currentSession = session;
          _loadSessionData(session.sessionData);
        }
        await _loadCachedImages();
      }
    } catch (e) {
      if (mounted)
        Helpers.showSnackBar(context, 'فشل في تحميل النموذج: $e',
            isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _loadResponseData(QualityResponse response) {
    _selectedDate = response.responseDate;
    _mainNotesController.text = response.mainNotes ?? '';

    for (final e in response.determinantValues.entries) {
      if (_determinantValues.containsKey(e.key)) {
        _determinantValues[e.key] = e.value.toString();
      }
    }

    for (final e in response.checkPointRatings.entries) {
      final id = e.key;
      if (!_checkPointRatings.containsKey(id)) continue;
      final rd = e.value as Map<String, dynamic>? ?? {};
      final raw = rd['rating'];
      final d = raw is int
          ? raw.toDouble()
          : (raw is double ? raw : double.tryParse(raw.toString()) ?? 1.0);
      final notes = rd['notes'] as String?;
      final ca = rd['corrective_action'] as String?;
      _checkPointRatings[id] =
          CheckPointRating(checkPointId: id, rating: d.round(), notes: notes, correctiveAction: ca);
      _decimalRatings[id] = d;
      _ratingControllers[id]?.text = _fmt(d);
      if (notes != null && notes.isNotEmpty) {
        _notesControllers[id]?.text = notes;
        _showNotesFields[id] = true;
      }
      if (ca != null && ca.isNotEmpty) {
        _correctiveControllers[id]?.text = ca;
        _showCorrectiveFields[id] = true;
      }
    }
  }

  void _initializeForm() {
    if (_selectedChecklist == null) return;
    for (final d in _selectedChecklist!.determinants) {
      _determinantValues[d.id] = '';
    }
    for (final cp in _selectedChecklist!.checkPoints) {
      _checkPointRatings[cp.id] =
          CheckPointRating(checkPointId: cp.id, rating: 1);
      _showNotesFields[cp.id] = false;
      _showCorrectiveFields[cp.id] = false;
      _decimalRatings[cp.id] = 1.0;
      _ratingControllers[cp.id] = TextEditingController(text: '1');
      _notesControllers[cp.id] = TextEditingController();
      _correctiveControllers[cp.id] = TextEditingController();
      _checkpointImages[cp.id] = [];
      _isPickingCheckpointImages[cp.id] = false;
    }
  }

  void _loadSessionData(Map<String, dynamic> data) {
    if (data['selected_date'] != null) {
      _selectedDate = DateTime.parse(data['selected_date']);
    }
    final rawNotes = data['main_notes'];
    if (rawNotes != null && rawNotes.toString().isNotEmpty) {
      _mainNotesController.text = rawNotes.toString();
    }

    final detVals =
        data['determinant_values'] as Map<String, dynamic>? ?? {};
    for (final e in detVals.entries) {
      if (_selectedChecklist!.determinants.any((d) => d.id == e.key)) {
        _determinantValues[e.key] = e.value.toString();
      }
    }

    final cpRatings =
        data['check_point_ratings'] as Map<String, dynamic>? ?? {};
    for (final e in cpRatings.entries) {
      final id = e.key;
      if (!_selectedChecklist!.checkPoints.any((cp) => cp.id == id)) continue;
      final rd = e.value as Map<String, dynamic>? ?? {};
      final raw = rd['rating'];
      final d = raw is int
          ? raw.toDouble()
          : (raw is double ? raw : double.tryParse(raw.toString()) ?? 1.0);
      final notes = rd['notes'] as String?;
      final ca = rd['corrective_action'] as String?;
      _checkPointRatings[id] = CheckPointRating(
          checkPointId: id,
          rating: d.round(),
          notes: notes,
          correctiveAction: ca);
      _decimalRatings[id] = d;
      _ratingControllers[id]?.text = _fmt(d);
      if (notes != null && notes.isNotEmpty) {
        _notesControllers[id]?.text = notes;
        _showNotesFields[id] = true;
      }
      if (ca != null && ca.isNotEmpty) {
        _correctiveControllers[id]?.text = ca;
        _showCorrectiveFields[id] = true;
      }
    }
  }

  String _fmt(double v) =>
      v == v.truncateToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  // ── Image cache ───────────────────────────────────────────────────────────

  String get _cacheKey =>
      QualityImageCache.cacheKey(widget.checklistId, widget.user.id);

  /// Persist the current in-memory images to sessionStorage (best-effort).
  Future<void> _cacheImages() async {
    await QualityImageCache.saveImages(
      _cacheKey,
      generalImages: _selectedImages,
      checkpointImages: _checkpointImages,
    );
  }

  /// Restore images from sessionStorage after a page reload.
  Future<void> _loadCachedImages() async {
    final cached = await QualityImageCache.loadImages(_cacheKey);
    if (cached == null || !mounted) return;
    setState(() {
      if (cached.general.isNotEmpty) {
        _selectedImages.addAll(cached.general);
      }
      for (final entry in cached.checkpoints.entries) {
        if (_checkpointImages.containsKey(entry.key)) {
          _checkpointImages[entry.key]!.addAll(entry.value);
        }
      }
    });
  }

  // ── Session save ──────────────────────────────────────────────────────────

  void _debouncedSave() {
    _saveDebouncer?.cancel();
    _saveDebouncer =
        Timer(const Duration(milliseconds: 1500), _saveSession);
  }

  Future<void> _saveSession() async {
    if (_isSaving || _selectedChecklist == null || !mounted) return;
    _isSaving = true;
    try {
      final data = _buildSessionData();
      if (_currentSession == null) {
        _currentSession = await SupabaseService.createSession(
          groupId: _selectedChecklist!.groupId,
          userId: widget.user.id,
          checklistId: _selectedChecklist!.id,
          sessionData: data,
        );
      } else {
        _currentSession = await SupabaseService.updateSession(
            sessionId: _currentSession!.id, sessionData: data);
      }
    } catch (e) {
      debugPrint('Session save error: $e');
    } finally {
      _isSaving = false;
    }
  }

  Map<String, dynamic> _buildSessionData() {
    final cpData = <String, dynamic>{};
    for (final e in _checkPointRatings.entries) {
      cpData[e.key] = {
        'rating': _decimalRatings[e.key] ?? e.value.rating.toDouble(),
        'notes': _notesControllers[e.key]?.text.trim(),
        'corrective_action': _correctiveControllers[e.key]?.text.trim(),
      };
    }
    return {
      'selected_date': _selectedDate.toIso8601String(),
      'determinant_values': _determinantValues,
      'check_point_ratings': cpData,
      'main_notes': _mainNotesController.text.trim(),
    };
  }

  // ── Rating helpers ────────────────────────────────────────────────────────

  void _updateRating(String id, double v) {
    final snapped = double.parse(v.toStringAsFixed(1));
    setState(() {
      _decimalRatings[id] = snapped;
      _checkPointRatings[id] =
          _checkPointRatings[id]!.copyWith(rating: snapped.round());
      _ratingControllers[id]?.text = _fmt(snapped);
    });
    _saveSession();
  }

  void _updateRatingFromText(String id, String value) {
    if (value.isEmpty || value == '.') return;
    final r = double.tryParse(value);
    final max = _selectedChecklist!.rateNumber.toDouble();
    if (r != null && r >= 0 && r <= max) {
      setState(() {
        _decimalRatings[id] = r;
        _checkPointRatings[id] =
            _checkPointRatings[id]!.copyWith(rating: r.round());
      });
      _saveSession();
    } else if (r != null && r > max) {
      setState(() {
        _decimalRatings[id] = max;
        _checkPointRatings[id] =
            _checkPointRatings[id]!.copyWith(rating: max.round());
        _ratingControllers[id]?.text = _fmt(max);
      });
      _saveSession();
    }
  }

  void _toggleNotes(String id) {
    setState(() {
      _showNotesFields[id] = !(_showNotesFields[id] ?? false);
      if (!_showNotesFields[id]!) _notesControllers[id]?.clear();
    });
    _saveSession();
  }

  void _toggleCorrective(String id) {
    setState(() {
      _showCorrectiveFields[id] = !(_showCorrectiveFields[id] ?? false);
      if (!_showCorrectiveFields[id]!) _correctiveControllers[id]?.clear();
    });
    _saveSession();
  }

  // ── Image helpers ─────────────────────────────────────────────────────────

  Future<void> _pickCheckpointImages(String cpId) async {
    if (_isPickingCheckpointImages[cpId] == true) return;
    setState(() => _isPickingCheckpointImages[cpId] = true);
    try {
      final bytes = await FileUtils.instance
          .pickImages()
          .timeout(const Duration(seconds: 60), onTimeout: () => []);
      if (bytes.isEmpty) return;
      for (int i = 0; i < bytes.length; i++) {
        await _processCheckpointBytes(cpId, bytes[i],
            'cp_${cpId}_${DateTime.now().millisecondsSinceEpoch}_$i.jpg');
      }
      _saveSession();
      _cacheImages();
    } catch (e) {
      if (mounted)
        Helpers.showSnackBar(context, 'فشل في اختيار الصور', isError: true);
    } finally {
      if (mounted) setState(() => _isPickingCheckpointImages[cpId] = false);
    }
  }

  Future<void> _processCheckpointBytes(
      String cpId, Uint8List bytes, String name) async {
    if (bytes.length > 10 * 1024 * 1024) return;
    if (mounted)
      setState(() {
        _checkpointImages[cpId] ??= [];
        _checkpointImages[cpId]!.add(
            XFile.fromData(bytes, name: name, mimeType: 'image/jpeg'));
      });
  }

  void _removeCheckpointImage(String cpId, int idx) {
    if (_checkpointImages[cpId] == null ||
        idx >= _checkpointImages[cpId]!.length) return;
    setState(() => _checkpointImages[cpId]!.removeAt(idx));
    _saveSession();
    _cacheImages();
  }

  Future<void> _pickGeneralImages() async {
    if (_isPickingImages) return;
    setState(() => _isPickingImages = true);
    try {
      final bytes = await FileUtils.instance
          .pickImages()
          .timeout(const Duration(seconds: 60), onTimeout: () => []);
      if (bytes.isEmpty) return;
      for (int i = 0; i < bytes.length; i++) {
        if (bytes[i].length <= 10 * 1024 * 1024) {
          setState(() => _selectedImages.add(XFile.fromData(bytes[i],
              name: 'img_${DateTime.now().millisecondsSinceEpoch}_$i.jpg',
              mimeType: 'image/jpeg')));
        }
      }
      _cacheImages();
    } catch (e) {
      if (mounted)
        Helpers.showSnackBar(context, 'فشل في اختيار الصور', isError: true);
    } finally {
      if (mounted) setState(() => _isPickingImages = false);
    }
  }

  void _removeGeneralImage(int idx) {
    if (idx >= 0 && idx < _selectedImages.length) {
      setState(() => _selectedImages.removeAt(idx));
      _cacheImages();
    }
  }

  // ── Issue dialog ──────────────────────────────────────────────────────────

  // FIX: Helper to check if all determinants are filled
  bool _areDeterminantsFilled() {
    if (_selectedChecklist == null) return false;
    for (final d in _selectedChecklist!.determinants) {
      if (_determinantValues[d.id] == null ||
          _determinantValues[d.id]!.trim().isEmpty) {
        return false;
      }
    }
    return true;
  }

  Future<void> _showIssueDialog(String cpId, String cpTitle) async {
    // FIX: Block dialog if determinants are not all filled
    if (_selectedChecklist != null &&
        _selectedChecklist!.determinants.isNotEmpty &&
        !_areDeterminantsFilled()) {
      // Find names of unfilled determinants for a helpful message
      final unfilled = _selectedChecklist!.determinants
          .where((d) =>
              _determinantValues[d.id] == null ||
              _determinantValues[d.id]!.trim().isEmpty)
          .map((d) => d.name)
          .toList();
      Helpers.showSnackBar(
        context,
        'يرجى تعبئة جميع المحددات أولاً: ${unfilled.join('، ')}',
        isError: true,
      );
      return;
    }

    final users = await SupabaseService.getUsers();
    final available =
        users.where((u) => u.isActive && u.id != widget.user.id).toList();
    if (available.isEmpty) {
      if (mounted)
        Helpers.showSnackBar(context, 'لا يوجد مستخدمون متاحون',
            isError: true);
      return;
    }
    if (!mounted) return;

    // Snapshot determinant definitions and values
    final List<Map<String, dynamic>> detDefs =
        (_selectedChecklist?.determinants ?? []).map((d) {
      return {
        'id': d.id,
        'name': d.name,
      };
    }).toList();

    final Map<String, dynamic> detValues =
        Map<String, dynamic>.from(_determinantValues);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CreateIssueDialog(
        checkPointId: cpId,
        checkPointTitle: cpTitle,
        formTitle: _selectedChecklist?.title ?? '',
        availableUsers: available,
        responseDate: _selectedDate,
        onIssueCreated: (issue) {
          setState(() => _pendingIssues.add(issue));
          if (mounted) Helpers.showSnackBar(context, 'تمت إضافة المشكلة');
        },
        determinantValues: detValues,
        determinantDefinitions: detDefs,
      ),
    );
  }

  // ── Validation & Submit ───────────────────────────────────────────────────

  bool _validateForm() {
    if (_selectedChecklist == null) return false;
    for (final d in _selectedChecklist!.determinants) {
      if (_determinantValues[d.id]?.isEmpty ?? true) {
        Helpers.showSnackBar(context, 'يرجى اختيار قيمة لـ ${d.name}',
            isError: true);
        return false;
      }
    }
    return true;
  }

  Future<void> _submitForm() async {
    if (!_validateForm()) return;
    final confirmed = await _showConfirmDialog();
    if (!confirmed) return;
    setState(() => _isSubmitting = true);
    try {
      final finalRatings = <String, dynamic>{};
      for (final e in _checkPointRatings.entries) {
        finalRatings[e.key] = {
          'rating': _decimalRatings[e.key] ?? e.value.rating.toDouble(),
          'notes': _notesControllers[e.key]?.text.trim(),
          'corrective_action': _correctiveControllers[e.key]?.text.trim(),
        };
      }

      final notesText = _mainNotesController.text.trim();

      if (_isEditMode) {
        await SupabaseService.updateQualityResponse(
          responseId: widget.existingResponse!.id,
          checkPointRatings: finalRatings,
          determinantValues: _determinantValues,
          mainNotes: notesText.isEmpty ? null : notesText,
        );
        if (mounted) {
          Helpers.showSnackBar(context, 'تم حفظ التعديلات بنجاح');
          Navigator.of(context).pop();
        }
        return;
      }

      List<Uint8List>? imgBytes;
      List<String>? imgNames;
      if (_selectedImages.isNotEmpty) {
        imgBytes = [];
        imgNames = [];
        for (final img in _selectedImages) {
          imgBytes.add(await img.readAsBytes());
          imgNames.add(img.name);
        }
      }

      Map<String, List<Map<String, dynamic>>>? cpImgData;
      if (_checkpointImages.isNotEmpty) {
        cpImgData = {};
        for (final e in _checkpointImages.entries) {
          if (e.value.isNotEmpty) {
            cpImgData[e.key] = [];
            for (final img in e.value) {
              cpImgData[e.key]!
                  .add({'bytes': await img.readAsBytes(), 'name': img.name});
            }
          }
        }
      }

      final response =
          await SupabaseService.submitQualityResponseWithCheckpointImages(
        groupId: _selectedChecklist!.groupId,
        checklistId: _selectedChecklist!.id,
        userId: widget.user.id,
        sessionId: _currentSession?.id,
        responseDate: _selectedDate,
        determinantValues: _determinantValues,
        checkPointRatings: finalRatings,
        imageBytes: imgBytes,
        imageNames: imgNames,
        checkpointImagesData: cpImgData,
        mainNotes: notesText.isEmpty ? null : notesText,
      );

      if (_pendingIssues.isNotEmpty && response != null) {
        await _submitPendingIssues(response.id);
      }
      if (_currentSession != null) {
        await SupabaseService.updateSession(
            sessionId: _currentSession!.id, isActive: false);
      }
      QualityImageCache.clearImages(_cacheKey);
      if (mounted) {
        Helpers.showSnackBar(context, 'تم إرسال النموذج بنجاح');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted)
        Helpers.showSnackBar(context, 'فشل في الإرسال: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // Pass determinant data through to SupabaseService
  Future<void> _submitPendingIssues(int responseId) async {
    for (final issue in _pendingIssues) {
      try {
        await SupabaseService.createQualityCheckpointIssue(
          responseId: responseId,
          checkPointId: issue.checkPointId,
          checkPointTitle: issue.checkPointTitle,
          formTitle: issue.formTitle,
          assignedTo: issue.assignedTo,
          description: issue.description,
          responseDate: issue.responseDate,
          imageBytes: issue.imageBytes.isNotEmpty ? issue.imageBytes : null,
          imageNames: issue.imageNames.isNotEmpty ? issue.imageNames : null,
          determinantValues: issue.determinantValues,
          determinantDefinitions: issue.determinantDefinitions,
        );
      } catch (e) {
        debugPrint('Issue submit error: $e');
      }
    }
  }

  Future<bool> _showConfirmDialog() async {
    int totalCpImages = 0;
    _checkpointImages.forEach((_, imgs) => totalCpImages += imgs.length);
    final hasNotes = _mainNotesController.text.trim().isNotEmpty;
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => Directionality(
            textDirection: ui.TextDirection.rtl,
            child: AlertDialog(
              backgroundColor: _T.surface,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_T.radiusLg)),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              title: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                        color: _T.accentLight,
                        borderRadius:
                            BorderRadius.circular(_T.radiusSm)),
                    child: const Icon(Icons.send_outlined,
                        color: _T.accent, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Text('تأكيد الإرسال', style: _T.title),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text(
                      'هل تريد إرسال النموذج؟ لن يمكن تعديله بعد الإرسال.',
                      style: _T.body),
                  const SizedBox(height: 10),
                  if (_pendingIssues.isNotEmpty)
                    _confirmBadge(Icons.flag_outlined,
                        'سيتم إنشاء ${_pendingIssues.length} مشكلة', _T.warning),
                  if (hasNotes)
                    _confirmBadge(Icons.sticky_note_2_outlined,
                        'تم إضافة ملاحظة عامة', Colors.blue),
                  if (totalCpImages > 0)
                    _confirmBadge(Icons.photo_library_outlined,
                        'إرفاق $totalCpImages صورة لنقاط الفحص', _T.success),
                  if (_selectedImages.isNotEmpty)
                    _confirmBadge(Icons.image_outlined,
                        'إرفاق ${_selectedImages.length} صورة عامة', _T.accent),
                  const SizedBox(height: 4),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('إلغاء',
                      style: TextStyle(color: _T.textMuted)),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _T.accent,
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(_T.radiusSm)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('إرسال',
                      style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ),
        ) ??
        false;
  }

  Widget _confirmBadge(IconData icon, String label, Color color) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 12,
                        color: color,
                        fontWeight: FontWeight.w500))),
          ],
        ),
      );

  // ── Date picker ───────────────────────────────────────────────────────────

  String _fmtDate(DateTime d) {
    final days = [
      'الاثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد'
    ];
    return '${days[d.weekday - 1]}، ${d.day} ${_arabicMonths[d.month - 1]} ${d.year}';
  }

  Future<void> _selectDate() async {
    try {
      final picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime.now().subtract(const Duration(days: 365)),
        lastDate: DateTime.now().add(const Duration(days: 30)),
        builder: (ctx, child) => Directionality(
          textDirection: ui.TextDirection.rtl,
          child: Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.light(
                  primary: _T.accent,
                  onPrimary: Colors.white,
                  onSurface: _T.text,
                  surface: _T.surface),
              dialogTheme: const DialogThemeData(
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.all(Radius.circular(12)))),
            ),
            child: child!,
          ),
        ),
      );
      if (picked != null && picked != _selectedDate) {
        setState(() => _selectedDate = picked);
        _saveSession();
      }
    } catch (_) {}
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isMobile = w < 640;
    final maxWidth = w > 960 ? 860.0 : double.infinity;
    final hPad = isMobile ? 14.0 : 24.0;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _T.bg,
        appBar: _buildAppBar(),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: _T.accent))
            : Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                        horizontal: hPad,
                        vertical: isMobile ? 14 : 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Read-only banner
                        if (_isReadOnly) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7ED),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: const Color(0xFFFED7AA)),
                            ),
                            child: const Row(children: [
                              Icon(Icons.visibility_outlined,
                                  size: 15, color: Color(0xFFD97706)),
                              SizedBox(width: 8),
                              Text('وضع العرض فقط — لا يمكن التعديل',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF92400E))),
                            ]),
                          ),
                        ],
                        // All form content — blocked from interaction when read-only
                        IgnorePointer(
                          ignoring: _isReadOnly,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildHeader(isMobile),
                              if (_selectedChecklist != null &&
                                  _selectedChecklist!
                                      .determinants.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                _buildDeterminants(isMobile),
                              ],
                              if (_selectedChecklist != null) ...[
                                const SizedBox(height: 12),
                                _buildCheckPoints(isMobile),
                              ],
                              const SizedBox(height: 12),
                              _buildGeneralImages(isMobile),
                              const SizedBox(height: 12),
                              _buildMainNotes(isMobile),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildSubmitButton(isMobile),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 1,
      backgroundColor: _T.surface,
      surfaceTintColor: _T.surface,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new,
            size: 18, color: _T.text),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        _isReadOnly
            ? 'عرض: ${_selectedChecklist?.title ?? ''}'
            : _isEditMode
                ? 'تعديل: ${_selectedChecklist?.title ?? ''}'
                : (_selectedChecklist?.title ?? 'نموذج مراقبة الجودة'),
        style: _T.title,
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        if (_isSaving)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 1.5, color: _T.accent)),
                const SizedBox(width: 6),
                Text('حفظ...', style: _T.labelSm),
              ],
            ),
          ),
      ],
    );
  }

  // ── Header card ───────────────────────────────────────────────────────────

  Widget _buildHeader(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 16),
      decoration: _T.card(shadow: true),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: _T.accentLight,
                borderRadius: BorderRadius.circular(_T.radiusSm)),
            child: const Icon(Icons.assignment_outlined,
                color: _T.accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_selectedChecklist?.description != null)
                  Text(_selectedChecklist!.description!,
                      style: _T.body,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: _selectDate,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 14, color: _T.textMuted),
                      const SizedBox(width: 6),
                      Text(_fmtDate(_selectedDate),
                          style: const TextStyle(
                              fontSize: 13,
                              color: _T.accent,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(width: 4),
                      const Icon(Icons.edit_outlined,
                          size: 12, color: _T.textMuted),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_pendingIssues.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: _T.warning.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.flag, size: 12, color: _T.warning),
                const SizedBox(width: 4),
                Text('${_pendingIssues.length}',
                    style: TextStyle(
                        fontSize: 11,
                        color: _T.warning,
                        fontWeight: FontWeight.w700)),
              ]),
            ),
        ],
      ),
    );
  }

  // ── Determinants ──────────────────────────────────────────────────────────

  Widget _buildDeterminants(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 16),
      decoration: _T.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(Icons.tune_outlined, 'المحددات'),
          const SizedBox(height: 12),
          ..._selectedChecklist!.determinants.asMap().entries.map((e) {
            final det = e.value;
            final isLast =
                e.key == _selectedChecklist!.determinants.length - 1;
            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(det.name, style: _T.labelMd),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _determinantValues[det.id]?.isEmpty == true
                        ? null
                        : _determinantValues[det.id],
                    onChanged: (v) {
                      setState(
                          () => _determinantValues[det.id] = v ?? '');
                      _saveSession();
                    },
                    style:
                        const TextStyle(fontSize: 13, color: _T.text),
                    decoration: _inputDec(hint: 'اختر ${det.name}'),
                    items: det.options
                        .map((o) => DropdownMenuItem(
                            value: o.value,
                            child: Text(o.value,
                                style: const TextStyle(fontSize: 13))))
                        .toList(),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  // ── Checkpoints ───────────────────────────────────────────────────────────

  Widget _buildCheckPoints(bool isMobile) {
    return Container(
      decoration: _T.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(isMobile ? 14 : 16),
            child: Row(
              children: [
                const Icon(Icons.checklist_outlined,
                    size: 16, color: _T.accent),
                const SizedBox(width: 8),
                Text('نقاط الفحص', style: _T.title),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: _T.accentLight,
                      borderRadius: BorderRadius.circular(20)),
                  child: Text('من ${_selectedChecklist!.rateNumber}',
                      style: const TextStyle(
                          fontSize: 11,
                          color: _T.accent,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _T.border),
          ..._selectedChecklist!.checkPoints.asMap().entries.map((e) {
            final idx = e.key;
            final cp = e.value;
            final isLast =
                idx == _selectedChecklist!.checkPoints.length - 1;
            return RepaintBoundary(
              child: Column(
                children: [
                  _buildCheckpointRow(cp, isMobile),
                  if (!isLast) const Divider(height: 1, color: _T.border),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildCheckpointRow(CheckPoint cp, bool isMobile) {
    final rating = _checkPointRatings[cp.id]!;
    final decimal = _decimalRatings[cp.id] ?? rating.rating.toDouble();
    final max = _selectedChecklist!.rateNumber.toDouble();
    final label = _selectedChecklist!.getRatingLabel(rating.rating);
    final hasPending = _pendingIssues.any((i) => i.checkPointId == cp.id);
    final cpImages = _checkpointImages[cp.id] ?? [];
    final isPicking = _isPickingCheckpointImages[cp.id] ?? false;
    final showNotes = _showNotesFields[cp.id] ?? false;
    final showCorrective = _showCorrectiveFields[cp.id] ?? false;

    // FIX: Determine if issue reporting chip should appear disabled
    final canReportIssue = _areDeterminantsFilled();

    Color ratingColor;
    if (decimal >= max * 0.8)
      ratingColor = _T.success;
    else if (decimal >= max * 0.5)
      ratingColor = _T.warning;
    else
      ratingColor = _T.danger;

    return Padding(
      padding: EdgeInsets.all(isMobile ? 14 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(cp.title, style: _T.labelMd)),
              if (hasPending) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                      color: _T.warning.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20)),
                  child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.flag, size: 11, color: _T.warning),
                        const SizedBox(width: 3),
                        Text('مشكلة',
                            style: TextStyle(
                                fontSize: 10,
                                color: _T.warning,
                                fontWeight: FontWeight.w600)),
                      ]),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),

          // Rating row
          Row(
            children: [
              // Score badge
              Container(
                width: 52,
                height: 36,
                decoration: BoxDecoration(
                    color: ratingColor.withOpacity(0.1),
                    borderRadius:
                        BorderRadius.circular(_T.radiusSm),
                    border: Border.all(
                        color: ratingColor.withOpacity(0.3))),
                child: Center(
                  child: Text(_fmt(decimal),
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: ratingColor)),
                ),
              ),
              const SizedBox(width: 8),

              // Text input
              SizedBox(
                width: 72,
                child: TextFormField(
                  controller: _ratingControllers[cp.id],
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  textAlign: TextAlign.center,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d*'))
                  ],
                  onChanged: (v) => _updateRatingFromText(cp.id, v),
                  onEditingComplete: () {
                    final cur = _decimalRatings[cp.id] ?? 0.0;
                    _ratingControllers[cp.id]?.text = _fmt(cur);
                  },
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _T.text),
                  decoration: _inputDec(
                          hint: '',
                          suffix:
                              '/${_selectedChecklist!.rateNumber}')
                      .copyWith(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Slider
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: ratingColor,
                    inactiveTrackColor: _T.border,
                    thumbColor: ratingColor,
                    overlayColor: ratingColor.withOpacity(0.15),
                    thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 9),
                    overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 16),
                    trackHeight: 3,
                    showValueIndicator:
                        ShowValueIndicator.always,
                    valueIndicatorTextStyle: const TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w700),
                  ),
                  child: Slider(
                    value: decimal.clamp(0.0, max),
                    min: 0,
                    max: max,
                    divisions: _selectedChecklist!.rateNumber * 10,
                    label: _fmt(decimal),
                    onChanged: (v) => _updateRating(cp.id, v),
                  ),
                ),
              ),
            ],
          ),

          // Rating label
          if (label.isNotEmpty && label != rating.rating.toString()) ...[
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: ratingColor,
                    fontWeight: FontWeight.w600)),
          ],

          const SizedBox(height: 10),

          // Action chips
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _chip(Icons.sticky_note_2_outlined, 'ملاحظات',
                  showNotes, () => _toggleNotes(cp.id)),
              _chip(Icons.build_outlined, 'إجراء تصحيحي',
                  showCorrective, () => _toggleCorrective(cp.id)),
              // FIX: issue chip is visually dimmed and shows tooltip when determinants not filled
              _issueChip(cp.id, cp.title, canReportIssue),
              _chip(
                isPicking
                    ? Icons.hourglass_empty
                    : Icons.add_a_photo_outlined,
                cpImages.isEmpty
                    ? 'صور'
                    : 'صور (${cpImages.length})',
                cpImages.isNotEmpty,
                isPicking
                    ? null
                    : () => _pickCheckpointImages(cp.id),
                color: _T.success,
              ),
            ],
          ),

          // Notes field
          if (showNotes) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _notesControllers[cp.id],
              onChanged: (_) => _debouncedSave(),
              maxLines: 3,
              style: const TextStyle(fontSize: 13),
              decoration:
                  _inputDec(hint: 'أدخل ملاحظاتك...', label: 'ملاحظات'),
            ),
          ],

          // Corrective field
          if (showCorrective) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _correctiveControllers[cp.id],
              onChanged: (_) => _debouncedSave(),
              maxLines: 3,
              style: const TextStyle(fontSize: 13),
              decoration: _inputDec(
                  hint: 'الإجراء التصحيحي المطلوب...',
                  label: 'الإجراء التصحيحي'),
            ),
          ],

          // Checkpoint images preview
          if (cpImages.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 56,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: cpImages.length,
                itemBuilder: (_, i) => FutureBuilder<Uint8List>(
                  future: cpImages[i].readAsBytes(),
                  builder: (_, snap) => Stack(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        margin: const EdgeInsets.only(left: 6),
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                                _T.radiusSm),
                            border:
                                Border.all(color: _T.border)),
                        child: ClipRRect(
                          borderRadius:
                              BorderRadius.circular(_T.radiusSm),
                          child: snap.hasData
                              ? Image.memory(snap.data!,
                                  fit: BoxFit.cover)
                              : Container(color: _T.bg),
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () =>
                              _removeCheckpointImage(cp.id, i),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                                color: _T.danger,
                                shape: BoxShape.circle),
                            child: const Icon(Icons.close,
                                size: 9, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // FIX: Dedicated issue chip that shows lock icon when determinants not filled
  Widget _issueChip(String cpId, String cpTitle, bool canReport) {
    return Tooltip(
      message: canReport ? '' : 'يرجى تعبئة جميع المحددات أولاً',
      child: InkWell(
        onTap: () => _showIssueDialog(cpId, cpTitle),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: canReport ? _T.bg : _T.bg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _T.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                canReport ? Icons.flag_outlined : Icons.lock_outline,
                size: 13,
                color: canReport ? _T.danger : _T.textMuted,
              ),
              const SizedBox(width: 5),
              Text(
                'إبلاغ عن مشكلة',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: canReport ? _T.danger : _T.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── General images ────────────────────────────────────────────────────────

  Widget _buildGeneralImages(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 16),
      decoration: _T.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _sectionTitle(Icons.photo_library_outlined, 'صور عامة'),
              const Spacer(),
              if (_isPickingImages)
                const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 1.5, color: _T.accent))
              else if (_selectedImages.isNotEmpty)
                GestureDetector(
                  onTap: () =>
                      setState(() => _selectedImages.clear()),
                  child: Text('مسح الكل',
                      style: const TextStyle(
                          fontSize: 11,
                          color: _T.danger,
                          fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed:
                _isPickingImages ? null : _pickGeneralImages,
            icon: const Icon(Icons.add_photo_alternate_outlined,
                size: 16),
            label: Text(
                _selectedImages.isEmpty
                    ? 'إضافة صور للنموذج'
                    : 'إضافة المزيد (${_selectedImages.length})',
                style: const TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              foregroundColor: _T.accent,
              side: const BorderSide(color: _T.border),
              shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(_T.radiusSm)),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
            ),
          ),
          if (_selectedImages.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 72,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedImages.length,
                itemBuilder: (_, i) => FutureBuilder<Uint8List>(
                  future: _selectedImages[i].readAsBytes(),
                  builder: (_, snap) => Stack(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        margin:
                            const EdgeInsets.only(left: 8),
                        decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(_T.radiusSm),
                            border:
                                Border.all(color: _T.border)),
                        child: ClipRRect(
                          borderRadius:
                              BorderRadius.circular(_T.radiusSm),
                          child: snap.hasData
                              ? Image.memory(snap.data!,
                                  fit: BoxFit.cover)
                              : Container(color: _T.bg),
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () => _removeGeneralImage(i),
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                                color: _T.danger,
                                shape: BoxShape.circle),
                            child: const Icon(Icons.close,
                                size: 10, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Main notes ────────────────────────────────────────────────────────────

  Widget _buildMainNotes(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 16),
      decoration: _T.card(border: Colors.blue.shade100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _sectionTitle(Icons.sticky_note_2_outlined, 'ملاحظات عامة',
                  color: Colors.blue.shade700),
              const Spacer(),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _mainNotesController,
                builder: (_, val, __) => val.text.isEmpty
                    ? const SizedBox.shrink()
                    : Text('${val.text.length} حرف',
                        style: const TextStyle(
                            fontSize: 11,
                            color: Colors.blue,
                            fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _mainNotesController,
            maxLines: 4,
            onChanged: (_) => _debouncedSave(),
            style: const TextStyle(fontSize: 13, height: 1.5),
            decoration: InputDecoration(
              hintText: 'أي ملاحظات تتعلق بهذا التقييم...',
              hintStyle: const TextStyle(
                  color: _T.textMuted, fontSize: 13),
              filled: true,
              fillColor:
                  Colors.blue.shade50.withOpacity(0.25),
              border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(_T.radiusSm),
                  borderSide:
                      BorderSide(color: Colors.blue.shade200)),
              enabledBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(_T.radiusSm),
                  borderSide:
                      BorderSide(color: Colors.blue.shade200)),
              focusedBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(_T.radiusSm),
                  borderSide: BorderSide(
                      color: Colors.blue.shade400, width: 1.5)),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }

  // ── Submit button ─────────────────────────────────────────────────────────

  Widget _buildSubmitButton(bool isMobile) {
    if (_isReadOnly) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded, size: 18),
          label: const Text('إغلاق',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          style: OutlinedButton.styleFrom(
            foregroundColor: _T.textSub,
            side: BorderSide(color: _T.border),
            padding: EdgeInsets.symmetric(vertical: isMobile ? 14 : 15),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_T.radius)),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: _isSubmitting ? null : _submitForm,
        style: FilledButton.styleFrom(
          backgroundColor: _T.accent,
          disabledBackgroundColor: _T.accent.withOpacity(0.5),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_T.radius)),
          padding: EdgeInsets.symmetric(
              vertical: isMobile ? 14 : 15),
        ),
        child: _isSubmitting
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white)),
                  const SizedBox(width: 10),
                  Text(_isEditMode ? 'جارٍ الحفظ...' : 'جارٍ الإرسال...',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                ],
              )
            : Text(_isEditMode ? 'حفظ التعديلات' : 'إرسال النموذج',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600)),
      ),
    );
  }

  // ── Shared helpers ────────────────────────────────────────────────────────

  Widget _sectionTitle(IconData icon, String label,
          {Color? color}) =>
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color ?? _T.accent),
          const SizedBox(width: 6),
          Text(label,
              style: color != null
                  ? _T.title.copyWith(color: color)
                  : _T.title),
        ],
      );

  Widget _chip(IconData icon, String label, bool active,
      VoidCallback? onTap,
      {Color? color}) {
    final c = color ?? _T.accent;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? c.withOpacity(0.1) : _T.bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active ? c.withOpacity(0.4) : _T.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 13,
                color: active ? c : _T.textMuted),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: active ? c : _T.textMuted)),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDec(
          {String? hint, String? label, String? suffix}) =>
      InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
            fontSize: 12, color: _T.textMuted),
        hintText: hint,
        hintStyle:
            const TextStyle(fontSize: 13, color: _T.textMuted),
        suffixText: suffix,
        suffixStyle:
            const TextStyle(fontSize: 11, color: _T.textMuted),
        filled: true,
        fillColor: _T.bg,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_T.radiusSm),
            borderSide: const BorderSide(color: _T.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_T.radiusSm),
            borderSide: const BorderSide(color: _T.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_T.radiusSm),
            borderSide:
                const BorderSide(color: _T.accent, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 10),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom Arabic Date Picker
// ─────────────────────────────────────────────────────────────────────────────
class CustomArabicDatePicker extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  const CustomArabicDatePicker({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<CustomArabicDatePicker> createState() =>
      _CustomArabicDatePickerState();
}

class _CustomArabicDatePickerState
    extends State<CustomArabicDatePicker> {
  late DateTime _selectedDate;
  late PageController _pageController;

  final _months = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
  ];
  final _daysShort = ['ج', 'س', 'أ', 'ا', 'خ', 'ث', 'ن'];

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _pageController = PageController(
      initialPage: _selectedDate.month -
          1 +
          (_selectedDate.year - widget.firstDate.year) * 12,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Dialog(
        backgroundColor: _T.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_T.radiusLg)),
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                IconButton(
                    icon: const Icon(Icons.chevron_right,
                        color: _T.accent),
                    onPressed: () => _pageController.previousPage(
                        duration:
                            const Duration(milliseconds: 250),
                        curve: Curves.easeInOut)),
                Expanded(
                    child: Text(
                        '${_months[_selectedDate.month - 1]} ${_selectedDate.year}',
                        textAlign: TextAlign.center,
                        style: _T.title)),
                IconButton(
                    icon: const Icon(Icons.chevron_left,
                        color: _T.accent),
                    onPressed: () => _pageController.nextPage(
                        duration:
                            const Duration(milliseconds: 250),
                        curve: Curves.easeInOut)),
              ]),
              const SizedBox(height: 8),
              Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceEvenly,
                  children: _daysShort
                      .map((d) => SizedBox(
                          width: 30,
                          height: 30,
                          child: Center(
                              child: Text(d, style: _T.labelSm))))
                      .toList()),
              const SizedBox(height: 4),
              SizedBox(
                height: 200,
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (idx) {
                    final y =
                        widget.firstDate.year + (idx ~/ 12);
                    final m = (idx % 12) + 1;
                    setState(() {
                      final last =
                          DateTime(y, m + 1, 0).day;
                      _selectedDate = DateTime(y, m,
                          _selectedDate.day.clamp(1, last));
                    });
                  },
                  itemBuilder: (_, idx) {
                    final y =
                        widget.firstDate.year + (idx ~/ 12);
                    final m = (idx % 12) + 1;
                    return _monthView(y, m);
                  },
                ),
              ),
              const SizedBox(height: 12),
              Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                        onPressed: () =>
                            Navigator.of(context).pop(),
                        child: const Text('إلغاء',
                            style: TextStyle(
                                color: _T.textMuted))),
                    const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: _T.accent,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(
                                      _T.radiusSm))),
                      onPressed: () => Navigator.of(context)
                          .pop(_selectedDate),
                      child: const Text('تأكيد',
                          style: TextStyle(fontSize: 13)),
                    ),
                  ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _monthView(int year, int month) {
    final first = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final startOffset = (first.weekday + 1) % 7;
    final widgets = <Widget>[
      ...List.generate(startOffset,
          (_) => const SizedBox(width: 30, height: 30)),
      ...List.generate(daysInMonth, (i) {
        final day = i + 1;
        final date = DateTime(year, month, day);
        final isSel = date.day == _selectedDate.day &&
            date.month == _selectedDate.month &&
            date.year == _selectedDate.year;
        final isToday = DateTime.now().day == day &&
            DateTime.now().month == month &&
            DateTime.now().year == year;
        final enabled = !date.isBefore(widget.firstDate) &&
            !date.isAfter(widget.lastDate);
        return GestureDetector(
          onTap: enabled
              ? () => setState(() => _selectedDate = date)
              : null,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: isSel ? _T.accent : Colors.transparent,
              shape: BoxShape.circle,
              border: isToday && !isSel
                  ? Border.all(color: _T.accent)
                  : null,
            ),
            child: Center(
                child: Text('$day',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSel || isToday
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: isSel
                          ? Colors.white
                          : (enabled ? _T.text : _T.textMuted),
                    ))),
          ),
        );
      }),
    ];
    while (widgets.length % 7 != 0)
      widgets.add(const SizedBox(width: 30, height: 30));
    return GridView.count(
        crossAxisCount: 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: widgets);
  }
}