// lib/screens/web/quality_checklist_builder_screen.dart
import 'package:flutter/material.dart';
import 'package:jala_as/models/quality_models.dart';
import 'package:jala_as/models/user.dart';
import '../../../../services/supabase_service.dart';
import '../../../../utils/constants.dart';
import '../../../../utils/helpers.dart';
import 'dart:ui' as ui;
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────
//  Design tokens
// ─────────────────────────────────────────────────────────────
const _kAccent       = Color(0xFF7C3AED);
const _kAccentLight  = Color(0xFFF5F3FF);
const _kSuccess      = Color(0xFF059669);
const _kSuccessLight = Color(0xFFD1FAE5);
const _kDanger       = Color(0xFFDC2626);
const _kWarning      = Color(0xFFD97706);
const _kRadius       = 10.0;
const _kRadiusSm     =  6.0;
const _kRadiusLg     = 14.0;

const _kStepColors = [
  Color(0xFF7C3AED),
  Color(0xFF2563EB),
  Color(0xFF0891B2),
  Color(0xFF059669),
  Color(0xFFD97706),
  Color(0xFFDC2626),
];

BoxDecoration _kCard({bool shadow = true, Color? border}) => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(_kRadiusLg),
  border: Border.all(color: border ?? Colors.grey.shade200),
  boxShadow: shadow
      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))]
      : null,
);

// ─────────────────────────────────────────────────────────────
//  Spotlight Tutorial System
// ─────────────────────────────────────────────────────────────

class SpotlightStep {
  final GlobalKey targetKey;
  final String title;
  final String body;
  final IconData icon;
  final SpotlightPosition position;

  const SpotlightStep({
    required this.targetKey,
    required this.title,
    required this.body,
    required this.icon,
    this.position = SpotlightPosition.bottom,
  });
}

enum SpotlightPosition { top, bottom, left, right, center }

class SpotlightOverlay extends StatefulWidget {
  final List<SpotlightStep> steps;
  final VoidCallback onComplete;
  final VoidCallback onSkip;
  final Color accentColor;

  const SpotlightOverlay({
    super.key,
    required this.steps,
    required this.onComplete,
    required this.onSkip,
    required this.accentColor,
  });

  @override
  State<SpotlightOverlay> createState() => _SpotlightOverlayState();
}

class _SpotlightOverlayState extends State<SpotlightOverlay>
    with SingleTickerProviderStateMixin {
  int _current = 0;
  late AnimationController _ctrl;
  late Animation<double> _fade;
  Rect? _targetRect;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureTarget());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _measureTarget() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final step = widget.steps[_current];
      final ctx = step.targetKey.currentContext;
      if (ctx == null) return;

      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;

      // Use global coordinates — the overlay is placed with Positioned.fill
      // inside the root-level Stack that covers the entire screen (including
      // the AppBar area), so global coords are correct here.
      final pos = box.localToGlobal(Offset.zero);
      if (!mounted) return;
      setState(() {
        _targetRect = Rect.fromLTWH(pos.dx, pos.dy, box.size.width, box.size.height);
      });
    });
  }

  void _next() {
    if (_current < widget.steps.length - 1) {
      _ctrl.reset();
      setState(() => _current++);
      _ctrl.forward();
      _measureTarget();
    } else {
      widget.onComplete();
    }
  }

  void _prev() {
    if (_current > 0) {
      _ctrl.reset();
      setState(() => _current--);
      _ctrl.forward();
      _measureTarget();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final step = widget.steps[_current];
    final rect = _targetRect;
    final c = widget.accentColor;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: FadeTransition(
        opacity: _fade,
        child: Stack(
          children: [
            // Dark overlay with hole
            if (rect != null)
              CustomPaint(
                size: size,
                painter: _SpotlightPainter(rect: rect, padding: 10),
              )
            else
              Container(color: Colors.black.withValues(alpha: 0.65)),

            // Tooltip card
            if (rect != null)
              _buildTooltip(size, rect, step, c)
            else
              Center(child: _buildCard(step, c)),

            // Top bar — step counter only
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_current + 1} / ${widget.steps.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),

            // Step dots
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 12,
              left: 0, right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.steps.length, (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _current ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _current ? c : Colors.white38,
                    borderRadius: BorderRadius.circular(4),
                  ),
                )),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTooltip(Size size, Rect rect, SpotlightStep step, Color c) {
    const padding = 12.0;
    final expandedRect = rect.inflate(padding);
    final cardWidth = (size.width * 0.82).clamp(280.0, 420.0);
    const cardHeightEstimate = 180.0;
    const minSpace = 24.0;

    // ── Vertical placement ────────────────────────────────────────
    double top;
    bool arrowBelow = false;

    // Prefer showing BELOW the target
    if (expandedRect.bottom + cardHeightEstimate + 48 < size.height - minSpace) {
      top = expandedRect.bottom + 12;
      arrowBelow = false;
    }
    // Otherwise try ABOVE
    else if (expandedRect.top - cardHeightEstimate - 48 > minSpace) {
      top = expandedRect.top - cardHeightEstimate - 12;
      arrowBelow = true;
    }
    // Fallback: center screen
    else {
      top = (size.height - cardHeightEstimate) / 2;
      arrowBelow = false;
    }

    // ── Horizontal centering ─────────────────────────────────────
    double left = (size.width - cardWidth) / 2;

    // Arrow tries to point to center of target
    double arrowCenterX = rect.center.dx;
    arrowCenterX = arrowCenterX.clamp(left + 24, left + cardWidth - 24);

    return Positioned(
      top: top,
      left: left,
      width: cardWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!arrowBelow)
            _Arrow(centerX: arrowCenterX - left, color: c, pointDown: false),
          Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(_kRadiusLg),
            child: _buildCard(step, c),
          ),
          if (arrowBelow)
            _Arrow(centerX: arrowCenterX - left, color: c, pointDown: true),
        ],
      ),
    );
  }

  Widget _buildCard(SpotlightStep step, Color c) {
    final isLast = _current == widget.steps.length - 1;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_kRadiusLg),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Card header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              color: c,
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(_kRadiusLg), topRight: Radius.circular(_kRadiusLg)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                  child: Icon(step.icon, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(step.title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(step.body, style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.55)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    if (_current > 0)
                      OutlinedButton(
                        onPressed: _prev,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: c,
                          side: BorderSide(color: c.withValues(alpha: 0.3)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_kRadiusSm)),
                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        child: const Text('السابق'),
                      ),
                    // Skip button always visible
                    TextButton(
                      onPressed: widget.onSkip,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey.shade500,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                      child: const Text('تخطي'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: _next,
                      style: FilledButton.styleFrom(
                        backgroundColor: c,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_kRadiusSm)),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      child: Text(isLast ? 'فهمت، لنبدأ!' : 'التالي'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  final double centerX;
  final Color color;
  final bool pointDown;

  const _Arrow({required this.centerX, required this.color, required this.pointDown});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 12,
      child: CustomPaint(
        painter: _ArrowPainter(centerX: centerX, color: color, pointDown: pointDown),
        size: Size.infinite,
      ),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  final double centerX;
  final Color color;
  final bool pointDown;

  _ArrowPainter({required this.centerX, required this.color, required this.pointDown});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    const w = 14.0;
    const h = 12.0;

    if (!pointDown) {
      path.moveTo(centerX - w, size.height);
      path.lineTo(centerX, 0);
      path.lineTo(centerX + w, size.height);
    } else {
      path.moveTo(centerX - w, 0);
      path.lineTo(centerX, size.height);
      path.lineTo(centerX + w, 0);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ArrowPainter old) => old.centerX != centerX || old.color != color;
}

class _SpotlightPainter extends CustomPainter {
  final Rect rect;
  final double padding;

  _SpotlightPainter({required this.rect, required this.padding});

  @override
  void paint(Canvas canvas, Size size) {
    final fullRect = Offset.zero & size;
    final spotRect = rect.inflate(padding);
    final rrect = RRect.fromRectAndRadius(spotRect, const Radius.circular(10));

    final path = Path()
      ..addRect(fullRect)
      ..addRRect(rrect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, Paint()..color = Colors.black.withValues(alpha: 0.65));

    // Glowing border on spotlight
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) => old.rect != rect;
}

// ─────────────────────────────────────────────────────────────
//  Step definitions
// ─────────────────────────────────────────────────────────────
class _Step {
  final String title;
  final IconData icon;
  const _Step(this.title, this.icon);
}

const _kSteps = [
  _Step('المعلومات الأساسية', Icons.info_outline_rounded),
  _Step('نوع القائمة',        Icons.layers_outlined),
  _Step('معايير التقييم',     Icons.star_outline_rounded),
  _Step('المحددات',           Icons.tune_outlined),
  _Step('نقاط الفحص',        Icons.checklist_outlined),
  _Step('تعيين المستخدمين',  Icons.people_alt_outlined),
];

// ─────────────────────────────────────────────────────────────
//  Preview: Groups Screen state
// ─────────────────────────────────────────────────────────────
enum _PreviewScreen { groups, form }

// ─────────────────────────────────────────────────────────────
//  Main widget
// ─────────────────────────────────────────────────────────────
class QualityChecklistBuilderScreen extends StatefulWidget {
  final QualityChecklistGroup? checklistGroup;
  const QualityChecklistBuilderScreen({super.key, this.checklistGroup});

  @override
  State<QualityChecklistBuilderScreen> createState() => _State();
}

class _State extends State<QualityChecklistBuilderScreen> with TickerProviderStateMixin {
  // ── Wizard ────────────────────────────────────────────────
  int _step = 0;
  late final PageController _pageCtrl;
  late final AnimationController _entryCtrl;
  late final Animation<double> _entryFade;

  // ── Spotlight Tutorial ────────────────────────────────────
  bool _showSpotlight = false;
  bool _tutorialDisabled = false;
  static const _kTutorialPrefKey = 'quality_builder_tutorial_disabled';

  // ── Live preview pane ─────────────────────────────────────
  bool _showPreview = false;
  _PreviewScreen _previewScreen = _PreviewScreen.groups;
  int _previewSelectedChecklistIndex = 0;

  // ── Form ──────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl  = TextEditingController();
  bool _isMultiple = false;
  DeterminantBuilder? _selectorDet;
  List<ChecklistBuilder> _checklists = [];
  bool _isSaving = false;

  // ── Users ─────────────────────────────────────────────────
  List<AppUser> _allUsers = [];
  List<String> _selectedUserIds = [];
  Map<String, bool> _userEditPermissions = {};
  bool _loadingUsers = false;

  // ── GlobalKeys for spotlight targets (step 0) ─────────────
  final _keyTitleField     = GlobalKey();
  final _keyDescField      = GlobalKey();
  final _keyModeChip       = GlobalKey();
  // step 1
  final _keySingleCard     = GlobalKey();
  final _keyMultiCard      = GlobalKey();
  final _keySelectorName   = GlobalKey();
  // step 2
  final _keyRateField      = GlobalKey();
  final _keyScaleRows      = GlobalKey();
  // step 3
  final _keyDetSection     = GlobalKey();
  // step 4
  final _keyCpSection      = GlobalKey();
  // step 5
  final _keyUsersSection   = GlobalKey();

  Color get _sc => _kStepColors[_step];

  List<SpotlightStep> get _spotlightSteps {
    switch (_step) {
      case 0:
        return [
          SpotlightStep(targetKey: _keyTitleField, icon: Icons.title_rounded,
              title: 'اسم القائمة أو المجموعة',
              body: 'هذا الاسم يظهر كعنوان رئيسي في شاشة التطبيق أمام مراقب الجودة. اختر اسماً واضحاً ومعبّراً.'),
          SpotlightStep(targetKey: _keyDescField, icon: Icons.notes_rounded,
              title: 'الوصف (اختياري)',
              body: 'نص يظهر تحت الاسم بلون رمادي. استخدمه لتوضيح هدف هذه القائمة أو الفريق المعني بها.'),
          SpotlightStep(targetKey: _keyModeChip, icon: Icons.info_outline_rounded,
              title: 'نوع القائمة الحالي',
              body: 'يمكنك تغيير نوع القائمة في الخطوة التالية. القائمة المفردة للعمليات الواحدة، والمتعددة لعدة أنواع تقييم.'),
        ];
      case 1:
        return [
          SpotlightStep(targetKey: _keySingleCard, icon: Icons.article_outlined,
              title: 'القائمة المفردة',
              body: 'تقييم واحد مباشر. المراقب يبدأ التقييم فور فتح النموذج دون أي اختيار مسبق. مناسب للعمليات الموحّدة.'),
          SpotlightStep(targetKey: _keyMultiCard, icon: Icons.layers_outlined,
              title: 'القوائم المتعددة',
              body: 'أكثر من قائمة تحت مجموعة. المراقب يختار من قائمة منسدلة أي نوع يريد تقييمه مثلاً وردية الصباح أو وردية المساء.'),
        ];
      case 2:
        return [
          SpotlightStep(targetKey: _keyRateField, icon: Icons.star_outline_rounded,
              title: 'أقصى رقم تقييم',
              body: 'حدد الحد الأعلى للتقييم. مثلاً إذا اخترت 5 سيظهر للمراقب شريط تمرير وحقل إدخال من 0 إلى 5 لكل نقطة فحص.'),
          SpotlightStep(targetKey: _keyScaleRows, icon: Icons.format_list_numbered,
              title: 'معايير التقييم',
              body: 'كل صف يمثل نطاقاً من الأرقام مع تسمية توضيحية. مثال: 5 = ممتاز جداً، 3 = جيد، 0 = ضعيف جداً.'),
        ];
      case 3:
        return [
          SpotlightStep(targetKey: _keyDetSection, icon: Icons.tune_outlined,
              title: 'ما هي المحددات؟',
              body: 'هي قوائم منسدلة يختار منها المراقب قيمة قبل بدء التقييم مثل رقم الشاحنة أو الوردية. القيمة المختارة تُحفظ مع التقرير وهي إلزامية.'),
        ];
      case 4:
        return [
          SpotlightStep(targetKey: _keyCpSection, icon: Icons.checklist_outlined,
              title: 'نقاط الفحص',
              body: 'هي العناصر الفعلية التي يقيّمها المراقب بالأرقام. مثال: نظافة منطقة العمل أو التزام العمال بالسلامة. اجعل كل نقطة دقيقة وواضحة.'),
        ];
      case 5:
        return [
          SpotlightStep(targetKey: _keyUsersSection, icon: Icons.people_alt_outlined,
              title: 'تعيين مراقبي الجودة',
              body: 'فقط المستخدمون المُعيَّنون هنا سيرون هذه المجموعة في تطبيقهم. انقر على بطاقة المستخدم لتحديده أو إلغاء تحديده.'),
        ];
      default:
        return [];
    }
  }

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    _entryCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _entryFade = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _entryCtrl.forward();
    _titleCtrl.addListener(() => setState(() {}));
    _descCtrl.addListener(()  => setState(() {}));
    _initForm();
    _loadUsers();
    _loadTutorialPref();
  }

  Future<void> _loadTutorialPref() async {
    final prefs = await SharedPreferences.getInstance();
    final disabled = prefs.getBool(_kTutorialPrefKey) ?? false;
    if (!mounted) return;
    setState(() => _tutorialDisabled = disabled);
    if (!disabled) {
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) setState(() => _showSpotlight = true);
      });
    }
  }

  Future<void> _disableTutorialForever() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kTutorialPrefKey, true);
    if (mounted) {
      setState(() {
        _tutorialDisabled = true;
        _showSpotlight = false;
      });
    }
  }

  Future<void> _resetTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kTutorialPrefKey, false);
    if (mounted) {
      setState(() {
        _tutorialDisabled = false;
        _showSpotlight = true;
      });
    }
  }

  void _showSkipTutorialDialog() {
    setState(() => _showSpotlight = false);
    showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تخطي الشرح'),
          content: const Text(
              'هل تريد إيقاف الشرح التفاعلي نهائياً؟\nيمكنك إعادة تشغيله في أي وقت عبر زر "شاهد الشرح".'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('لا، فقط أغلق الآن'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: _kAccent),
              child: const Text('نعم، لا تُظهره مجدداً'),
            ),
          ],
        ),
      ),
    ).then((disable) {
      if (disable == true) _disableTutorialForever();
    });
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _entryCtrl.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _selectorDet?.dispose();
    for (final c in _checklists) c.dispose();
    super.dispose();
  }

  // ── Navigation ────────────────────────────────────────────
  void _goto(int s) {
    if (s < 0 || s >= _kSteps.length) return;
    setState(() {
      _step = s;
      _showSpotlight = false;
    });
    _pageCtrl.animateToPage(s, duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    _entryCtrl.reset();
    _entryCtrl.forward();
    if (!_tutorialDisabled) {
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) setState(() => _showSpotlight = true);
      });
    }
  }

  void _next() { if (_validateStep()) _goto(_step + 1); }
  void _prev() => _goto(_step - 1);

  // ── Init form ─────────────────────────────────────────────
  void _initForm() {
    if (widget.checklistGroup != null) {
      final g = widget.checklistGroup!;
      _titleCtrl.text = g.title;
      _descCtrl.text  = g.description ?? '';
      _isMultiple     = g.isMultipleActive;
      if (g.selectorDeterminant != null) {
        _selectorDet = DeterminantBuilder(
          id: g.selectorDeterminant!.id,
          nameCtrl: TextEditingController(text: g.selectorDeterminant!.name),
          options: g.selectorDeterminant!.options
              .map((o) => DetOptBuilder(id: o.id, valueCtrl: TextEditingController(text: o.value)))
              .toList(),
        );
      }
      _checklists = g.checklists.map((cl) => ChecklistBuilder(
        id: cl.id.toString(),
        titleCtrl: TextEditingController(text: cl.title),
        descCtrl:  TextEditingController(text: cl.description ?? ''),
        rateCtrl:  TextEditingController(text: cl.rateNumber.toString()),
        selectorOptionValue: cl.selectorOptionValue,
        determinants: cl.determinants.map((d) => DeterminantBuilder(
          id: d.id,
          nameCtrl: TextEditingController(text: d.name),
          options: d.options.map((o) => DetOptBuilder(id: o.id, valueCtrl: TextEditingController(text: o.value))).toList(),
        )).toList(),
        scales: cl.ratingScale.map((s) => ScaleBuilder(
          id: const Uuid().v4(),
          minCtrl:   TextEditingController(text: s.minValue?.toString() ?? ''),
          maxCtrl:   TextEditingController(text: s.maxValue?.toString() ?? ''),
          labelCtrl: TextEditingController(text: s.label),
        )).toList(),
        checkPoints: cl.checkPoints.map((cp) => CPBuilder(id: cp.id, titleCtrl: TextEditingController(text: cp.title))).toList(),
      )).toList();
    } else {
      _addFirstChecklist();
    }
  }

  Future<void> _loadUsers() async {
    setState(() => _loadingUsers = true);
    try {
      final users = await SupabaseService.getQualityControllerUsers();
      List<String> assigned = [];
      Map<String, bool> editPerms = {};
      if (widget.checklistGroup != null) {
        final map = await SupabaseService.getGroupAssignedUserIds(widget.checklistGroup!.id);
        assigned = map.keys.toList();
        editPerms = map;
      }
      if (!mounted) return;
      setState(() {
        _allUsers = users;
        _selectedUserIds = assigned;
        _userEditPermissions = editPerms;
        _loadingUsers = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingUsers = false);
    }
  }

  // ── Checklist helpers ─────────────────────────────────────
  void _addFirstChecklist() {
    _checklists.add(ChecklistBuilder(
      id: const Uuid().v4(),
      titleCtrl: TextEditingController(),
      descCtrl:  TextEditingController(),
      rateCtrl:  TextEditingController(text: '5'),
      determinants: [], // empty by default — user adds if needed
      scales: _defaultScales(),
      checkPoints: [CPBuilder(id: const Uuid().v4(), titleCtrl: TextEditingController())],
    ));
  }

  List<ScaleBuilder> _defaultScales() => [
    _mkScale('5', 'ممتاز جداً'),
    _mkScale('4', 'ممتاز'),
    _mkScale('3', 'جيد'),
    _mkScale('2', 'مقبول'),
    _mkScale('1', 'ضعيف'),
    _mkScale('0', 'ضعيف جداً'),
  ];

  ScaleBuilder _mkScale(String min, String label) => ScaleBuilder(
    id: const Uuid().v4(),
    minCtrl:   TextEditingController(text: min),
    maxCtrl:   TextEditingController(),
    labelCtrl: TextEditingController(text: label),
  );

  void _syncTitle() {
    if (!_isMultiple && _checklists.isNotEmpty)
      _checklists.first.titleCtrl.text = _titleCtrl.text;
  }

  void _toggleMultiple(bool val) {
    setState(() {
      _isMultiple = val;
      if (val) {
        _selectorDet ??= DeterminantBuilder(
          id: const Uuid().v4(),
          nameCtrl: TextEditingController(text: 'نوع التقييم'),
          options: [DetOptBuilder(id: const Uuid().v4(), valueCtrl: TextEditingController(text: 'القائمة 1'))],
        );
        if (_checklists.isNotEmpty) {
          final v = _selectorDet!.options.first.valueCtrl.text.trim();
          _checklists.first.selectorOptionValue = v.isEmpty ? null : v;
          _checklists.first.titleCtrl.text = v.isNotEmpty ? v : 'القائمة 1';
        }
      } else {
        _selectorDet?.dispose();
        _selectorDet = null;
        for (int i = 1; i < _checklists.length; i++) _checklists[i].dispose();
        _checklists = [_checklists.first];
        _checklists.first.selectorOptionValue = null;
        _syncTitle();
      }
    });
  }

  void _addSelectorOption() {
    if (_selectorDet == null) return;
    final n = _selectorDet!.options.length + 1;
    final label = 'القائمة $n';
    setState(() {
      _selectorDet!.options.add(DetOptBuilder(id: const Uuid().v4(), valueCtrl: TextEditingController(text: label)));
      _checklists.add(ChecklistBuilder(
        id: const Uuid().v4(),
        titleCtrl: TextEditingController(text: label),
        descCtrl:  TextEditingController(),
        rateCtrl:  TextEditingController(text: '5'),
        selectorOptionValue: label,
        determinants: [], // empty by default — user adds if needed
        scales: _defaultScales(),
        checkPoints: [CPBuilder(id: const Uuid().v4(), titleCtrl: TextEditingController())],
      ));
    });
  }

  void _onSelectorOptChanged(int idx, String v) {
    if (_selectorDet == null || idx >= _checklists.length) return;
    setState(() {
      _checklists[idx].titleCtrl.text = v;
      _checklists[idx].selectorOptionValue = v;
    });
  }

  void _removeSelectorOption(int idx) {
    if (_selectorDet == null || _selectorDet!.options.length <= 1) return;
    setState(() {
      _selectorDet!.options[idx].valueCtrl.dispose();
      _selectorDet!.options.removeAt(idx);
      if (idx < _checklists.length) { _checklists[idx].dispose(); _checklists.removeAt(idx); }
    });
  }

  void _addDet(int ci) {
    setState(() {
      _checklists[ci].determinants.add(DeterminantBuilder(
        id: const Uuid().v4(),
        nameCtrl: TextEditingController(),
        options: [DetOptBuilder(id: const Uuid().v4(), valueCtrl: TextEditingController())],
      ));
    });
  }

  void _removeDet(int ci, int di) {
    setState(() { _checklists[ci].determinants[di].dispose(); _checklists[ci].determinants.removeAt(di); });
  }

  void _addDetOpt(int ci, int di) {
    setState(() {
      _checklists[ci].determinants[di].options.add(DetOptBuilder(id: const Uuid().v4(), valueCtrl: TextEditingController()));
    });
  }

  void _removeDetOpt(int ci, int di, int oi) {
    setState(() {
      _checklists[ci].determinants[di].options[oi].valueCtrl.dispose();
      _checklists[ci].determinants[di].options.removeAt(oi);
    });
  }

  void _addCP(int ci) {
    setState(() { _checklists[ci].checkPoints.add(CPBuilder(id: const Uuid().v4(), titleCtrl: TextEditingController())); });
  }

  void _removeCP(int ci, int cpi) {
    setState(() { _checklists[ci].checkPoints[cpi].titleCtrl.dispose(); _checklists[ci].checkPoints.removeAt(cpi); });
  }

  void _importCheckpoints(int targetCi, int sourceCi) {
    setState(() {
      for (final cp in _checklists[sourceCi].checkPoints) {
        _checklists[targetCi].checkPoints.add(
          CPBuilder(id: const Uuid().v4(), titleCtrl: TextEditingController(text: cp.titleCtrl.text)),
        );
      }
    });
  }

  void _showImportCheckpointsDialog(int targetCi, Color c) {
    final others = _checklists.asMap().entries.where((e) => e.key != targetCi).toList();
    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('استيراد نقاط من قائمة أخرى',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: others.map((e) {
              final ci = e.key; final cl = e.value;
              final name = cl.titleCtrl.text.isEmpty ? 'القائمة ${ci + 1}' : cl.titleCtrl.text;
              return ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 14, backgroundColor: c.withValues(alpha: 0.12),
                  child: Text('${ci + 1}', style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w700)),
                ),
                title: Text(name, style: const TextStyle(fontSize: 13)),
                subtitle: Text('${cl.checkPoints.length} نقطة فحص',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                onTap: () {
                  Navigator.pop(context);
                  _importCheckpoints(targetCi, ci);
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
          ],
        ),
      ),
    );
  }

  void _insertCPAt(int ci, int insertIdx) {
    setState(() {
      _checklists[ci].checkPoints.insert(
        insertIdx,
        CPBuilder(id: const Uuid().v4(), titleCtrl: TextEditingController()),
      );
    });
  }

  void _addScale(int ci) {
    setState(() {
      _checklists[ci].scales.add(ScaleBuilder(
        id: const Uuid().v4(),
        minCtrl:   TextEditingController(),
        maxCtrl:   TextEditingController(),
        labelCtrl: TextEditingController(),
      ));
    });
  }

  void _removeScale(int ci, int si) {
    setState(() { _checklists[ci].scales[si].dispose(); _checklists[ci].scales.removeAt(si); });
  }

  // ── Validation ────────────────────────────────────────────
  bool _validateStep() {
    switch (_step) {
      case 0:
        if (_titleCtrl.text.trim().isEmpty) { _err('يرجى إدخال اسم القائمة أو المجموعة'); return false; }
        return true;
      case 1:
        if (_isMultiple && _selectorDet != null) {
          if (_selectorDet!.nameCtrl.text.trim().isEmpty) { _err('يرجى إدخال اسم محدد الاختيار'); return false; }
          for (final o in _selectorDet!.options) {
            if (o.valueCtrl.text.trim().isEmpty) { _err('يرجى ملء جميع خيارات المحدد'); return false; }
          }
        }
        return true;
      case 2:
        for (final cl in _checklists) {
          final rn = int.tryParse(cl.rateCtrl.text);
          if (rn == null || rn < 1 || rn > 10) { _err('أقصى تقييم يجب أن يكون بين 1 و 10'); return false; }
          for (final s in cl.scales) {
            if (s.minCtrl.text.trim().isEmpty || s.labelCtrl.text.trim().isEmpty) {
              _err('يرجى ملء جميع معايير التقييم'); return false;
            }
          }
        }
        return true;
      case 3:
        for (final cl in _checklists) {
          for (final d in cl.determinants) {
            if (d.nameCtrl.text.trim().isEmpty) { _err('يرجى إدخال اسم المحدد'); return false; }
            for (final o in d.options) {
              if (o.valueCtrl.text.trim().isEmpty) { _err('يرجى ملء جميع خيارات المحدد'); return false; }
            }
          }
        }
        return true;
      case 4:
        for (int ci = 0; ci < _checklists.length; ci++) {
          for (int cpi = 0; cpi < _checklists[ci].checkPoints.length; cpi++) {
            if (_checklists[ci].checkPoints[cpi].titleCtrl.text.trim().isEmpty) {
              _err('يرجى إدخال عنوان نقطة الفحص ${cpi + 1}'); return false;
            }
          }
        }
        return true;
      default: return true;
    }
  }

  void _err(String msg) => Helpers.showSnackBar(context, msg, isError: true);

  // ── Save ──────────────────────────────────────────────────
  Future<void> _save() async {
    if (!_isMultiple && _checklists.isNotEmpty)
      _checklists.first.titleCtrl.text = _titleCtrl.text.trim();
    if (_titleCtrl.text.trim().isEmpty) { _err('يرجى إدخال اسم القائمة'); return; }
    setState(() => _isSaving = true);
    try {
      Determinant? selDet;
      if (_isMultiple && _selectorDet != null) {
        selDet = Determinant(
          id: _selectorDet!.id,
          name: _selectorDet!.nameCtrl.text.trim(),
          options: _selectorDet!.options.map((o) => DeterminantOption(id: o.id, value: o.valueCtrl.text.trim())).toList(),
        );
      }

      final checklists = _checklists.map((cb) {
        final dets   = cb.determinants.map((d) => Determinant(
          id: d.id, name: d.nameCtrl.text.trim(),
          options: d.options.map((o) => DeterminantOption(id: o.id, value: o.valueCtrl.text.trim())).toList(),
        )).toList();
        final scales = cb.scales.map((s) => RatingScale(
          minValue: int.tryParse(s.minCtrl.text.trim()),
          maxValue: s.maxCtrl.text.trim().isEmpty ? null : int.tryParse(s.maxCtrl.text.trim()),
          label:    s.labelCtrl.text.trim(),
        )).toList();
        final cps    = cb.checkPoints.map((cp) => CheckPoint(id: cp.id, title: cp.titleCtrl.text.trim())).toList();

        int clId = 0;
        if (widget.checklistGroup != null) {
          final existing = widget.checklistGroup!.checklists;
          final idx = _checklists.indexOf(cb);
          if (idx < existing.length) {
            clId = existing[idx].id;
          } else {
            final m = existing.firstWhere(
              (e) => e.title == cb.titleCtrl.text.trim(),
              orElse: () => QualityChecklist(id: 0, groupId: 0, title: '', determinants: [], rateNumber: 5,
                  ratingScale: [], checkPoints: [], isActive: true,
                  createdAt: DateTime.now(), updatedAt: DateTime.now()),
            );
            if (m.id != 0) clId = m.id;
          }
        }

        return QualityChecklist(
          id: clId, groupId: widget.checklistGroup?.id ?? 0,
          title: cb.titleCtrl.text.trim(),
          description: cb.descCtrl.text.trim().isEmpty ? null : cb.descCtrl.text.trim(),
          selectorOptionValue: cb.selectorOptionValue,
          determinants: dets, rateNumber: int.tryParse(cb.rateCtrl.text) ?? 5,
          ratingScale: scales, checkPoints: cps,
          isActive: true, createdBy: null,
          createdAt: DateTime.now(), updatedAt: DateTime.now(),
        );
      }).toList();

      int groupId;
      if (widget.checklistGroup != null) {
        await SupabaseService.updateQualityChecklistGroup(
          id: widget.checklistGroup!.id,
          title: _titleCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          isMultipleActive: _isMultiple,
          selectorDeterminant: selDet,
          checklists: checklists,
        );
        groupId = widget.checklistGroup!.id;
        if (!mounted) return;
        Helpers.showSnackBar(context, 'تم التحديث بنجاح');
      } else {
        final created = await SupabaseService.createQualityChecklistGroup(
          title: _titleCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          isMultipleActive: _isMultiple,
          selectorDeterminant: selDet,
          checklists: checklists,
        );
        groupId = created.id;
        if (!mounted) return;
        Helpers.showSnackBar(context, 'تم الإنشاء بنجاح');
      }

      if (_selectedUserIds.isNotEmpty || widget.checklistGroup != null) {
        await SupabaseService.assignUsersToQualityGroup(
          groupId: groupId,
          userIds: _selectedUserIds,
          userEditPermissions: _userEditPermissions,
        );
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) _err('فشل في الحفظ: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ─────────────────────────────────────────────────────────
  //  AppBar
  // ─────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(bool isMobile) {
    return AppBar(
      elevation: 0, scrolledUnderElevation: 0,
      backgroundColor: Colors.white, surfaceTintColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Color(AppConstants.primaryColor)),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(
          widget.checklistGroup != null ? 'تعديل مجموعة قوائم الجودة' : 'إنشاء مجموعة قوائم الجودة',
          style: TextStyle(fontSize: isMobile ? 14 : 16, fontWeight: FontWeight.w700,
              color: const Color(AppConstants.primaryColor)),
        ),
        Text('الخطوة ${_step + 1} من ${_kSteps.length} — ${_kSteps[_step].title}',
            style: TextStyle(fontSize: 11, color: _sc, fontWeight: FontWeight.w600)),
      ]),
      actions: [
        // Tutorial button — shows if tutorial is disabled (let user re-enable),
        // or shows help icon if tutorial is active
        if (_tutorialDisabled)
          TextButton.icon(
            onPressed: _resetTutorial,
            icon: Icon(Icons.help_outline_rounded, size: 15, color: _sc),
            label: Text('شاهد الشرح',
                style: TextStyle(fontSize: 11, color: _sc, fontWeight: FontWeight.w600)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
          )
        else
          IconButton(
            onPressed: () => setState(() => _showSpotlight = true),
            tooltip: 'شرح تفاعلي لهذه الخطوة',
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _sc.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(_kRadiusSm),
              ),
              child: Icon(Icons.help_outline_rounded, size: 16, color: _sc),
            ),
          ),
        const SizedBox(width: 4),
        if (_isSaving)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5, color: _kAccent)),
              const SizedBox(width: 6),
              Text('حفظ...', style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
            ]),
          )
        else
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_rounded, size: 15, color: Colors.white),
              label: const Text('حفظ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              style: FilledButton.styleFrom(
                backgroundColor: _kSuccess,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_kRadiusSm)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              ),
            ),
          ),
      ],
    );
  }

  // ── Progress bar ──────────────────────────────────────────
  Widget _buildProgressBar() {
    return Container(
      height: 3, color: Colors.grey.shade200,
      child: AnimatedFractionallySizedBox(
        duration: const Duration(milliseconds: 450), curve: Curves.easeInOut,
        widthFactor: (_step + 1) / _kSteps.length, alignment: Alignment.centerRight,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [_sc.withValues(alpha: 0.5), _sc],
                begin: Alignment.centerRight, end: Alignment.centerLeft),
          ),
        ),
      ),
    );
  }

  // ── Step tabs ─────────────────────────────────────────────
  Widget _buildStepTabs(bool isMobile) {
    return Container(
      height: 52, color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: 8),
        child: Row(
          children: List.generate(_kSteps.length, (i) {
            final s      = _kSteps[i];
            final active = i == _step;
            final done   = i < _step;
            final c      = _kStepColors[i];
            return GestureDetector(
              onTap: () => _goto(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(left: 6),
                padding: EdgeInsets.symmetric(horizontal: active ? 14 : 10, vertical: 5),
                decoration: BoxDecoration(
                  color: active ? c : done ? c.withValues(alpha: 0.08) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: active ? c : done ? c.withValues(alpha: 0.3) : Colors.grey.shade200),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 20, height: 20,
                    decoration: BoxDecoration(
                      color: active ? Colors.white.withValues(alpha: 0.25) : done ? c : Colors.grey.shade200,
                      shape: BoxShape.circle,
                    ),
                    child: Center(child: done
                        ? const Icon(Icons.check_rounded, size: 11, color: Colors.white)
                        : Text('${i + 1}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                              color: active ? Colors.white : Colors.grey.shade500))),
                  ),
                  const SizedBox(width: 6),
                  Text(s.title, style: TextStyle(
                      fontSize: 12,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active ? Colors.white : done ? c : Colors.grey.shade500)),
                ]),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ── Bottom bar ─────────────────────────────────────────────
  Widget _buildBottomBar(bool isMobile, bool showSideBySide) {
    final isLast  = _step == _kSteps.length - 1;
    final isFirst = _step == 0;
    return Container(
      decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade200))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: 12),
          child: Row(children: [
            if (!isFirst)
              OutlinedButton.icon(
                onPressed: _prev,
                icon: const Icon(Icons.arrow_back_ios_rounded, size: 13),
                label: const Text('السابق'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey.shade600,
                  side: BorderSide(color: Colors.grey.shade300),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_kRadius)),
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            // Preview button — only shown when preview pane is not side-by-side
            if (!isFirst) const SizedBox(width: 8),
            if (!showSideBySide)
              OutlinedButton.icon(
                onPressed: () => setState(() => _showPreview = !_showPreview),
                icon: Icon(
                  _showPreview ? Icons.close : Icons.phone_iphone_rounded,
                  size: 14,
                  color: _kAccent,
                ),
                label: Text(
                  _showPreview ? 'أغلق' : 'معاينة',
                  style: TextStyle(fontSize: 12, color: _kAccent, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: _kAccent.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_kRadius)),
                ),
              ),
            const Spacer(),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Text('${_step + 1} / ${_kSteps.length}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400, fontWeight: FontWeight.w600)),
              Text(_kSteps[_step].title,
                  style: TextStyle(fontSize: 10, color: _sc, fontWeight: FontWeight.w500)),
            ]),
            const Spacer(),
            if (!isLast)
              FilledButton(
                onPressed: _next,
                style: FilledButton.styleFrom(
                  backgroundColor: _sc,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_kRadius)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('التالي', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    SizedBox(width: 6),
                    Icon(Icons.arrow_forward_ios_rounded, size: 13, color: Colors.white),
                  ],
                ),
              )
            else
              FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_rounded, size: 17, color: Colors.white),
                label: Text(_isSaving ? 'جارٍ الحفظ...' : 'حفظ القائمة',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                style: FilledButton.styleFrom(
                  backgroundColor: _kSuccess,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_kRadius)),
                ),
              ),
          ]),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  Live Preview Pane (real replica)
  // ─────────────────────────────────────────────────────────
  Widget _buildPreviewPane() {
    return Container(
      color: Colors.grey.shade100,
      child: Column(
        children: [
          // Preview header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: Colors.white,
            child: Row(children: [
              const Icon(Icons.phone_iphone_rounded, size: 15, color: _kAccent),
              const SizedBox(width: 6),
              Text('معاينة التطبيق', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                  color: const Color(AppConstants.primaryColor))),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: _kAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _kAccent.withValues(alpha: 0.2))),
                child: Text('حية', style: TextStyle(fontSize: 9, color: _kAccent, fontWeight: FontWeight.w700)),
              ),
              const Spacer(),
              // Screen toggle
              if (_previewScreen == _PreviewScreen.form)
                GestureDetector(
                  onTap: () => setState(() => _previewScreen = _PreviewScreen.groups),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text('الرجوع', style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
            ]),
          ),
          const Divider(height: 1, color: Color(0xFFE8E9F0)),
          // Phone frame
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                Center(
                  child: Container(
                    width: 260,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(36),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(0, 10))],
                    ),
                    padding: const EdgeInsets.fromLTRB(8, 16, 8, 16),
                    child: Column(children: [
                      // Status bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        child: Row(children: [
                          Text('9:41', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700)),
                          const Spacer(),
                          const Icon(Icons.signal_cellular_alt, size: 11, color: Colors.white),
                          const SizedBox(width: 3),
                          const Icon(Icons.wifi, size: 11, color: Colors.white),
                          const SizedBox(width: 3),
                          const Icon(Icons.battery_full, size: 11, color: Colors.white),
                        ]),
                      ),
                      // Screen content
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: Directionality(
                          textDirection: ui.TextDirection.rtl,
                          child: _previewScreen == _PreviewScreen.groups
                              ? _buildGroupsScreen()
                              : _buildFormScreen(),
                        ),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 14),
                // Preview info
                _buildPreviewInfoCard(),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Groups Screen (first screen user sees) ─────────────────
  Widget _buildGroupsScreen() {
    final groupName = _titleCtrl.text.isEmpty ? 'اسم المجموعة...' : _titleCtrl.text;
    final groupDesc = _descCtrl.text;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // AppBar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(children: [
            const Icon(Icons.arrow_back_ios_new, size: 12, color: Color(0xFF1A1F36)),
            const SizedBox(width: 6),
            const Expanded(child: Text('تقارير مراقبة الجودة',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1A1F36)),
                overflow: TextOverflow.ellipsis)),
          ]),
        ),
        const Divider(height: 1, color: Color(0xFFE8E9F0)),
        Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header card
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: _kAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                      child: const Icon(Icons.checklist_outlined, size: 13, color: _kAccent),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('تقارير مراقبة الجودة',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF1A1F36))),
                      Text('القوائم المُسندة إليك فقط',
                          style: TextStyle(fontSize: 8, color: Colors.grey.shade500)),
                    ])),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.2)),
                      ),
                      child: Text('1 مجموعة',
                          style: const TextStyle(fontSize: 7.5, color: Color(0xFF065F46), fontWeight: FontWeight.w600)),
                    ),
                  ]),
                  const SizedBox(height: 7),
                  // Search bar mock
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(children: [
                      Icon(Icons.search, size: 10, color: Colors.grey.shade400),
                      const SizedBox(width: 5),
                      Text('البحث في القوائم...',
                          style: TextStyle(fontSize: 8.5, color: Colors.grey.shade400)),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 8),
              // Stats bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: _kAccent.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: _kAccent.withValues(alpha: 0.15)),
                ),
                child: Row(children: [
                  Icon(Icons.info_outline, size: 10, color: _kAccent),
                  const SizedBox(width: 5),
                  Text('${_totalCheckpoints} قائمة متاحة',
                      style: TextStyle(fontSize: 8.5, color: _kAccent, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text('1 مجموعة',
                      style: TextStyle(fontSize: 8, color: _kAccent.withValues(alpha: 0.7), fontWeight: FontWeight.w500)),
                ]),
              ),
              const SizedBox(height: 8),
              // Group card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    // Group header
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(color: _kAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(5)),
                          child: const Icon(Icons.folder_outlined, size: 12, color: _kAccent),
                        ),
                        const SizedBox(width: 7),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(groupName,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF1A1F36)),
                              overflow: TextOverflow.ellipsis),
                          if (groupDesc.isNotEmpty)
                            Text(groupDesc,
                                style: TextStyle(fontSize: 8, color: Colors.grey.shade500),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                        ])),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: _kAccent.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: _kAccent.withValues(alpha: 0.2)),
                          ),
                          child: Text('${_checklists.length} قائمة',
                              style: TextStyle(fontSize: 8, color: _kAccent, fontWeight: FontWeight.w600)),
                        ),
                      ]),
                    ),
                    const Divider(height: 1, color: Color(0xFFF3F4F6)),
                    // Checklists rows
                    ..._checklists.asMap().entries.map((e) {
                      final i = e.key; final cl = e.value;
                      final title = cl.titleCtrl.text.isEmpty
                          ? (_isMultiple ? 'القائمة ${i + 1}' : groupName)
                          : cl.titleCtrl.text;
                      final cpCount = cl.checkPoints.length;
                      return GestureDetector(
                        onTap: () => setState(() {
                          _previewSelectedChecklistIndex = i;
                          _previewScreen = _PreviewScreen.form;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                          decoration: BoxDecoration(
                            border: i < _checklists.length - 1
                                ? Border(bottom: BorderSide(color: Colors.grey.shade100))
                                : null,
                          ),
                          child: Row(children: [
                            Container(
                              width: 2.5, height: 30,
                              margin: const EdgeInsets.only(left: 5),
                              decoration: BoxDecoration(
                                color: _kAccent.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 7),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: _kAccent.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: const Icon(Icons.assignment_outlined, size: 11, color: _kAccent),
                            ),
                            const SizedBox(width: 7),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(title,
                                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: Color(0xFF1A1F36)),
                                  overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 2),
                              Row(children: [
                                Icon(Icons.checklist_rounded, size: 8, color: Colors.grey.shade500),
                                const SizedBox(width: 2),
                                Text('$cpCount نقطة',
                                    style: TextStyle(fontSize: 8, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
                                const SizedBox(width: 6),
                                Icon(Icons.star_outline_rounded, size: 8, color: Colors.grey.shade500),
                                const SizedBox(width: 2),
                                Text('من ${cl.rateCtrl.text}',
                                    style: TextStyle(fontSize: 8, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
                              ]),
                            ])),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              decoration: BoxDecoration(
                                color: _kAccent,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Text('ابدأ', style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w700)),
                                const SizedBox(width: 2),
                                const Icon(Icons.arrow_forward_ios, size: 7, color: Colors.white),
                              ]),
                            ),
                          ]),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  int get _totalCheckpoints => _checklists.fold(0, (s, c) => s + c.checkPoints.length);

  // ── Form Screen (checklist form) ───────────────────────────
  Widget _buildFormScreen() {
    final idx = _previewSelectedChecklistIndex.clamp(0, _checklists.length - 1);
    final cl = _checklists[idx];
    final groupName = _titleCtrl.text.isEmpty ? 'اسم المجموعة...' : _titleCtrl.text;
    final clTitle = cl.titleCtrl.text.isEmpty
        ? (_isMultiple ? 'القائمة ${idx + 1}' : groupName)
        : cl.titleCtrl.text;
    final maxRating = int.tryParse(cl.rateCtrl.text) ?? 5;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // AppBar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(children: [
            GestureDetector(
              onTap: () => setState(() => _previewScreen = _PreviewScreen.groups),
              child: const Icon(Icons.arrow_back_ios_new, size: 12, color: Color(0xFF1A1F36)),
            ),
            const SizedBox(width: 6),
            Expanded(child: Text(clTitle,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1A1F36)),
                overflow: TextOverflow.ellipsis)),
          ]),
        ),
        const Divider(height: 1, color: Color(0xFFE8E9F0)),
        Padding(
          padding: const EdgeInsets.all(9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header card
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(color: Colors.white,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: Colors.grey.shade200)),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: _kAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: const Icon(Icons.assignment_outlined, size: 13, color: _kAccent),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (cl.descCtrl.text.isNotEmpty)
                      Text(cl.descCtrl.text,
                          style: TextStyle(fontSize: 8, color: Colors.grey.shade500), maxLines: 1),
                    const SizedBox(height: 3),
                    Row(children: [
                      Icon(Icons.calendar_today_outlined, size: 9, color: Colors.grey.shade500),
                      const SizedBox(width: 3),
                      Text('اليوم', style: TextStyle(fontSize: 8.5, color: _kAccent, fontWeight: FontWeight.w600)),
                    ]),
                  ])),
                ]),
              ),
              // Determinants
              if (cl.determinants.isNotEmpty) ...[
                const SizedBox(height: 7),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: Colors.grey.shade200)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(Icons.tune_outlined, size: 10, color: _kAccent),
                      const SizedBox(width: 4),
                      Text('المحددات', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF1A1F36))),
                    ]),
                    const SizedBox(height: 7),
                    ...cl.determinants.take(2).map((d) {
                      final name = d.nameCtrl.text.isEmpty ? 'المحدد' : d.nameCtrl.text;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(name, style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.grey.shade200)),
                            child: Row(children: [
                              Text(d.options.isNotEmpty && d.options.first.valueCtrl.text.isNotEmpty
                                  ? d.options.first.valueCtrl.text : 'اختر...',
                                  style: const TextStyle(fontSize: 8, color: Color(0xFF1A1F36))),
                              const Spacer(),
                              Icon(Icons.expand_more_rounded, size: 10, color: Colors.grey.shade400),
                            ]),
                          ),
                        ]),
                      );
                    }).toList(),
                  ]),
                ),
              ],
              // Checkpoints
              const SizedBox(height: 7),
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: Colors.grey.shade200)),
                child: Column(children: [
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(children: [
                      const Icon(Icons.checklist_outlined, size: 10, color: _kAccent),
                      const SizedBox(width: 4),
                      const Text('نقاط الفحص', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF1A1F36))),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(color: _kAccent.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
                        child: Text('من $maxRating',
                            style: TextStyle(fontSize: 8, color: _kAccent, fontWeight: FontWeight.w600)),
                      ),
                    ]),
                  ),
                  const Divider(height: 1, color: Color(0xFFF3F4F6)),
                  ...cl.checkPoints.take(3).toList().asMap().entries.map((e) {
                    final cpi = e.key; final cp = e.value;
                    final t = cp.titleCtrl.text.isEmpty ? 'نقطة الفحص ${cpi + 1}...' : cp.titleCtrl.text;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                      decoration: cpi < (cl.checkPoints.take(3).length - 1)
                          ? BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100)))
                          : null,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(t, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w600, color: Color(0xFF1A1F36)),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Row(children: [
                          // Score badge
                          Container(
                            width: 26, height: 18,
                            decoration: BoxDecoration(
                              color: const Color(0xFF00C48C).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(color: const Color(0xFF00C48C).withValues(alpha: 0.3)),
                            ),
                            child: Center(child: Text('$maxRating',
                                style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Color(0xFF00C48C)))),
                          ),
                          const SizedBox(width: 5),
                          // Mini slider
                          Expanded(
                            child: Container(
                              height: 4,
                              decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), color: Colors.grey.shade200),
                              child: FractionallySizedBox(
                                widthFactor: 1.0,
                                alignment: Alignment.centerRight,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(2),
                                    color: const Color(0xFF00C48C),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ]),
                      ]),
                    );
                  }).toList(),
                  if (cl.checkPoints.length > 3)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Center(child: Text('+ ${cl.checkPoints.length - 3} المزيد',
                          style: TextStyle(fontSize: 8, color: Colors.grey.shade400))),
                    ),
                ]),
              ),
              const SizedBox(height: 7),
              // Submit button
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(color: _kAccent, borderRadius: BorderRadius.circular(6)),
                child: const Center(child: Text('إرسال النموذج',
                    style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700))),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewInfoCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(_kRadius),
          border: Border.all(color: Colors.grey.shade200)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('ملخص القائمة', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
              color: const Color(AppConstants.primaryColor))),
          const Spacer(),
          if (_previewScreen == _PreviewScreen.form)
            GestureDetector(
              onTap: () => setState(() => _previewScreen = _PreviewScreen.groups),
              child: Text('← شاشة المجموعات',
                  style: TextStyle(fontSize: 10, color: _kAccent, fontWeight: FontWeight.w600)),
            ),
        ]),
        const SizedBox(height: 10),
        _previewRow(Icons.title_rounded, 'الاسم',
            _titleCtrl.text.isEmpty ? '—' : _titleCtrl.text, _kAccent),
        _previewRow(Icons.layers_outlined, 'النوع',
            _isMultiple ? 'متعدد (${_checklists.length} قوائم)' : 'مفردة', _kStepColors[1]),
        if (_checklists.isNotEmpty)
          _previewRow(Icons.star_outline_rounded, 'أقصى تقييم',
              'من ${_checklists.first.rateCtrl.text}', _kStepColors[2]),
        if (_checklists.isNotEmpty)
          _previewRow(Icons.tune_outlined, 'محددات',
              '${_checklists.first.determinants.length} محدد', _kStepColors[3]),
        _previewRow(Icons.checklist_outlined, 'نقاط الفحص',
            '$_totalCheckpoints نقطة', _kStepColors[4]),
        _previewRow(Icons.people_alt_outlined, 'المُعيَّنون',
            '${_selectedUserIds.length} مستخدم', _kStepColors[5]),
        if (_previewScreen == _PreviewScreen.groups && _checklists.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: _kAccent.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _kAccent.withValues(alpha: 0.15)),
            ),
            child: Row(children: [
              Icon(Icons.touch_app_outlined, size: 12, color: _kAccent),
              const SizedBox(width: 6),
              Expanded(child: Text('انقر على قائمة في المعاينة لترى شاشة النموذج',
                  style: TextStyle(fontSize: 10.5, color: _kAccent, fontWeight: FontWeight.w500))),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _previewRow(IconData icon, String label, String val, Color c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(children: [
        Icon(icon, size: 13, color: c),
        const SizedBox(width: 7),
        Text(label, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
        const Spacer(),
        Text(val, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700,
            color: const Color(AppConstants.primaryColor))),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  BUILD
  //
  //  KEY FIX: The SpotlightOverlay is now placed in a root-level
  //  Stack that wraps the entire Scaffold body. This means the
  //  overlay's coordinate space matches global screen coordinates,
  //  so localToGlobal() measurements of target widgets are correct
  //  and the spotlight hole lands exactly on the target element.
  // ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, c) {
      final isMobile       = c.maxWidth < 700;
      final showSideBySide = c.maxWidth >= 1100;

      return Directionality(
        textDirection: ui.TextDirection.rtl,
        child: Scaffold(
          backgroundColor: Colors.grey.shade50,
          appBar: _buildAppBar(isMobile),
          // ── Wrap body in a Stack so the spotlight overlay sits at
          //    the very top of the body coordinate space. ──────────
          body: Stack(
            children: [
              // ── Main content ──────────────────────────────────
              Column(children: [
                _buildProgressBar(),
                _buildStepTabs(isMobile),
                Expanded(
                  child: showSideBySide
                      ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(flex: 3, child: _buildFormPageView(isMobile)),
                          VerticalDivider(width: 1, color: Colors.grey.shade200),
                          SizedBox(width: 320, child: _buildPreviewPane()),
                        ])
                      : Stack(children: [
                          _buildFormPageView(isMobile),
                          if (_showPreview)
                            Positioned.fill(
                              child: GestureDetector(
                                onTap: () => setState(() => _showPreview = false),
                                child: Container(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  alignment: Alignment.center,
                                  child: GestureDetector(
                                    onTap: () {},
                                    child: Container(
                                      width: 340, height: 600,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(_kRadiusLg),
                                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20)],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(_kRadiusLg),
                                        child: _buildPreviewPane(),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ]),
                ),
                _buildBottomBar(isMobile, showSideBySide),
              ]),

              // ── Spotlight tutorial overlay ─────────────────────
              // Placed as a direct child of the body Stack so it
              // fills the entire body area. Since we use global
              // coordinates in _measureTarget(), the hole will be
              // offset by the AppBar height relative to the body.
              // We compensate with a top-offset equal to the AppBar
              // height so the overlay covers the full screen visually
              // while still aligning with global positions.
              if (_showSpotlight && _spotlightSteps.isNotEmpty)
                Positioned(
                  // Extend upward by the AppBar height so the dark
                  // overlay covers the AppBar area too, and the
                  // coordinate math stays correct (global == body + appBarHeight).
                  top: -(kToolbarHeight + MediaQuery.of(context).padding.top),
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SpotlightOverlay(
                    steps: _spotlightSteps,
                    accentColor: _sc,
                    onComplete: _disableTutorialForever,
                    onSkip: _showSkipTutorialDialog,
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildFormPageView(bool isMobile) {
    final steps = [_step0, _step1, _step2, _step3, _step4, _step5];
    return Form(
      key: _formKey,
      child: PageView.builder(
        controller: _pageCtrl,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: steps.length,
        itemBuilder: (_, i) => _StepPage(
          key: PageStorageKey('step_$i'),
          color: _kStepColors[i],
          // builder is called lazily after the first frame so navigation
          // animations are never blocked by a heavy synchronous build.
          builder: () => _wrap(steps[i](isMobile), isMobile),
        ),
      ),
    );
  }

  Widget _wrap(Widget child, bool isMobile) {
    return FadeTransition(
      opacity: _entryFade,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.025), end: Offset.zero).animate(_entryFade),
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: isMobile ? 16 : 20),
          child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 820), child: child)),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  STEP 0 — Basics
  // ─────────────────────────────────────────────────────────
  Widget _step0(bool isMobile) {
    final c = _kStepColors[0];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _StepHeader(
        step: 1, total: _kSteps.length, title: 'المعلومات الأساسية',
        subtitle: 'أدخل اسم ووصف القائمة أو المجموعة', color: c,
        onHelp: () => setState(() => _showSpotlight = true),
      ),
      const SizedBox(height: 16),
      Container(
        padding: EdgeInsets.all(isMobile ? 16 : 20),
        decoration: _kCard(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _SectionHead(icon: Icons.folder_outlined,
              label: _isMultiple ? 'اسم المجموعة' : 'اسم القائمة', color: c),
          const SizedBox(height: 16),

          _FieldLabel(
            label: _isMultiple ? 'اسم المجموعة *' : 'اسم القائمة *',
            hint: 'يظهر كعنوان رئيسي في شاشة اختيار التقييم بالتطبيق',
          ),
          const SizedBox(height: 6),
          TextFormField(
            key: _keyTitleField,
            controller: _titleCtrl,
            onChanged: (v) { if (!_isMultiple) _syncTitle(); setState(() {}); },
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                color: const Color(AppConstants.primaryColor)),
            decoration: _inp(
                hint: _isMultiple ? 'مثال: مجموعة تقييمات المختبر' : 'مثال: قائمة مراقبة جودة المختبر',
                prefix: Icons.title_rounded),
          ),
          const SizedBox(height: 20),

          _FieldLabel(label: 'الوصف (اختياري)', hint: 'يظهر كنص رمادي تحت الاسم الرئيسي في التطبيق'),
          const SizedBox(height: 6),
          TextFormField(
            key: _keyDescField,
            controller: _descCtrl, maxLines: 3,
            style: const TextStyle(fontSize: 14),
            decoration: _inp(hint: 'وصف موجز لهدف هذه القائمة...', prefix: Icons.notes_rounded),
          ),
          const SizedBox(height: 20),
          Container(
            key: _keyModeChip,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(_kRadius),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(children: [
              Icon(Icons.info_outline_rounded, size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 8),
              Expanded(child: RichText(text: TextSpan(
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.5),
                children: [
                  TextSpan(text: 'نوع القائمة الحالي: ',
                      style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1A1F36))),
                  TextSpan(text: _isMultiple ? 'قوائم متعددة تحت مجموعة' : 'قائمة مفردة',
                      style: TextStyle(color: c, fontWeight: FontWeight.w700)),
                  const TextSpan(text: ' — يمكنك تغييره في الخطوة التالية.'),
                ],
              ))),
            ]),
          ),
        ]),
      ),
    ]);
  }

  // ─────────────────────────────────────────────────────────
  //  STEP 1 — Mode
  // ─────────────────────────────────────────────────────────
  Widget _step1(bool isMobile) {
    final c = _kStepColors[1];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _StepHeader(
        step: 2, total: _kSteps.length, title: 'نوع القائمة',
        subtitle: 'اختر إذا كانت قائمة واحدة أو مجموعة قوائم متعددة',
        color: c, onHelp: () => setState(() => _showSpotlight = true),
      ),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: _ModeCard(
            key: _keySingleCard,
            selected: !_isMultiple, icon: Icons.article_outlined,
            title: 'قائمة مفردة',
            desc: 'تقييم واحد مباشر — المراقب يبدأ بدون اختيار مسبق',
            badge: 'بسيط', color: c, onTap: () => _toggleMultiple(false))),
        const SizedBox(width: 12),
        Expanded(child: _ModeCard(
            key: _keyMultiCard,
            selected: _isMultiple, icon: Icons.layers_outlined,
            title: 'قوائم متعددة',
            desc: 'أكثر من قائمة — المراقب يختار من قائمة منسدلة',
            badge: 'متقدم', color: c, onTap: () => _toggleMultiple(true))),
      ]),

      if (_isMultiple && _selectorDet != null) ...[
        const SizedBox(height: 20),
        Container(
          decoration: _kCard(),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: EdgeInsets.all(isMobile ? 14 : 18),
              child: Row(children: [
                _SectionHead(icon: Icons.tune_outlined, label: 'إعداد محدد الاختيار', color: c),
                const Spacer(),
                _CountBadge(count: _selectorDet!.options.length, label: 'قائمة', color: c),
              ]),
            ),
            Divider(height: 1, color: Colors.grey.shade100),
            Padding(
              padding: EdgeInsets.all(isMobile ? 14 : 18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _FieldLabel(label: 'اسم محدد الاختيار *',
                    hint: 'يظهر كعنوان القائمة المنسدلة أعلى نموذج التقييم'),
                const SizedBox(height: 6),
                TextFormField(
                  key: _keySelectorName,
                  controller: _selectorDet!.nameCtrl,
                  style: const TextStyle(fontSize: 14),
                  decoration: _inp(hint: 'مثال: نوع الوردية، نوع الجهاز', prefix: Icons.label_outline_rounded),
                ),
                const SizedBox(height: 20),
                _FieldLabel(label: 'قوائم المجموعة',
                    hint: 'كل سطر هو خيار في القائمة المنسدلة + قائمة تقييم مستقلة'),
                const SizedBox(height: 12),
                ...List.generate(_selectorDet!.options.length, (i) {
                  final opt = _selectorDet!.options[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(_kRadius),
                      border: Border.all(color: c.withValues(alpha: 0.15)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(7)),
                          child: Center(child: Text('${i + 1}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white))),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: TextFormField(
                          controller: opt.valueCtrl,
                          onChanged: (v) => _onSelectorOptChanged(i, v),
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                              color: const Color(AppConstants.primaryColor)),
                          decoration: _inp(hint: 'اسم هذه القائمة'),
                        )),
                        const SizedBox(width: 8),
                        if (_selectorDet!.options.length > 1)
                          _DelBtn(enabled: true, onTap: () => _removeSelectorOption(i)),
                      ]),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: c.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(_kRadiusSm)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.auto_awesome, size: 12, color: c),
                          const SizedBox(width: 6),
                          Text('سيتم إنشاء قائمة تقييم مستقلة لهذا الخيار',
                              style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w500)),
                        ]),
                      ),
                    ]),
                  );
                }),
                const SizedBox(height: 4),
                _AddRow(label: 'إضافة قائمة جديدة للمجموعة', icon: Icons.add_circle_outline_rounded,
                    color: c, onTap: _addSelectorOption),
              ]),
            ),
          ]),
        ),
      ],
    ]);
  }

  // ─────────────────────────────────────────────────────────
  //  STEP 2 — Rating Scales
  // ─────────────────────────────────────────────────────────
  Widget _step2(bool isMobile) {
    final c = _kStepColors[2];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _StepHeader(
        step: 3, total: _kSteps.length, title: 'معايير التقييم',
        subtitle: 'حدد ماذا يعني كل رقم في التقييم',
        color: c, onHelp: () => setState(() => _showSpotlight = true),
      ),
      const SizedBox(height: 16),
      ..._checklists.asMap().entries.map((e) {
        final ci = e.key; final cl = e.value;
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: _kCard(),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: EdgeInsets.all(isMobile ? 14 : 18),
              child: Row(children: [
                if (_isMultiple)
                  _ClipLabel(title: cl.titleCtrl.text.isEmpty ? 'القائمة ${ci + 1}' : cl.titleCtrl.text, color: c)
                else
                  _SectionHead(icon: Icons.star_outline_rounded, label: 'معايير التقييم', color: c),
                const Spacer(),
                _CountBadge(count: cl.scales.length, label: 'مستوى', color: c),
              ]),
            ),
            Divider(height: 1, color: Colors.grey.shade100),
            Padding(
              padding: EdgeInsets.all(isMobile ? 14 : 18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: _FieldLabel(
                      label: 'أقصى رقم تقييم *',
                      hint: 'الحد الأقصى لأزرار الأرقام في نموذج التقييم (1-10)')),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 80,
                    child: TextFormField(
                      key: ci == 0 ? _keyRateField : null,
                      controller: cl.rateCtrl, keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      onChanged: (_) => setState(() {}),
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c),
                      decoration: _inp(hint: '5'),
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 8),
                  decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(_kRadiusSm)),
                  child: Row(children: [
                    SizedBox(width: 64, child: Text('من *', style: _headerStyle)),
                    const SizedBox(width: 8),
                    SizedBox(width: 64, child: Text('إلى', style: _headerStyle)),
                    const SizedBox(width: 8),
                    Expanded(child: Text('الوصف / التسمية *', style: _headerStyle)),
                    const SizedBox(width: 32),
                  ]),
                ),
                const SizedBox(height: 8),
                Column(
                  key: ci == 0 ? _keyScaleRows : null,
                  children: List.generate(cl.scales.length, (si) {
                    final s = cl.scales[si];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        _Num(n: si + 1, color: c),
                        const SizedBox(width: 8),
                        SizedBox(width: 64, child: TextFormField(
                          controller: s.minCtrl, keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                          decoration: _inp(hint: '0'),
                        )),
                        const SizedBox(width: 8),
                        SizedBox(width: 64, child: TextFormField(
                          controller: s.maxCtrl, keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13),
                          decoration: _inp(hint: '—'),
                        )),
                        const SizedBox(width: 8),
                        Expanded(child: TextFormField(
                          controller: s.labelCtrl,
                          style: const TextStyle(fontSize: 13),
                          decoration: _inp(hint: 'مثال: ممتاز جداً'),
                        )),
                        const SizedBox(width: 6),
                        _DelBtn(enabled: cl.scales.length > 1,
                            onTap: cl.scales.length > 1 ? () => _removeScale(ci, si) : null),
                      ]),
                    );
                  }),
                ),
                const SizedBox(height: 4),
                _AddRow(label: 'إضافة مستوى تقييم', icon: Icons.add_rounded, color: c, onTap: () => _addScale(ci)),
              ]),
            ),
          ]),
        );
      }).toList(),
    ]);
  }

  TextStyle get _headerStyle => TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade500);

  // ─────────────────────────────────────────────────────────
  //  STEP 3 — Determinants
  // ─────────────────────────────────────────────────────────
  Widget _step3(bool isMobile) {
    final c = _kStepColors[3];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _StepHeader(
        step: 4, total: _kSteps.length, title: 'المحددات',
        subtitle: 'قوائم منسدلة يملؤها المراقب قبل بدء التقييم',
        color: c, onHelp: () => setState(() => _showSpotlight = true),
      ),
      const SizedBox(height: 16),
      ..._checklists.asMap().entries.map((e) {
        final ci = e.key; final cl = e.value;
        return Container(
          key: ci == 0 ? _keyDetSection : null,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: _kCard(),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: EdgeInsets.all(isMobile ? 14 : 18),
              child: Row(children: [
                if (_isMultiple)
                  _ClipLabel(title: cl.titleCtrl.text.isEmpty ? 'القائمة ${ci + 1}' : cl.titleCtrl.text, color: c)
                else
                  _SectionHead(icon: Icons.tune_outlined, label: 'المحددات', color: c),
                const Spacer(),
                _CountBadge(count: cl.determinants.length, label: 'محدد', color: c),
              ]),
            ),
            Divider(height: 1, color: Colors.grey.shade100),
            Padding(
              padding: EdgeInsets.fromLTRB(isMobile ? 14 : 18, 14, isMobile ? 14 : 18, isMobile ? 14 : 18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // ── Empty state hint ──────────────────────────
                if (cl.determinants.isEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: c.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(_kRadius),
                      border: Border.all(color: c.withValues(alpha: 0.15)),
                    ),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(Icons.info_outline_rounded, size: 16, color: c.withValues(alpha: 0.7)),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('هذه الخطوة اختيارية',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c)),
                        const SizedBox(height: 4),
                        Text(
                          'المحددات هي قوائم منسدلة يختار منها المراقب قيمة قبل بدء التقييم (مثال: رقم الشاحنة، الوردية). '
                          'إذا لم تحتج لها اتركها فارغة وانتقل للخطوة التالية.',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.5),
                        ),
                      ])),
                    ]),
                  ),
                // ── Determinant items ─────────────────────────
                ...List.generate(cl.determinants.length, (di) => _DetRow(
                  key: ValueKey(cl.determinants[di].id),
                  index: di,
                  det: cl.determinants[di],
                  color: c,
                  isMobile: isMobile,
                  onDelete: () => _removeDet(ci, di),
                  onAddOption: () => _addDetOpt(ci, di),
                  onRemoveOption: (oi) => _removeDetOpt(ci, di, oi),
                )),
                _AddRow(label: 'إضافة محدد', icon: Icons.add_circle_outline_rounded,
                    color: c, onTap: () => _addDet(ci)),
              ]),
            ),
          ]),
        );
      }).toList(),
    ]);
  }

  // ─────────────────────────────────────────────────────────
  //  STEP 4 — Check Points
  // ─────────────────────────────────────────────────────────
  Widget _step4(bool isMobile) {
    final c = _kStepColors[4];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _StepHeader(
        step: 5, total: _kSteps.length, title: 'نقاط الفحص',
        subtitle: 'العناصر الفعلية التي يقيّمها المراقب بالأرقام',
        color: c, onHelp: () => setState(() => _showSpotlight = true),
      ),
      const SizedBox(height: 16),
      ..._checklists.asMap().entries.map((e) {
        final ci = e.key; final cl = e.value;
        return Container(
          key: ci == 0 ? _keyCpSection : null,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: _kCard(),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: EdgeInsets.all(isMobile ? 14 : 18),
              child: Row(children: [
                if (_isMultiple)
                  _ClipLabel(title: cl.titleCtrl.text.isEmpty ? 'القائمة ${ci + 1}' : cl.titleCtrl.text, color: c)
                else
                  _SectionHead(icon: Icons.checklist_outlined, label: 'نقاط الفحص', color: c),
                const Spacer(),
                _CountBadge(count: cl.checkPoints.length, label: 'نقطة', color: c),
              ]),
            ),
            Divider(height: 1, color: Colors.grey.shade100),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: cl.checkPoints.length,
              onReorder: (oldIdx, newIdx) {
                setState(() {
                  if (newIdx > oldIdx) newIdx--;
                  final item = cl.checkPoints.removeAt(oldIdx);
                  cl.checkPoints.insert(newIdx, item);
                });
              },
              itemBuilder: (ctx, cpi) {
                final cp = cl.checkPoints[cpi];
                return _CPRow(
                  key: ValueKey(cp.id),
                  index: cpi,
                  total: cl.checkPoints.length,
                  cp: cp,
                  color: c,
                  isMobile: isMobile,
                  onInsertAfter: () => _insertCPAt(ci, cpi + 1),
                  onDelete: cl.checkPoints.length > 1
                      ? () => _removeCP(ci, cpi)
                      : null,
                );
              },
            ),
            Padding(
              padding: EdgeInsets.all(isMobile ? 14 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _AddRow(label: 'إضافة نقطة فحص', icon: Icons.add_task_rounded,
                      color: c, onTap: () => _addCP(ci)),
                  if (_checklists.length > 1) ...[
                    const SizedBox(height: 8),
                    _AddRow(
                      label: 'استيراد نقاط من قائمة أخرى',
                      icon: Icons.file_copy_outlined,
                      color: c,
                      onTap: () => _showImportCheckpointsDialog(ci, c),
                    ),
                  ],
                ],
              ),
            ),
          ]),
        );
      }).toList(),
    ]);
  }

  // ─────────────────────────────────────────────────────────
  //  STEP 5 — Users
  // ─────────────────────────────────────────────────────────
  Widget _step5(bool isMobile) {
    final c = _kStepColors[5];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _StepHeader(
        step: 6, total: _kSteps.length, title: 'تعيين المستخدمين',
        subtitle: 'من سيرى هذه المجموعة في تطبيقه',
        color: c, onHelp: () => setState(() => _showSpotlight = true),
      ),
      const SizedBox(height: 16),
      Container(
        key: _keyUsersSection,
        padding: EdgeInsets.all(isMobile ? 14 : 18),
        decoration: _kCard(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _SectionHead(icon: Icons.people_alt_outlined, label: 'مراقبو الجودة', color: c),
            const Spacer(),
            _CountBadge(count: _allUsers.length, label: 'متاح', color: c),
          ]),
          const SizedBox(height: 14),
          if (_loadingUsers)
            const Center(child: Padding(padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: _kAccent)))
          else if (_allUsers.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(_kRadius),
                  border: Border.all(color: Colors.grey.shade200)),
              child: Column(children: [
                Icon(Icons.people_outline_rounded, size: 36, color: Colors.grey.shade400),
                const SizedBox(height: 10),
                Text('لا يوجد مراقبو جودة مسجلون',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
                const SizedBox(height: 4),
                Text('أضف مستخدمين من نوع "مراقب جودة" من إدارة المستخدمين',
                    style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500), textAlign: TextAlign.center),
              ]),
            )
          else ...[
            Row(children: [
              Text('المتاحون (${_allUsers.length})',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() {
                  _selectedUserIds = _selectedUserIds.length == _allUsers.length
                      ? [] : _allUsers.map((u) => u.id).toList();
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: c.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(_kRadiusSm),
                      border: Border.all(color: c.withValues(alpha: 0.2))),
                  child: Text(_selectedUserIds.length == _allUsers.length ? 'إلغاء تحديد الكل' : 'تحديد الكل',
                      style: TextStyle(fontSize: 11.5, color: c, fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _allUsers.map((user) {
                final sel = _selectedUserIds.contains(user.id);
                final canEdit = _userEditPermissions[user.id] ?? false;
                return _UserChip(
                  key: ValueKey(user.id),
                  user: user,
                  selected: sel,
                  color: c,
                  canEdit: canEdit,
                  onTap: () => setState(() {
                    if (sel) {
                      _selectedUserIds.remove(user.id);
                      _userEditPermissions.remove(user.id);
                    } else {
                      _selectedUserIds.add(user.id);
                    }
                  }),
                  onToggleEdit: sel
                      ? () => setState(() {
                            _userEditPermissions[user.id] =
                                !(_userEditPermissions[user.id] ?? false);
                          })
                      : null,
                );
              }).toList(),
            ),
            if (_selectedUserIds.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: _kSuccessLight, borderRadius: BorderRadius.circular(_kRadius),
                    border: Border.all(color: _kSuccess.withValues(alpha: 0.3))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.check_circle_outline_rounded, color: _kSuccess, size: 15),
                  const SizedBox(width: 7),
                  Expanded(child: Text(
                      'تم تحديد ${_selectedUserIds.length} مراقب — سيتمكنون من رؤية هذه المجموعة',
                      style: const TextStyle(fontSize: 12, color: _kSuccess, fontWeight: FontWeight.w600))),
                ]),
              ),
            ],
          ],
        ]),
      ),
    ]);
  }

  // ── Shared helpers ────────────────────────────────────────
  InputDecoration _inp({String? hint, IconData? prefix, String? suffix}) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
    prefixIcon: prefix != null ? Icon(prefix, size: 17, color: Colors.grey.shade400) : null,
    suffixText: suffix,
    filled: true, fillColor: Colors.grey.shade50,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(_kRadius), borderSide: BorderSide(color: Colors.grey.shade200)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(_kRadius), borderSide: BorderSide(color: Colors.grey.shade200)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(_kRadius), borderSide: const BorderSide(color: _kAccent, width: 1.5)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    isDense: true,
  );
}

// ─────────────────────────────────────────────────────────────
//  Reusable small widgets
// ─────────────────────────────────────────────────────────────

class _StepHeader extends StatelessWidget {
  final int step, total;
  final String title, subtitle;
  final Color color;
  final VoidCallback onHelp;

  const _StepHeader({
    required this.step, required this.total,
    required this.title, required this.subtitle,
    required this.color, required this.onHelp,
  });

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 40, height: 40,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
        child: Center(child: Text('$step', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white))),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: const Color(AppConstants.primaryColor))),
        const SizedBox(height: 3),
        Text(subtitle, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500)),
      ])),
      GestureDetector(
        onTap: onHelp,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.help_outline_rounded, size: 14, color: color),
            const SizedBox(width: 5),
            Text('شرح', style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    ]);
  }
}

class _SectionHead extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _SectionHead({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 15, color: color),
      const SizedBox(width: 7),
      Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(AppConstants.primaryColor))),
    ]);
  }
}

class _FieldLabel extends StatelessWidget {
  final String label, hint;
  const _FieldLabel({required this.label, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: const Color(AppConstants.primaryColor))),
      const SizedBox(height: 2),
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.phone_iphone_rounded, size: 10, color: Colors.grey.shade400),
        const SizedBox(width: 4),
        Flexible(child: Text(hint,
            style: TextStyle(fontSize: 10.5, color: Colors.grey.shade400, fontStyle: FontStyle.italic))),
      ]),
    ]);
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  final String label;
  final Color color;
  const _CountBadge({required this.count, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Text('$count $label', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _ClipLabel extends StatelessWidget {
  final String title;
  final Color color;
  const _ClipLabel({required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.layers_outlined, size: 12, color: color),
        const SizedBox(width: 5),
        Text(title, style: TextStyle(fontSize: 11.5, color: color, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _Num extends StatelessWidget {
  final int n;
  final Color color;
  const _Num({required this.n, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26, height: 26,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Center(child: Text('$n', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color))),
    );
  }
}

class _IcoBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const _IcoBtn({required this.icon, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.2))),
        child: Icon(icon, size: 15, color: color),
      ),
    );
  }
}

class _DelBtn extends StatelessWidget {
  final bool enabled;
  final VoidCallback? onTap;
  const _DelBtn({required this.enabled, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: enabled ? _kDanger.withValues(alpha: 0.07) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: enabled ? _kDanger.withValues(alpha: 0.2) : Colors.grey.shade200),
        ),
        child: Icon(Icons.delete_outline_rounded, size: 15, color: enabled ? _kDanger : Colors.grey.shade400),
      ),
    );
  }
}

class _AddRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _AddRow({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16, color: color),
        label: Text(label, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color.withValues(alpha: 0.3)),
          backgroundColor: color.withValues(alpha: 0.04),
          padding: const EdgeInsets.symmetric(vertical: 11),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title, desc, badge;
  final Color color;
  final VoidCallback onTap;

  const _ModeCard({
    super.key,
    required this.selected, required this.icon,
    required this.title, required this.desc,
    required this.badge, required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? color : Colors.grey.shade200, width: selected ? 2 : 1),
          boxShadow: selected
              ? [BoxShadow(color: color.withValues(alpha: 0.12), blurRadius: 10, offset: const Offset(0, 3))]
              : [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: selected ? color : Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: selected ? Colors.white : Colors.grey.shade400, size: 22),
          ),
          const SizedBox(height: 10),
          Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
              color: selected ? color : const Color(AppConstants.primaryColor))),
          const SizedBox(height: 5),
          Text(desc, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: selected ? color : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(badge, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600,
                color: selected ? Colors.white : Colors.grey.shade500)),
          ),
          const SizedBox(height: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 18, height: 18,
            decoration: BoxDecoration(
              color: selected ? color : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(color: selected ? color : Colors.grey.shade300, width: 2),
            ),
            child: selected ? const Icon(Icons.check_rounded, size: 10, color: Colors.white) : null,
          ),
        ]),
      ),
    );
  }
}

// Kept as StatelessWidget + plain Container (no AnimationControllers, no hover
// state) — with 50+ users in the list the saving is significant.
class _UserChip extends StatelessWidget {
  final AppUser user;
  final bool selected;
  final Color color;
  final bool canEdit;
  final VoidCallback onTap;
  final VoidCallback? onToggleEdit;

  const _UserChip({
    super.key,
    required this.user,
    required this.selected,
    required this.color,
    required this.onTap,
    this.canEdit = false,
    this.onToggleEdit,
  });

  @override
  Widget build(BuildContext context) {
    final c = color;
    const editColor = Color(0xFF10B981);
    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? c.withValues(alpha: 0.07) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? c.withValues(alpha: 0.35) : Colors.grey.shade200,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: selected ? c : Colors.grey.shade400,
              child: Text(
                user.username.isNotEmpty ? user.username[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(user.username,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600,
                      color: selected ? c : const Color(AppConstants.primaryColor))),
              Text(user.email, style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500)),
            ]),
            const SizedBox(width: 8),
            Container(
              width: 16, height: 16,
              decoration: BoxDecoration(
                color: selected ? c : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: selected ? c : Colors.grey.shade300, width: 1.5),
              ),
              child: selected ? const Icon(Icons.check_rounded, size: 10, color: Colors.white) : null,
            ),
            if (selected && onToggleEdit != null) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onToggleEdit,
                child: Tooltip(
                  message: canEdit ? 'يمكنه تعديل تقاريره' : 'لا يمكنه التعديل',
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: canEdit ? editColor.withValues(alpha: 0.1) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: canEdit ? editColor.withValues(alpha: 0.4) : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(
                        canEdit ? Icons.edit_rounded : Icons.edit_off_rounded,
                        size: 11,
                        color: canEdit ? editColor : Colors.grey.shade400,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        canEdit ? 'تعديل' : 'قراءة',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: canEdit ? editColor : Colors.grey.shade500,
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Checkpoint row — StatelessWidget so Flutter can diff/skip it
// ─────────────────────────────────────────────────────────────

InputDecoration _cpInp({String? hint}) => InputDecoration(
  hintText: hint,
  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
  filled: true,
  fillColor: Colors.grey.shade50,
  border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_kRadius),
      borderSide: BorderSide(color: Colors.grey.shade200)),
  enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_kRadius),
      borderSide: BorderSide(color: Colors.grey.shade200)),
  focusedBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(_kRadius)),
      borderSide: BorderSide(color: _kAccent, width: 1.5)),
  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  isDense: true,
);

class _CPRow extends StatelessWidget {
  final int index;
  final int total;
  final CPBuilder cp;
  final Color color;
  final bool isMobile;
  final VoidCallback onInsertAfter;
  final VoidCallback? onDelete;

  const _CPRow({
    required super.key,
    required this.index,
    required this.total,
    required this.cp,
    required this.color,
    required this.isMobile,
    required this.onInsertAfter,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 14 : 18, vertical: 12),
            child: Row(children: [
              ReorderableDragStartListener(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(Icons.drag_indicator_rounded,
                      size: 18, color: Colors.grey.shade400),
                ),
              ),
              Container(
                width: 3,
                height: 38,
                margin: const EdgeInsets.only(left: 10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              _Num(n: index + 1, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: cp.titleCtrl,
                  style: const TextStyle(fontSize: 14),
                  decoration: _cpInp(hint: 'مثال: نظافة منطقة العمل'),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onInsertAfter,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: color.withValues(alpha: 0.25)),
                  ),
                  child: Icon(Icons.add_rounded, size: 14, color: color),
                ),
              ),
              const SizedBox(width: 4),
              _DelBtn(enabled: total > 1, onTap: onDelete),
            ]),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Step page wrapper — defers first render so navigation never
//  freezes, then keeps the page alive via AutomaticKeepAlive so
//  revisiting a step is instant.
// ─────────────────────────────────────────────────────────────
class _StepPage extends StatefulWidget {
  final Widget Function() builder;
  final Color color;

  const _StepPage({required super.key, required this.builder, required this.color});

  @override
  State<_StepPage> createState() => _StepPageState();
}

class _StepPageState extends State<_StepPage> with AutomaticKeepAliveClientMixin {
  bool _ready = false;
  bool _rebuildPending = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Defer the first build to the next frame — page-slide animation
    // plays smoothly before the heavy widget tree is constructed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  void didUpdateWidget(_StepPage old) {
    super.didUpdateWidget(old);
    // Batch every parent-setState into a single next-frame rebuild.
    // This prevents the current step from rebuilding synchronously
    // every time any unrelated parent state changes (e.g. loading flag,
    // mode toggle). Multiple rapid changes collapse into one repaint.
    if (_ready && !_rebuildPending) {
      _rebuildPending = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _rebuildPending = false;
        if (mounted) setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin
    if (!_ready) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(60),
          child: CircularProgressIndicator(color: widget.color, strokeWidth: 2),
        ),
      );
    }
    return widget.builder();
  }
}

// ─────────────────────────────────────────────────────────────
//  Determinant option row — isolated repaint boundary
// ─────────────────────────────────────────────────────────────
class _DetOptRow extends StatelessWidget {
  final DetOptBuilder opt;
  final Color color;
  final bool canDelete;
  final VoidCallback? onDelete;

  const _DetOptRow({
    required super.key,
    required this.opt,
    required this.color,
    required this.canDelete,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(children: [
          Container(
            width: 6, height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          Expanded(child: TextField(
            controller: opt.valueCtrl,
            style: const TextStyle(fontSize: 13),
            decoration: _cpInp(hint: 'قيمة الخيار'),
          )),
          const SizedBox(width: 8),
          if (canDelete)
            _IcoBtn(icon: Icons.remove_rounded, color: _kDanger, onTap: onDelete),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Determinant row — isolated repaint boundary
// ─────────────────────────────────────────────────────────────
class _DetRow extends StatelessWidget {
  final int index;
  final DeterminantBuilder det;
  final Color color;
  final bool isMobile;
  final VoidCallback onDelete;
  final VoidCallback onAddOption;
  final void Function(int optIndex) onRemoveOption;

  const _DetRow({
    required super.key,
    required this.index,
    required this.det,
    required this.color,
    required this.isMobile,
    required this.onDelete,
    required this.onAddOption,
    required this.onRemoveOption,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(_kRadius),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(children: [
              _Num(n: index + 1, color: color),
              const SizedBox(width: 10),
              Expanded(child: TextField(
                controller: det.nameCtrl,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                    color: const Color(AppConstants.primaryColor)),
                decoration: _cpInp(hint: 'اسم المحدد (مثال: رقم الشاحنة)'),
              )),
              const SizedBox(width: 8),
              _DelBtn(enabled: true, onTap: onDelete),
            ]),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('خيارات هذا المحدد:',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500)),
              const SizedBox(height: 8),
              ...List.generate(det.options.length, (oi) => _DetOptRow(
                key: ValueKey(det.options[oi].id),
                opt: det.options[oi],
                color: color,
                canDelete: det.options.length > 1,
                onDelete: () => onRemoveOption(oi),
              )),
              const SizedBox(height: 4),
              _AddRow(label: 'إضافة خيار', icon: Icons.add_rounded,
                  color: color, onTap: onAddOption),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Data builder classes
// ─────────────────────────────────────────────────────────────
class ChecklistBuilder {
  final String id;
  final TextEditingController titleCtrl, descCtrl, rateCtrl;
  String? selectorOptionValue;
  final List<DeterminantBuilder> determinants;
  final List<ScaleBuilder> scales;
  final List<CPBuilder> checkPoints;

  ChecklistBuilder({
    required this.id, required this.titleCtrl, required this.descCtrl,
    required this.rateCtrl, this.selectorOptionValue,
    required this.determinants, required this.scales, required this.checkPoints,
  });

  void dispose() {
    titleCtrl.dispose(); descCtrl.dispose(); rateCtrl.dispose();
    for (final d in determinants) d.dispose();
    for (final s in scales) s.dispose();
    for (final cp in checkPoints) cp.titleCtrl.dispose();
  }
}

class ScaleBuilder {
  final String id;
  final TextEditingController minCtrl, maxCtrl, labelCtrl;
  ScaleBuilder({required this.id, required this.minCtrl, required this.maxCtrl, required this.labelCtrl});
  void dispose() { minCtrl.dispose(); maxCtrl.dispose(); labelCtrl.dispose(); }
}

class DeterminantBuilder {
  final String id;
  final TextEditingController nameCtrl;
  final List<DetOptBuilder> options;
  DeterminantBuilder({required this.id, required this.nameCtrl, required this.options});
  void dispose() { nameCtrl.dispose(); for (final o in options) o.valueCtrl.dispose(); }
}

class DetOptBuilder {
  final String id;
  final TextEditingController valueCtrl;
  DetOptBuilder({required this.id, required this.valueCtrl});
}

class CPBuilder {
  final String id;
  final TextEditingController titleCtrl;
  CPBuilder({required this.id, required this.titleCtrl});
}