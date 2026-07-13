import 'package:flutter/material.dart';
import '../../../models/role.dart';
import '../../../models/feature_definition.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/constants.dart';
import '../../../utils/helpers.dart';

class RoleEditorScreen extends StatefulWidget {
  final Role? role; // null = create new

  const RoleEditorScreen({super.key, this.role});

  @override
  State<RoleEditorScreen> createState() => _RoleEditorScreenState();
}

class _RoleEditorScreenState extends State<RoleEditorScreen> {
  static const _primary = Color(AppConstants.primaryColor);
  static const _accent = Color(AppConstants.accentColor);

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  InterfaceType _interfaceType = InterfaceType.user;
  bool _isActive = true;
  bool _saving = false;

  // featureKey → config map (only for enabled features)
  final Map<String, Map<String, dynamic>> _featureConfigs = {};

  bool get _isEdit => widget.role != null;

  @override
  void initState() {
    super.initState();
    final r = widget.role;
    if (r != null) {
      _nameCtrl.text = r.nameAr;
      _descCtrl.text = r.description ?? '';
      _interfaceType = r.interfaceType;
      _isActive = r.isActive;
      for (final f in r.features) {
        _featureConfigs[f.featureKey] = Map<String, dynamic>.from(f.config);
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  bool _featureEnabled(String key) => _featureConfigs.containsKey(key);

  void _toggleFeature(String key, bool enabled) {
    setState(() {
      if (enabled) {
        _featureConfigs[key] = {};
      } else {
        _featureConfigs.remove(key);
      }
    });
  }

  void _setConfig(String featureKey, String configKey, dynamic value) {
    setState(() {
      _featureConfigs.putIfAbsent(featureKey, () => <String, dynamic>{})[configKey] = value;
    });
  }

  dynamic _getConfig(String featureKey, String configKey,
      {dynamic defaultValue}) {
    return _featureConfigs[featureKey]?[configKey] ?? defaultValue;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      late String roleId;
      if (_isEdit) {
        await SupabaseService.updateRole(
          widget.role!.id,
          nameAr: _nameCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
          interfaceType: _interfaceType,
          isActive: _isActive,
        );
        roleId = widget.role!.id;
      } else {
        final created = await SupabaseService.createRole(
          nameAr: _nameCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
          interfaceType: _interfaceType,
        );
        roleId = created.id;
      }

      // Build and save feature list
      final features = _featureConfigs.entries
          .map((e) => RoleFeature(featureKey: e.key, config: e.value))
          .toList();
      await SupabaseService.setRoleFeatures(roleId, features);

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) Helpers.showApiErrorDialog(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final features = AppFeatures.forInterface(_interfaceType);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          foregroundColor: _primary,
          title: Text(
            _isEdit ? 'تعديل الدور' : 'إنشاء دور جديد',
            style: const TextStyle(
                color: _primary, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 4),
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(backgroundColor: _accent),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('حفظ'),
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(height: 1, color: Colors.grey.shade200),
          ),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // ── Basic info ─────────────────────────────────────────────────
              _Section(
                title: 'المعلومات الأساسية',
                icon: Icons.info_outline,
                children: [
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'اسم الدور *',
                      hintText: 'مثال: مندوب مبيعات',
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'الاسم مطلوب' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'الوصف (اختياري)',
                      hintText: 'وصف مختصر لهذا الدور',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  // Interface type selector
                  Text('نوع الواجهة',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700)),
                  const SizedBox(height: 8),
                  Row(
                    children: InterfaceType.values.map((type) {
                      final selected = _interfaceType == type;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (_interfaceType == type) return;
                            if (_featureConfigs.isNotEmpty) {
                              _showInterfaceChangeWarning(type);
                            } else {
                              setState(() {
                                _interfaceType = type;
                              });
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: EdgeInsets.only(
                                left: type == InterfaceType.user ? 6 : 0),
                            padding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              color: selected
                                  ? type.color.withValues(alpha: 0.1)
                                  : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selected
                                    ? type.color
                                    : Colors.grey.shade300,
                                width: selected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(type.icon,
                                    size: 18,
                                    color: selected
                                        ? type.color
                                        : Colors.grey.shade500),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    type.displayName,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: selected
                                          ? type.color
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  // Active switch
                  Row(
                    children: [
                      Expanded(
                        child: Text('حالة الدور',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade700)),
                      ),
                      Switch(
                        value: _isActive,
                        activeColor: _accent,
                        onChanged: (v) => setState(() => _isActive = v),
                      ),
                      Text(_isActive ? 'مفعّل' : 'معطّل',
                          style: TextStyle(
                              fontSize: 13,
                              color: _isActive
                                  ? Colors.green.shade600
                                  : Colors.red.shade400)),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ── Features ───────────────────────────────────────────────────
              _Section(
                title: 'الصلاحيات',
                icon: Icons.checklist_outlined,
                subtitle:
                    'فعّل الصلاحيات التي يمكن لهذا الدور الوصول إليها',
                children: features
                    .map((def) => _FeatureTile(
                          definition: def,
                          enabled: _featureEnabled(def.key),
                          config: _featureConfigs[def.key] ?? {},
                          onToggle: (v) => _toggleFeature(def.key, v),
                          onConfigChanged: (ck, cv) =>
                              _setConfig(def.key, ck, cv),
                          getConfig: (ck, {dv}) =>
                              _getConfig(def.key, ck, defaultValue: dv),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showInterfaceChangeWarning(InterfaceType newType) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تغيير نوع الواجهة'),
          content: const Text(
              'تغيير نوع الواجهة سيحذف جميع الصلاحيات المحددة حالياً. هل تريد المتابعة؟'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء')),
            TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.orange),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('متابعة')),
          ],
        ),
      ),
    );
    if (ok == true) {
      setState(() {
        _interfaceType = newType;
        _featureConfigs.clear();
      });
    }
  }
}

// ── Section wrapper ───────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? subtitle;
  final List<Widget> children;

  const _Section({
    required this.title,
    required this.icon,
    this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Icon(icon,
                    size: 18,
                    color: const Color(AppConstants.accentColor)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(AppConstants.primaryColor))),
                      if (subtitle != null)
                        Text(subtitle!,
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade100),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Feature tile ──────────────────────────────────────────────────────────────

class _FeatureTile extends StatelessWidget {
  final FeatureDefinition definition;
  final bool enabled;
  final Map<String, dynamic> config;
  final ValueChanged<bool> onToggle;
  final void Function(String key, dynamic value) onConfigChanged;
  final dynamic Function(String key, {dynamic dv}) getConfig;

  const _FeatureTile({
    required this.definition,
    required this.enabled,
    required this.config,
    required this.onToggle,
    required this.onConfigChanged,
    required this.getConfig,
  });

  @override
  Widget build(BuildContext context) {
    final accent = const Color(AppConstants.accentColor);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: enabled
            ? accent.withValues(alpha: 0.04)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: enabled ? accent.withValues(alpha: 0.3) : Colors.grey.shade200,
          width: enabled ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(definition.icon,
                    size: 20,
                    color: enabled ? accent : Colors.grey.shade400),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(definition.nameAr,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: enabled
                                  ? const Color(AppConstants.primaryColor)
                                  : Colors.grey.shade600)),
                      if (definition.descriptionAr != null)
                        Text(definition.descriptionAr!,
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500)),
                    ],
                  ),
                ),
                Switch(
                  value: enabled,
                  activeColor: accent,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: onToggle,
                ),
              ],
            ),
          ),
          // Config fields (visible only when enabled and schema exists)
          if (enabled && definition.configSchema.isNotEmpty) ...[
            Divider(height: 1, color: accent.withValues(alpha: 0.15)),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: definition.configSchema
                    .where((field) => _isVisible(field))
                    .map((field) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ConfigField(
                            field: field,
                            value: getConfig(field.key,
                                dv: field.defaultValue),
                            onChanged: (v) =>
                                onConfigChanged(field.key, v),
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool _isVisible(ConfigField field) {
    if (field.showWhenKey == null) return true;
    final controlling = getConfig(field.showWhenKey!, dv: null);
    return controlling?.toString() == field.showWhenValue;
  }
}

// ── Dynamic config field ──────────────────────────────────────────────────────

class _ConfigField extends StatefulWidget {
  final ConfigField field;
  final dynamic value;
  final ValueChanged<dynamic> onChanged;

  const _ConfigField({
    required this.field,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_ConfigField> createState() => _ConfigFieldState();
}

class _ConfigFieldState extends State<_ConfigField> {
  late final TextEditingController _addCtrl;

  @override
  void initState() {
    super.initState();
    _addCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _addCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.field.label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(AppConstants.primaryColor))),
        if (widget.field.hint != null) ...[
          const SizedBox(height: 2),
          Text(widget.field.hint!,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ],
        const SizedBox(height: 6),
        _buildInput(),
      ],
    );
  }

  Widget _buildInput() {
    switch (widget.field.type) {
      case ConfigFieldType.select:
        return _buildSelect();
      case ConfigFieldType.multiSelect:
        return _buildMultiSelect();
      case ConfigFieldType.textList:
        return _buildTextList();
      case ConfigFieldType.toggle:
        return _buildToggle();
      case ConfigFieldType.text:
        return _buildText();
    }
  }

  Widget _buildSelect() {
    final val = widget.value?.toString() ??
        widget.field.defaultValue?.toString();
    return DropdownButtonFormField<String>(
      value: val,
      isExpanded: true,
      decoration: const InputDecoration(
        contentPadding:
            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      ),
      items: widget.field.options
          .map((o) => DropdownMenuItem(
              value: o.value,
              child: Text(o.label,
                  style: const TextStyle(fontSize: 13))))
          .toList(),
      onChanged: widget.onChanged,
    );
  }

  Widget _buildMultiSelect() {
    final selected = (widget.value as List<dynamic>? ??
            widget.field.defaultValue as List? ?? [])
        .map((e) => e.toString())
        .toList();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: widget.field.options.map((opt) {
        final isSelected = selected.contains(opt.value);
        return FilterChip(
          label: Text(opt.label, style: const TextStyle(fontSize: 12)),
          selected: isSelected,
          selectedColor:
              const Color(AppConstants.accentColor).withValues(alpha: 0.15),
          checkmarkColor: const Color(AppConstants.accentColor),
          onSelected: (v) {
            final newList = List<String>.from(selected);
            if (v) {
              newList.add(opt.value);
            } else {
              newList.remove(opt.value);
            }
            widget.onChanged(newList);
          },
        );
      }).toList(),
    );
  }

  Widget _buildTextList() {
    final items = (widget.value as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (items.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: items
                .map((item) => Chip(
                      label: Text(item,
                          style: const TextStyle(fontSize: 12)),
                      deleteIcon: const Icon(Icons.close, size: 14),
                      onDeleted: () {
                        final newList = List<String>.from(items)
                          ..remove(item);
                        widget.onChanged(newList);
                      },
                    ))
                .toList(),
          ),
        if (items.isNotEmpty) const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _addCtrl,
                decoration: const InputDecoration(
                  hintText: 'أضف عنصراً...',
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 13),
                onSubmitted: _addItem,
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              onPressed: () => _addItem(_addCtrl.text),
              icon: const Icon(Icons.add_circle_outline),
              color: const Color(AppConstants.accentColor),
              tooltip: 'إضافة',
            ),
          ],
        ),
      ],
    );
  }

  void _addItem(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final items = ((widget.value as List<dynamic>?) ?? [])
        .map((e) => e.toString())
        .toList();
    if (!items.contains(trimmed)) {
      widget.onChanged([...items, trimmed]);
    }
    _addCtrl.clear();
  }

  Widget _buildToggle() {
    return Switch(
      value: widget.value as bool? ?? widget.field.defaultValue as bool? ?? false,
      activeColor: const Color(AppConstants.accentColor),
      onChanged: widget.onChanged,
    );
  }

  Widget _buildText() {
    return TextFormField(
      initialValue: widget.value?.toString() ?? '',
      decoration: const InputDecoration(
        contentPadding:
            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      ),
      style: const TextStyle(fontSize: 13),
      onChanged: widget.onChanged,
    );
  }
}
