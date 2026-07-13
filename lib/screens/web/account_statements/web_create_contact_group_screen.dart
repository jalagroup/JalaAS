// lib/screens/web/web_create_contact_group_screen.dart
import 'package:flutter/material.dart';
import 'package:jala_as/models/contact.dart';
import 'package:jala_as/models/contact_group.dart';
import 'package:jala_as/models/user.dart';
import 'package:jala_as/services/supabase_service.dart';
import 'package:jala_as/utils/constants.dart';
import 'package:jala_as/utils/arabic_text_helper.dart';
import 'dart:ui' as ui;

class CreateContactGroupScreen extends StatefulWidget {
  final AppUser user;
  final ContactGroup? editingGroup;

  const CreateContactGroupScreen({
    super.key,
    required this.user,
    this.editingGroup,
  });

  @override
  State<CreateContactGroupScreen> createState() =>
      _CreateContactGroupScreenState();
}

// lib/screens/web/web_create_contact_group_screen.dart - OPTIMIZED

class _CreateContactGroupScreenState extends State<CreateContactGroupScreen> {
  final _nameController = TextEditingController();
  final _searchController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  List<Contact> _allContacts = [];
  List<Contact> _filteredContacts = [];
  Set<String> _selectedContactCodes = {};
  bool _isLoading = true;
  bool _isSaving = false;
  String _searchQuery = '';

  bool get _isEditing => widget.editingGroup != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _nameController.text = widget.editingGroup!.name;
      _selectedContactCodes = widget.editingGroup!.contactCodes.toSet();
    }
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadContacts();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    if (_searchQuery != query) {
      setState(() {
        _searchQuery = query;
        _filterContacts();
      });
    }
  }

  void _filterContacts() {
    if (_searchQuery.isEmpty) {
      _filteredContacts = _allContacts;
    } else {
      final lowerQuery = _searchQuery.toLowerCase();
      _filteredContacts = _allContacts.where((contact) {
        return contact.nameAr.toLowerCase().contains(lowerQuery) ||
            contact.code.toLowerCase().contains(lowerQuery);
      }).toList();
    }
  }

  Future<void> _loadContacts() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final user = widget.user;
      List<Contact> contacts;

      if (user.isSystemAdmin) {
        contacts = await SupabaseService.getContacts();
      } else if (user.isSalesAdmin) {
        contacts = await SupabaseService.getUserContacts(
          salesman: '00',
          area: user.area,
        );
      } else {
        contacts = await SupabaseService.getUserContacts(
          salesman: user.salesman,
          area: user.area,
          additionalContactCodes: user.additionalContactCodes,
        );
      }

      if (mounted) {
        setState(() {
          _allContacts = contacts;
          _filteredContacts = contacts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('فشل في تحميل قائمة العملاء', true);
      }
    }
  }

  void _toggleContactSelection(String contactCode) {
    setState(() {
      if (_selectedContactCodes.contains(contactCode)) {
        _selectedContactCodes.remove(contactCode);
      } else {
        _selectedContactCodes.add(contactCode);
      }
    });
  }

  Future<void> _saveGroup() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedContactCodes.isEmpty) {
      _showSnackBar('يرجى اختيار عميل واحد على الأقل', true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      if (_isEditing) {
        await SupabaseService.updateContactGroup(
          id: widget.editingGroup!.id!,
          name: _nameController.text.trim(),
          contactCodes: _selectedContactCodes.toList(),
        );
        _showSnackBar('تم تحديث المجموعة بنجاح', false);
      } else {
        await SupabaseService.createContactGroup(
          name: _nameController.text.trim(),
          contactCodes: _selectedContactCodes.toList(),
        );
        _showSnackBar('تم إنشاء المجموعة بنجاح', false);
      }

      if (mounted) {
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        _showSnackBar(
          _isEditing ? 'فشل في تحديث المجموعة' : 'فشل في إنشاء المجموعة',
          true,
        );
      }
    }
  }

  void _showSnackBar(String message, bool isError) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;
    final isMobile = size.width < 768;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back,
                color: Color(AppConstants.primaryColor)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            _isEditing ? 'تعديل المجموعة' : 'إنشاء مجموعة جديدة',
            style: const TextStyle(
              color: Color(AppConstants.primaryColor),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 1000 : double.infinity,
            ),
            child: Column(
              children: [
                // Name Input & Selected Count
                Container(
                  padding: EdgeInsets.all(isMobile ? 16 : 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Form(
                        key: _formKey,
                        child: TextFormField(
                          controller: _nameController,
                          textDirection: ui.TextDirection.rtl,
                          decoration: InputDecoration(
                            labelText: 'اسم المجموعة',
                            hintText: 'أدخل اسم المجموعة',
                            hintTextDirection: ui.TextDirection.rtl,
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            prefixIcon: Container(
                              margin: const EdgeInsets.all(8),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(AppConstants.accentColor),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.label,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(AppConstants.accentColor),
                                width: 1.5,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'يرجى إدخال اسم المجموعة';
                            }
                            return null;
                          },
                        ),
                      ),
                      if (_selectedContactCodes.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 12 : 16,
                            vertical: isMobile ? 8 : 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(AppConstants.accentColor)
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(AppConstants.accentColor)
                                  .withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: isMobile ? 16 : 18,
                                color: const Color(AppConstants.accentColor),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'تم اختيار ${_selectedContactCodes.length} عميل',
                                style: TextStyle(
                                  color: const Color(AppConstants.accentColor),
                                  fontWeight: FontWeight.w600,
                                  fontSize: isMobile ? 13 : 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Search
                Padding(
                  padding: EdgeInsets.all(isMobile ? 16 : 24),
                  child: TextField(
                    controller: _searchController,
                    textDirection: ui.TextDirection.rtl,
                    decoration: InputDecoration(
                      labelText: 'البحث عن عميل',
                      hintText: 'ادخل اسم العميل أو رقمه',
                      hintTextDirection: ui.TextDirection.rtl,
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      prefixIcon: Container(
                        margin: const EdgeInsets.all(8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(AppConstants.accentColor),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.search,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey),
                              onPressed: () => _searchController.clear(),
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(AppConstants.accentColor),
                          width: 1.5,
                        ),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 16 : 20,
                        vertical: isMobile ? 12 : 16,
                      ),
                    ),
                  ),
                ),

                // Contacts List
                Expanded(
                  child: _buildContactsList(isMobile),
                ),

                // Save Button
                Container(
                  padding: EdgeInsets.all(isMobile ? 16 : 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: isMobile ? 50 : 56,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveGroup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(AppConstants.accentColor),
                        disabledBackgroundColor: Colors.grey.shade300,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _isSaving
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _isEditing
                                      ? 'جاري التحديث...'
                                      : 'جاري الحفظ...',
                                  style: TextStyle(
                                    fontSize: isMobile ? 14 : 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _isEditing ? Icons.save : Icons.check,
                                  size: isMobile ? 18 : 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _isEditing
                                      ? 'حفظ التعديلات'
                                      : 'إنشاء المجموعة',
                                  style: TextStyle(
                                    fontSize: isMobile ? 14 : 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContactsList(bool isMobile) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Color(AppConstants.accentColor),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'جاري تحميل العملاء...',
              style: TextStyle(
                fontSize: isMobile ? 14 : 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    if (_filteredContacts.isEmpty) {
      return Center(
        child: Text(
          'لا توجد نتائج',
          style: TextStyle(
            fontSize: isMobile ? 16 : 18,
            color: Colors.grey.shade600,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: 8,
      ),
      physics: const BouncingScrollPhysics(),
      itemCount: _filteredContacts.length,
      itemBuilder: (context, index) {
        final contact = _filteredContacts[index];
        final isSelected = _selectedContactCodes.contains(contact.code);

        return _SelectableContactCard(
          key: ValueKey(contact.code),
          contact: contact,
          isSelected: isSelected,
          isMobile: isMobile,
          onTap: () => _toggleContactSelection(contact.code),
        );
      },
    );
  }
}

class _SelectableContactCard extends StatelessWidget {
  final Contact contact;
  final bool isSelected;
  final bool isMobile;
  final VoidCallback onTap;

  const _SelectableContactCard({
    super.key,
    required this.contact,
    required this.isSelected,
    required this.isMobile,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 8 : 12),
      child: Material(
        color: isSelected
            ? const Color(AppConstants.accentColor).withOpacity(0.1)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 14,
              vertical: isMobile ? 10 : 12,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? const Color(AppConstants.accentColor)
                    : Colors.grey.shade200,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                // Checkbox
                Container(
                  width: isMobile ? 22 : 24,
                  height: isMobile ? 22 : 24,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(AppConstants.accentColor)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSelected
                          ? const Color(AppConstants.accentColor)
                          : Colors.grey.shade400,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 14,
                        )
                      : null,
                ),

                SizedBox(width: isMobile ? 12 : 14),

                // Avatar
                Container(
                  width: isMobile ? 36 : 38,
                  height: isMobile ? 36 : 38,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(AppConstants.accentColor)
                        : const Color(AppConstants.accentColor)
                            .withOpacity(0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      contact.nameAr.isNotEmpty ? contact.nameAr[0] : 'ع',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: isMobile ? 14 : 15,
                      ),
                    ),
                  ),
                ),

                SizedBox(width: isMobile ? 12 : 14),

                // Contact Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        ArabicTextHelper.cleanText(contact.nameAr),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: isMobile ? 13 : 13,
                          color: const Color(AppConstants.primaryColor),
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'كود: ${contact.code}',
                        style: TextStyle(
                          fontSize: isMobile ? 11 : 11,
                          color: const Color(AppConstants.accentColor),
                          fontWeight: FontWeight.w500,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
