// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:jala_as/models/user.dart';
import 'package:jala_as/services/supabase_service.dart';
import 'package:jala_as/utils/constants.dart';
import 'package:jala_as/utils/helpers.dart';

class ProfileScreen extends StatefulWidget {
  final AppUser user;
  const ProfileScreen({super.key, required this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // ── Colors ────────────────────────────────────────────────────────────────
  static const _primary = Color(AppConstants.primaryColor);
  static const _bg = Color(0xFFF1F3F4);
  static const _textMain = Color(0xFF202124);
  static const _textSub = Color(0xFF5F6368);
  static const _border = Color(0xFFE8EAED);

  // ── Personal info ─────────────────────────────────────────────────────────
  final _infoFormKey = GlobalKey<FormState>();
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _areaCtrl;
  bool _savingInfo = false;
  bool _editingInfo = false;

  // ── Password ──────────────────────────────────────────────────────────────
  final _pwdFormKey = GlobalKey<FormState>();
  final _currentPwdCtrl = TextEditingController();
  final _newPwdCtrl = TextEditingController();
  final _confirmPwdCtrl = TextEditingController();
  bool _showCurrentPwd = false;
  bool _showNewPwd = false;
  bool _showConfirmPwd = false;
  bool _savingPwd = false;

  // ── OTP ───────────────────────────────────────────────────────────────────
  final _otpFormKey = GlobalKey<FormState>();
  final _otpCtrl = TextEditingController();
  final _otpNewPwdCtrl = TextEditingController();
  final _otpConfirmPwdCtrl = TextEditingController();
  bool _showOtpNewPwd = false;
  bool _showOtpConfirmPwd = false;
  bool _otpSent = false;
  bool _sendingOtp = false;
  bool _verifyingOtp = false;

  // ── Notifications ─────────────────────────────────────────────────────────
  Map<String, bool> _prefs = {};
  bool _loadingPrefs = true;
  bool _savingPrefs = false;

  int _passwordMethod = 0;

  bool get _showArea => !widget.user.isQualityController &&
      !widget.user.isQualityControlAdmin &&
      !widget.user.isSystemAdmin;

  @override
  void initState() {
    super.initState();
    _usernameCtrl = TextEditingController(text: widget.user.username);
    _areaCtrl = TextEditingController(text: widget.user.area ?? '');
    _loadPreferences();
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _areaCtrl.dispose();
    _currentPwdCtrl.dispose();
    _newPwdCtrl.dispose();
    _confirmPwdCtrl.dispose();
    _otpCtrl.dispose();
    _otpNewPwdCtrl.dispose();
    _otpConfirmPwdCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final prefs =
        await SupabaseService.getNotificationPreferences(widget.user.id);
    if (mounted) setState(() { _prefs = prefs; _loadingPrefs = false; });
  }

  Future<void> _saveInfo() async {
    if (!_infoFormKey.currentState!.validate()) return;
    setState(() => _savingInfo = true);
    try {
      await SupabaseService.updateUserProfile(
        userId: widget.user.id,
        username: _usernameCtrl.text.trim(),
        area: _showArea ? _areaCtrl.text.trim() : null,
      );
      if (mounted) {
        setState(() => _editingInfo = false);
        Helpers.showSnackBar(context, 'تم تحديث المعلومات بنجاح');
      }
    } catch (_) {
      if (mounted) {
        Helpers.showSnackBar(context, 'فشل في تحديث المعلومات', isError: true);
      }
    } finally {
      if (mounted) setState(() => _savingInfo = false);
    }
  }

  Future<void> _savePassword() async {
    if (!_pwdFormKey.currentState!.validate()) return;
    setState(() => _savingPwd = true);
    try {
      await SupabaseService.changePasswordWithCurrentPassword(
        email: widget.user.email,
        currentPassword: _currentPwdCtrl.text,
        newPassword: _newPwdCtrl.text,
      );
      if (mounted) {
        Helpers.showSnackBar(context, 'تم تغيير كلمة المرور بنجاح');
        _currentPwdCtrl.clear();
        _newPwdCtrl.clear();
        _confirmPwdCtrl.clear();
      }
    } catch (_) {
      if (mounted) {
        Helpers.showSnackBar(context, 'كلمة المرور الحالية غير صحيحة',
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _savingPwd = false);
    }
  }

  Future<void> _sendOtp() async {
    setState(() => _sendingOtp = true);
    try {
      await SupabaseService.sendPasswordResetOtp(widget.user.email);
      if (mounted) {
        setState(() => _otpSent = true);
        Helpers.showSnackBar(
            context, 'تم إرسال رمز التحقق إلى بريدك الإلكتروني');
      }
    } catch (_) {
      if (mounted) {
        Helpers.showSnackBar(context, 'فشل في إرسال رمز التحقق', isError: true);
      }
    } finally {
      if (mounted) setState(() => _sendingOtp = false);
    }
  }

  Future<void> _verifyOtpAndSave() async {
    if (!_otpFormKey.currentState!.validate()) return;
    setState(() => _verifyingOtp = true);
    try {
      await SupabaseService.verifyOtpAndChangePassword(
        email: widget.user.email,
        otp: _otpCtrl.text.trim(),
        newPassword: _otpNewPwdCtrl.text,
      );
      if (mounted) {
        Helpers.showSnackBar(context, 'تم تغيير كلمة المرور بنجاح');
        _otpCtrl.clear();
        _otpNewPwdCtrl.clear();
        _otpConfirmPwdCtrl.clear();
        setState(() => _otpSent = false);
      }
    } catch (_) {
      if (mounted) {
        Helpers.showSnackBar(
            context, 'رمز التحقق غير صحيح أو منتهي الصلاحية',
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _verifyingOtp = false);
    }
  }

  Future<void> _savePrefs() async {
    setState(() => _savingPrefs = true);
    try {
      await SupabaseService.updateNotificationPreferences(
        userId: widget.user.id,
        preferences: _prefs,
      );
      if (mounted) Helpers.showSnackBar(context, 'تم حفظ إعدادات الإشعارات');
    } catch (_) {
      if (mounted) {
        Helpers.showSnackBar(context, 'فشل في حفظ إعدادات الإشعارات',
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _savingPrefs = false);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String get _initials {
    final parts = widget.user.username.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return widget.user.username.isNotEmpty
        ? widget.user.username[0].toUpperCase()
        : '?';
  }

  Color _userTypeColor() {
    if (widget.user.isSystemAdmin) return const Color(0xFF8B5CF6);
    if (widget.user.isQualityControlAdmin) return const Color(0xFF0EA5E9);
    if (widget.user.isQualityController) return const Color(0xFF10B981);
    if (widget.user.isSalesAdmin) return const Color(0xFFF59E0B);
    return _primary;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _bg,
        body: CustomScrollView(
          slivers: [
            _buildHeroAppBar(),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 16),
                  _buildInfoCard(),
                  const SizedBox(height: 12),
                  _buildSecurityCard(),
                  const SizedBox(height: 12),
                  _buildNotificationsCard(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Hero SliverAppBar ─────────────────────────────────────────────────────
  Widget _buildHeroAppBar() {
    final typeColor = _userTypeColor();
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: _primary,
      iconTheme: const IconThemeData(color: Colors.white),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _primary,
                Color.lerp(_primary, const Color(0xFF000000), 0.3)!,
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                // Avatar
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      _initials,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: _primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.user.username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.user.email,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: typeColor.withValues(alpha: 0.6)),
                  ),
                  child: Text(
                    widget.user.userTypeDisplayText,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.95),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      title: const Text(
        'الملف الشخصي',
        style: TextStyle(color: Colors.white, fontSize: 17),
      ),
    );
  }

  // ── Info Card ─────────────────────────────────────────────────────────────
  Widget _buildInfoCard() {
    return _SectionCard(
      header: _CardHeader(
        icon: Icons.person_outline_rounded,
        iconColor: _primary,
        title: 'المعلومات الشخصية',
        trailing: _editingInfo
            ? null
            : _HeaderButton(
                label: 'تعديل',
                icon: Icons.edit_outlined,
                onTap: () => setState(() => _editingInfo = true),
              ),
      ),
      child: _editingInfo ? _buildInfoEditForm() : _buildInfoReadView(),
    );
  }

  Widget _buildInfoReadView() {
    return Column(
      children: [
        _InfoRow(
          icon: Icons.email_outlined,
          label: 'البريد الإلكتروني',
          value: widget.user.email,
          locked: true,
        ),
        _divider(),
        _InfoRow(
          icon: Icons.badge_outlined,
          label: 'اسم المستخدم',
          value: widget.user.username,
        ),
        _divider(),
        _InfoRow(
          icon: Icons.admin_panel_settings_outlined,
          label: 'نوع المستخدم',
          value: widget.user.userTypeDisplayText,
          locked: true,
        ),
        _divider(),
        _InfoRow(
          icon: Icons.work_outline_rounded,
          label: 'المسمى الوظيفي',
          value: widget.user.positionName ?? 'غير محدد',
          locked: true,
        ),
        if (_showArea && (widget.user.area?.isNotEmpty ?? false)) ...[
          _divider(),
          _InfoRow(
            icon: Icons.location_on_outlined,
            label: 'المنطقة',
            value: widget.user.area!,
          ),
        ],
      ],
    );
  }

  Widget _buildInfoEditForm() {
    return Form(
      key: _infoFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ReadOnlyInfoField(
            icon: Icons.email_outlined,
            label: 'البريد الإلكتروني',
            value: widget.user.email,
          ),
          const SizedBox(height: 12),
          _buildField(
            controller: _usernameCtrl,
            label: 'اسم المستخدم',
            icon: Icons.badge_outlined,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'اسم المستخدم مطلوب' : null,
          ),
          if (_showArea) ...[
            const SizedBox(height: 12),
            _buildField(
              controller: _areaCtrl,
              label: 'المنطقة',
              icon: Icons.location_on_outlined,
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _savingInfo
                      ? null
                      : () {
                          _usernameCtrl.text = widget.user.username;
                          _areaCtrl.text = widget.user.area ?? '';
                          setState(() => _editingInfo = false);
                        },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _textSub,
                    side: const BorderSide(color: _border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('إلغاء'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: _savingInfo ? null : _saveInfo,
                  style: FilledButton.styleFrom(
                    backgroundColor: _primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: _savingInfo
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('حفظ'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Security Card ─────────────────────────────────────────────────────────
  Widget _buildSecurityCard() {
    return _SectionCard(
      header: const _CardHeader(
        icon: Icons.shield_outlined,
        iconColor: Color(0xFF10B981),
        title: 'الأمان وكلمة المرور',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Method selector tabs
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                _SegmentTab(
                  label: 'كلمة المرور',
                  icon: Icons.lock_outline,
                  selected: _passwordMethod == 0,
                  onTap: () => setState(() => _passwordMethod = 0),
                ),
                _SegmentTab(
                  label: 'رمز التحقق',
                  icon: Icons.sms_outlined,
                  selected: _passwordMethod == 1,
                  onTap: () => setState(() => _passwordMethod = 1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_passwordMethod == 0) _buildCurrentPasswordForm(),
          if (_passwordMethod == 1) _buildOtpForm(),
        ],
      ),
    );
  }

  Widget _buildCurrentPasswordForm() {
    return Form(
      key: _pwdFormKey,
      child: Column(
        children: [
          _buildPasswordField(
            controller: _currentPwdCtrl,
            label: 'كلمة المرور الحالية',
            show: _showCurrentPwd,
            onToggle: () =>
                setState(() => _showCurrentPwd = !_showCurrentPwd),
            validator: (v) =>
                (v == null || v.isEmpty) ? 'أدخل كلمة المرور الحالية' : null,
          ),
          const SizedBox(height: 12),
          _buildPasswordField(
            controller: _newPwdCtrl,
            label: 'كلمة المرور الجديدة',
            show: _showNewPwd,
            onToggle: () => setState(() => _showNewPwd = !_showNewPwd),
            validator: (v) {
              if (v == null || v.isEmpty) return 'أدخل كلمة المرور الجديدة';
              if (v.length < 6) return 'يجب أن تكون 6 أحرف على الأقل';
              return null;
            },
          ),
          const SizedBox(height: 12),
          _buildPasswordField(
            controller: _confirmPwdCtrl,
            label: 'تأكيد كلمة المرور',
            show: _showConfirmPwd,
            onToggle: () =>
                setState(() => _showConfirmPwd = !_showConfirmPwd),
            validator: (v) => v != _newPwdCtrl.text
                ? 'كلمتا المرور غير متطابقتين'
                : null,
          ),
          const SizedBox(height: 16),
          _PrimaryButton(
            label: 'تغيير كلمة المرور',
            loading: _savingPwd,
            onTap: _savePassword,
          ),
        ],
      ),
    );
  }

  Widget _buildOtpForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _InfoBanner(
          icon: Icons.info_outline_rounded,
          color: _primary,
          text: 'سيتم إرسال رمز التحقق إلى: ${widget.user.email}',
        ),
        const SizedBox(height: 12),
        if (!_otpSent) ...[
          _PrimaryButton(
            label: 'إرسال رمز التحقق',
            icon: Icons.send_rounded,
            loading: _sendingOtp,
            onTap: _sendOtp,
          ),
        ] else ...[
          Form(
            key: _otpFormKey,
            child: Column(
              children: [
                _InfoBanner(
                  icon: Icons.check_circle_outline_rounded,
                  color: const Color(0xFF10B981),
                  text: 'تم إرسال الرمز، يرجى التحقق من بريدك الإلكتروني',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _otpCtrl,
                  keyboardType: TextInputType.number,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 8),
                  decoration: _fieldDeco('رمز التحقق', Icons.pin_outlined),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'أدخل رمز التحقق' : null,
                ),
                const SizedBox(height: 12),
                _buildPasswordField(
                  controller: _otpNewPwdCtrl,
                  label: 'كلمة المرور الجديدة',
                  show: _showOtpNewPwd,
                  onToggle: () =>
                      setState(() => _showOtpNewPwd = !_showOtpNewPwd),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'أدخل كلمة المرور الجديدة';
                    }
                    if (v.length < 6) return 'يجب أن تكون 6 أحرف على الأقل';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _buildPasswordField(
                  controller: _otpConfirmPwdCtrl,
                  label: 'تأكيد كلمة المرور',
                  show: _showOtpConfirmPwd,
                  onToggle: () => setState(
                      () => _showOtpConfirmPwd = !_showOtpConfirmPwd),
                  validator: (v) => v != _otpNewPwdCtrl.text
                      ? 'كلمتا المرور غير متطابقتين'
                      : null,
                ),
                const SizedBox(height: 16),
                _PrimaryButton(
                  label: 'تأكيد وتغيير كلمة المرور',
                  loading: _verifyingOtp,
                  onTap: _verifyOtpAndSave,
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton.icon(
                    onPressed: _sendingOtp ? null : _sendOtp,
                    icon: const Icon(Icons.refresh_rounded, size: 15),
                    label: const Text('إعادة إرسال الرمز',
                        style: TextStyle(fontSize: 13)),
                    style: TextButton.styleFrom(foregroundColor: _primary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ── Notifications Card ────────────────────────────────────────────────────
  Widget _buildNotificationsCard() {
    return _SectionCard(
      header: const _CardHeader(
        icon: Icons.notifications_outlined,
        iconColor: Color(0xFFF59E0B),
        title: 'إعدادات الإشعارات',
      ),
      child: _loadingPrefs
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              children: [
                _NotifToggle(
                  icon: Icons.notifications_active_outlined,
                  iconColor: _primary,
                  label: 'تشغيل جميع الإشعارات',
                  subtitle: 'تعطيل هذا الخيار يوقف جميع الإشعارات',
                  value: _prefs['all_notifications'] ?? true,
                  onChanged: (v) => setState(() => _prefs['all_notifications'] = v),
                  isHeader: true,
                ),
                if (_prefs['all_notifications'] == true) ...[
                  _divider(),
                  _NotifToggle(
                    icon: Icons.alarm_outlined,
                    iconColor: const Color(0xFF6366F1),
                    label: 'التذكيرات كل ساعة',
                    subtitle: 'تذكير بالمهام المعلقة كل ساعة',
                    value: _prefs['hourly_reminders'] ?? true,
                    onChanged: (v) =>
                        setState(() => _prefs['hourly_reminders'] = v),
                  ),
                  _divider(),
                  _NotifToggle(
                    icon: Icons.wb_sunny_outlined,
                    iconColor: const Color(0xFFF59E0B),
                    label: 'التذكيرات الصباحية',
                    subtitle: 'ملخص صباحي بمهام اليوم',
                    value: _prefs['morning_reminders'] ?? true,
                    onChanged: (v) =>
                        setState(() => _prefs['morning_reminders'] = v),
                  ),
                  _divider(),
                  _NotifToggle(
                    icon: Icons.task_alt_outlined,
                    iconColor: const Color(0xFF10B981),
                    label: 'تكليف قائمة مهام',
                    subtitle: 'عند تكليفك بقائمة مهام جديدة',
                    value: _prefs['task_assigned'] ?? true,
                    onChanged: (v) =>
                        setState(() => _prefs['task_assigned'] = v),
                  ),
                  _divider(),
                  _NotifToggle(
                    icon: Icons.checklist_outlined,
                    iconColor: const Color(0xFF0EA5E9),
                    label: 'إشعارات قوائم المهام',
                    subtitle: 'تحديثات على قوائم المهام المعينة لك',
                    value: _prefs['task_list_notifications'] ?? true,
                    onChanged: (v) =>
                        setState(() => _prefs['task_list_notifications'] = v),
                  ),
                  _divider(),
                  _NotifToggle(
                    icon: Icons.warning_amber_outlined,
                    iconColor: const Color(0xFFEF4444),
                    label: 'تعيين مشكلة جودة',
                    subtitle: 'عند تعيين مشكلة جودة لك',
                    value: _prefs['quality_issue_assigned'] ?? true,
                    onChanged: (v) =>
                        setState(() => _prefs['quality_issue_assigned'] = v),
                  ),
                  _divider(),
                  _NotifToggle(
                    icon: Icons.group_outlined,
                    iconColor: const Color(0xFF8B5CF6),
                    label: 'إضافة إلى مجموعة جودة',
                    subtitle: 'عند إضافتك إلى مجموعة مراقبة جودة',
                    value: _prefs['quality_group_assigned'] ?? true,
                    onChanged: (v) =>
                        setState(() => _prefs['quality_group_assigned'] = v),
                  ),
                  _divider(),
                  _NotifToggle(
                    icon: Icons.check_circle_outline,
                    iconColor: const Color(0xFF10B981),
                    label: 'حل مشكلة جودة',
                    subtitle: 'عند حل مشكلة جودة أبلغت عنها',
                    value: _prefs['quality_issue_resolved'] ?? true,
                    onChanged: (v) =>
                        setState(() => _prefs['quality_issue_resolved'] = v),
                  ),
                ],
                const SizedBox(height: 16),
                _PrimaryButton(
                  label: 'حفظ إعدادات الإشعارات',
                  loading: _savingPrefs,
                  onTap: _savePrefs,
                ),
              ],
            ),
    );
  }

  // ── Shared field builders ─────────────────────────────────────────────────
  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(fontSize: 14, color: _textMain),
      decoration: _fieldDeco(label, icon),
      validator: validator,
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool show,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: !show,
      style: const TextStyle(fontSize: 14, color: _textMain),
      decoration: _fieldDeco(label, Icons.lock_outline_rounded).copyWith(
        suffixIcon: IconButton(
          icon: Icon(
              show
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size: 18),
          onPressed: onToggle,
          color: _textSub,
        ),
      ),
      validator: validator,
    );
  }

  InputDecoration _fieldDeco(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 13, color: _textSub),
      prefixIcon: Icon(icon, size: 18, color: _primary),
      filled: true,
      fillColor: const Color(0xFFF8F9FA),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: _primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide:
            const BorderSide(color: Color(0xFFEF4444), width: 1.5),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Widget _divider() =>
      const Divider(height: 1, indent: 52, color: _border);
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPOSABLE WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final _CardHeader header;
  final Widget child;

  const _SectionCard({required this.header, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: header,
          ),
          const Divider(height: 1, color: Color(0xFFE8EAED)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget? trailing;

  const _CardHeader({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF202124),
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _HeaderButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderButton(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1F36).withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: const Color(0xFF5F6368)),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF5F6368)),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool locked;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F3F4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 17, color: const Color(0xFF5F6368)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF5F6368),
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF202124),
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          if (locked)
            const Icon(Icons.lock_outline_rounded,
                size: 14, color: Color(0xFFBDBDBD)),
        ],
      ),
    );
  }
}

class _ReadOnlyInfoField extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ReadOnlyInfoField(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8EAED)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFFBDBDBD)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF9AA0A6))),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        fontSize: 14, color: Color(0xFF9AA0A6))),
              ],
            ),
          ),
          const Icon(Icons.lock_outline_rounded,
              size: 14, color: Color(0xFFBDBDBD)),
        ],
      ),
    );
  }
}

class _SegmentTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SegmentTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const primary = Color(AppConstants.primaryColor);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 1),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 15,
                  color: selected ? primary : const Color(0xFF9AA0A6)),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.normal,
                  color: selected ? primary : const Color(0xFF9AA0A6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotifToggle extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isHeader;

  const _NotifToggle({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.isHeader = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: iconColor, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        isHeader ? FontWeight.w700 : FontWeight.w500,
                    color: const Color(0xFF202124),
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF9AA0A6)),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: iconColor,
            activeTrackColor: iconColor.withValues(alpha: 0.3),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _InfoBanner(
      {required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool loading;
  final VoidCallback onTap;

  const _PrimaryButton({
    required this.label,
    required this.loading,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    const primary = Color(AppConstants.primaryColor);
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: loading ? null : onTap,
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          disabledBackgroundColor: primary.withValues(alpha: 0.45),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(vertical: 13),
        ),
        child: loading
            ? const SizedBox(
                width: 17,
                height: 17,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white))
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16),
                    const SizedBox(width: 6),
                  ],
                  Text(label,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                ],
              ),
      ),
    );
  }
}
