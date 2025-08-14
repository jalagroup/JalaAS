// lib/screens/mobile/web_contact_selection_screen.dart
import 'package:flutter/material.dart';
import '../../models/contact.dart';
import '../../models/user.dart';
import '../../services/supabase_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
// MyAppBar is defined locally in this file
import 'web_date_selection_screen.dart';
import 'mobile_login_screen.dart';

class ContactSelectionScreen extends StatefulWidget {
  const ContactSelectionScreen({super.key});

  @override
  State<ContactSelectionScreen> createState() => _ContactSelectionScreenState();
}

class _ContactSelectionScreenState extends State<ContactSelectionScreen> {
  final _searchController = TextEditingController();
  List<Contact> _contacts = [];
  List<Contact> _filteredContacts = [];
  bool _isLoading = true;
  AppUser? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadUserAndContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserAndContacts() async {
    try {
      _currentUser = await SupabaseService.getCurrentUser();

      if (_currentUser == null) {
        _navigateToLogin();
        return;
      }

      await _loadContacts();
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(
          context,
          'فشل في تحميل بيانات المستخدم',
          isError: true,
        );
      }
    }
  }

  Future<void> _loadContacts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      List<Contact> contacts;

      if (_currentUser!.isAdmin) {
        contacts = await SupabaseService.getContacts();
      } else {
        contacts = await SupabaseService.getUserContacts(
          salesman: _currentUser!.salesman,
          area: _currentUser!.area,
        );
      }

      if (mounted) {
        setState(() {
          _contacts = contacts;
          _filteredContacts = contacts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        Helpers.showSnackBar(
          context,
          'فشل في تحميل قائمة العملاء',
          isError: true,
        );
      }
    }
  }

  void _filterContacts(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredContacts = _contacts;
      } else {
        _filteredContacts = _contacts.where((contact) {
          final nameMatch =
              contact.nameAr.toLowerCase().contains(query.toLowerCase());
          final codeMatch =
              contact.code.toLowerCase().contains(query.toLowerCase());
          return nameMatch || codeMatch;
        }).toList();
      }
    });
  }

  void _selectContact(Contact contact) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DateRangeScreen(contact: contact),
      ),
    );
  }

  Future<void> _logout() async {
    try {
      await SupabaseService.signOut();
      await Helpers.setLoggedIn(false);
      await Helpers.clearUserData();
      if (mounted) {
        _navigateToLogin();
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(
          context,
          'فشل في تسجيل الخروج',
          isError: true,
        );
      }
    }
  }

  void _navigateToLogin() {
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const LoginScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _currentUser != null
          ? _MyHomeAppBar(
              currentUser: _currentUser!,
              onLogout: _logout,
              onRefresh: _loadContacts,
            )
          : AppBar(
              title: const Text('اختيار العميل'),
              backgroundColor: const Color(AppConstants.primaryColor),
              foregroundColor: Colors.white,
              automaticallyImplyLeading: false,
            ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: [
              const SizedBox(height: 16),

              // Enhanced Search Field
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 12,
                        spreadRadius: 2,
                        offset: const Offset(0, 0),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _filterContacts,
                    decoration: InputDecoration(
                      labelText: 'البحث عن عميل',
                      hintText: 'ادخل اسم العميل أو رقمه',
                      prefixIcon: Container(
                        margin: const EdgeInsets.all(12),
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: const Color(AppConstants.accentColor),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.search,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: Color(AppConstants.accentColor),
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 13, vertical: 15),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Contact count badge with better styling
              if (_filteredContacts.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(AppConstants.accentColor)
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(
                            color: const Color(AppConstants.accentColor)
                                .withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.people,
                              size: 16,
                              color: const Color(AppConstants.accentColor),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${_filteredContacts.length} عميل',
                              style: const TextStyle(
                                color: Color(AppConstants.accentColor),
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Enhanced Contacts List
              Expanded(
                child: _isLoading
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.06),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                    offset: const Offset(0, 0),
                                  ),
                                ],
                              ),
                              child: const CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(AppConstants.accentColor)),
                                strokeWidth: 3,
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'جاري تحميل العملاء...',
                              style: TextStyle(
                                color: Color(AppConstants.primaryColor),
                                fontWeight: FontWeight.w500,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : _filteredContacts.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(32),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.06),
                                        blurRadius: 20,
                                        spreadRadius: 2,
                                        offset: const Offset(0, 0),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.people_outline,
                                    size: 80,
                                    color: Colors.grey[300],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  _contacts.isEmpty
                                      ? 'لا توجد عملاء'
                                      : 'لا توجد نتائج للبحث',
                                  style: TextStyle(
                                    fontSize: 20,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _contacts.isEmpty
                                      ? 'لم يتم العثور على أي عملاء في النظام'
                                      : 'جرب البحث بكلمات مختلفة',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[500],
                                  ),
                                ),
                                if (_contacts.isEmpty) ...[
                                  const SizedBox(height: 24),
                                  ElevatedButton(
                                    onPressed: _loadContacts,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          const Color(AppConstants.accentColor),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 32, vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(25),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: const Text(
                                      'إعادة التحميل',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 15),
                            child: ListView.builder(
                              itemCount: _filteredContacts.length,
                              itemBuilder: (context, index) {
                                final contact = _filteredContacts[index];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.04),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                        offset: const Offset(0, 0),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () => _selectContact(contact),
                                      borderRadius: BorderRadius.circular(16),
                                      child: Padding(
                                        padding: const EdgeInsets.all(14),
                                        child: Row(
                                          children: [
                                            // Enhanced Avatar
                                            Container(
                                              width: 56,
                                              height: 56,
                                              decoration: BoxDecoration(
                                                color: const Color(
                                                    AppConstants.accentColor),
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: const Color(
                                                            AppConstants
                                                                .accentColor)
                                                        .withOpacity(0.3),
                                                    blurRadius: 8,
                                                    spreadRadius: 0,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: Center(
                                                child: Text(
                                                  contact.nameAr.isNotEmpty
                                                      ? contact.nameAr[0]
                                                      : 'ع',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 22,
                                                  ),
                                                ),
                                              ),
                                            ),

                                            const SizedBox(width: 20),

                                            // Content - Name and Code
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  // Contact Name
                                                  Text(
                                                    contact.nameAr,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 14,
                                                      color: Color(AppConstants
                                                          .primaryColor),
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),

                                                  const SizedBox(height: 8),

                                                  // Contact Code with better styling
                                                  Row(
                                                    children: [
                                                      Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 8,
                                                                vertical: 4),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: const Color(
                                                                  AppConstants
                                                                      .accentColor)
                                                              .withOpacity(0.1),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(8),
                                                        ),
                                                        child: Text(
                                                          '#',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: const Color(
                                                                AppConstants
                                                                    .accentColor),
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        contact.code,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: const Color(
                                                              AppConstants
                                                                  .accentColor),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),

                                            // Enhanced Arrow
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: const Color(AppConstants
                                                        .primaryColor)
                                                    .withOpacity(0.08),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: const Icon(
                                                Icons.arrow_forward_ios,
                                                size: 16,
                                                color: Color(
                                                    AppConstants.primaryColor),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// Update the _MyHomeAppBar class in your ContactSelectionScreen

class _MyHomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final AppUser currentUser;
  final VoidCallback onLogout;
  final VoidCallback onRefresh;

  const _MyHomeAppBar({
    required this.currentUser,
    required this.onLogout,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: 4,
      backgroundColor: const Color(AppConstants.primaryColor),
      // Remove automaticallyImplyLeading: false to show back button
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Row(
        children: [
          // Logo in AppBar with white background
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Image.asset(
              AppConstants.logoPath,
              width: 28,
              height: 28,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(AppConstants.accentColor),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.account_balance,
                    size: 16,
                    color: Colors.white,
                  ),
                );
              },
            ),
          ),

          const SizedBox(width: 12),

          // Title instead of user greeting since we have less space
          const Expanded(
            child: Text(
              'اختيار العميل',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: [
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'logout') {
              onLogout();
            } else if (value == 'refresh') {
              onRefresh();
            }
          },
          icon: const Icon(Icons.more_vert, color: Colors.white),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'refresh',
              child: Row(
                children: [
                  Icon(Icons.refresh, color: Color(AppConstants.accentColor)),
                  SizedBox(width: 8),
                  Text('تحديث'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout, color: Color(AppConstants.errorColor)),
                  SizedBox(width: 8),
                  Text('تسجيل الخروج'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

String getGreetingMessage() {
  final hour = DateTime.now().hour;

  if (hour >= 5 && hour < 12) {
    return 'صباح الخير ☀️';
  } else if (hour >= 12 && hour < 17) {
    return 'مساء الخير 🌤️';
  } else {
    return 'مساء الخير 🌙';
  }
}
