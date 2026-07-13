// lib/screens/web/assign_additional_contacts_dialog.dart - NEW FILE

import 'package:flutter/material.dart';
import '../../../models/user.dart';
import '../../../models/contact.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/helpers.dart';
import '../../../utils/arabic_text_helper.dart';
import '../../../utils/constants.dart';

class AssignAdditionalContactsDialog extends StatefulWidget {
  final AppUser user;

  const AssignAdditionalContactsDialog({
    super.key,
    required this.user,
  });

  @override
  State<AssignAdditionalContactsDialog> createState() =>
      _AssignAdditionalContactsDialogState();
}

class _AssignAdditionalContactsDialogState
    extends State<AssignAdditionalContactsDialog> {
  final _searchController = TextEditingController();
  List<Contact> _allContacts = [];
  List<Contact> _filteredContacts = [];
  Set<String> _selectedContactCodes = {};
  bool _isLoading = true;
  String _searchQuery = '';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
      _filterContacts();
    });
  }

  void _filterContacts() {
    if (_searchQuery.isEmpty) {
      _filteredContacts = _allContacts;
    } else {
      _filteredContacts = _allContacts.where((contact) {
        final nameMatch =
            contact.nameAr.toLowerCase().contains(_searchQuery.toLowerCase());
        final codeMatch =
            contact.code.toLowerCase().contains(_searchQuery.toLowerCase());
        return nameMatch || codeMatch;
      }).toList();
    }
  }

  Future<void> _loadContacts() async {
    try {
      setState(() => _isLoading = true);

      // Get contacts that user cannot see by default
      final contacts = await SupabaseService.getContactsNotVisibleToUser(
        userSalesman: widget.user.salesman,
        userArea: widget.user.area,
      );

      // Get currently assigned additional contacts
      final currentlyAssigned =
          await SupabaseService.getUserAdditionalContacts(widget.user.id);

      if (mounted) {
        setState(() {
          _allContacts = contacts;
          _filteredContacts = contacts;
          _selectedContactCodes = Set.from(currentlyAssigned);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        Helpers.showSnackBar(
          context,
          'فشل في تحميل العملاء: ${e.toString()}',
          isError: true,
        );
      }
    }
  }

  void _toggleContact(String contactCode) {
    setState(() {
      if (_selectedContactCodes.contains(contactCode)) {
        _selectedContactCodes.remove(contactCode);
      } else {
        _selectedContactCodes.add(contactCode);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedContactCodes = Set.from(_filteredContacts.map((c) => c.code));
    });
  }

  void _selectNone() {
    setState(() {
      _selectedContactCodes.clear();
    });
  }

  Future<void> _saveAssignments() async {
    try {
      setState(() => _isSaving = true);

      await SupabaseService.assignAdditionalContactsToUser(
        userId: widget.user.id,
        contactCodes: _selectedContactCodes.toList(),
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        Helpers.showSnackBar(
          context,
          'تم تعيين العملاء الإضافيين بنجاح',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        Helpers.showSnackBar(
          context,
          'فشل في تعيين العملاء: ${e.toString()}',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 600;
    final dialogWidth = isMobile ? screenSize.width - 32 : 700.0;
    final maxHeight = screenSize.height - 80;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : (screenSize.width - 700) / 2,
          vertical: 40,
        ),
        child: Container(
          width: dialogWidth,
          constraints: BoxConstraints(
            maxHeight: maxHeight,
            maxWidth: dialogWidth,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(isMobile ? 16 : 20),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'تعيين عملاء إضافيين',
                            style: TextStyle(
                              fontSize: isMobile ? 16 : 18,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF2C3E50),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'المستخدم: ${widget.user.username}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF546E7A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF135467).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.person_add,
                        color: Color(0xFF135467),
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),

              // Selected count and actions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFE1E5E9)),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF135467).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            size: 16,
                            color: Color(0xFF135467),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'محدد: ${_selectedContactCodes.length}',
                            style: const TextStyle(
                              color: Color(0xFF135467),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _selectAll,
                      child: const Text(
                        'تحديد الكل',
                        style: TextStyle(
                          color: Color(0xFF135467),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _selectNone,
                      child: const Text(
                        'إلغاء الكل',
                        style: TextStyle(
                          color: Color(0xFF546E7A),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Search field
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: TextField(
                    controller: _searchController,
                    textDirection: TextDirection.rtl,
                    decoration: InputDecoration(
                      labelText: 'البحث عن عميل',
                      hintText: 'ادخل اسم العميل أو رقمه',
                      hintTextDirection: TextDirection.rtl,
                      prefixIcon: Container(
                        margin: const EdgeInsets.all(8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF135467),
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
                              icon: const Icon(
                                Icons.clear,
                                color: Colors.grey,
                              ),
                              onPressed: () => _searchController.clear(),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                  ),
                ),
              ),

              // Contacts list
              Expanded(
                child: _buildContactsList(),
              ),

              // Footer
              Container(
                padding: EdgeInsets.all(isMobile ? 16 : 20),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: _isSaving
                            ? null
                            : () => Navigator.of(context).pop(false),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF546E7A),
                          padding: EdgeInsets.symmetric(
                            vertical: isMobile ? 10 : 12,
                          ),
                        ),
                        child: const Text('إلغاء'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveAssignments,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF135467),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: EdgeInsets.symmetric(
                            vertical: isMobile ? 10 : 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('حفظ التعيينات'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactsList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF135467),
          strokeWidth: 2,
        ),
      );
    }

    if (_filteredContacts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Icon(
                Icons.people_outline,
                size: 60,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _allContacts.isEmpty
                  ? 'لا توجد عملاء إضافية متاحة'
                  : 'لا توجد نتائج للبحث',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _allContacts.isEmpty
                  ? 'جميع العملاء مخصصون بالفعل'
                  : 'جرب البحث بكلمات مختلفة',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _filteredContacts.length,
      itemBuilder: (context, index) {
        final contact = _filteredContacts[index];
        final isSelected = _selectedContactCodes.contains(contact.code);

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF135467).withOpacity(0.05)
                : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color:
                  isSelected ? const Color(0xFF135467) : Colors.grey.shade200,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: CheckboxListTile(
            value: isSelected,
            onChanged: (value) => _toggleContact(contact.code),
            title: Text(
              ArabicTextHelper.cleanText(contact.nameAr),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: isSelected
                    ? const Color(0xFF135467)
                    : const Color(0xFF2C3E50),
              ),
            ),
            subtitle: Row(
              children: [
                Text(
                  'كود: ${contact.code}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF546E7A),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF16936).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'مندوب: ${contact.salesman}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFFF16936),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            activeColor: const Color(0xFF135467),
            checkColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 4,
            ),
            dense: true,
          ),
        );
      },
    );
  }
}
