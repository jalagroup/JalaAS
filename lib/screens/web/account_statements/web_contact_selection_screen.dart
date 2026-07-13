// lib/screens/web/web_contact_selection_screen.dart - Light Design
import 'package:flutter/material.dart';
import 'package:jala_as/screens/web/account_statements/web_contact_groups_list_screen.dart';
import '../../../models/user.dart';
import '../../../models/contact.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/helpers.dart';
import '../../../utils/constants.dart';
import '../../../utils/arabic_text_helper.dart';
import 'web_date_selection_screen.dart';
import '../web_login_screen.dart';

class ContactSelectionScreen extends StatefulWidget {
  final AppUser user;

  const ContactSelectionScreen({
    super.key,
    required this.user,
  });

  @override
  State<ContactSelectionScreen> createState() => _ContactSelectionScreenState();
}

// lib/screens/web/web_contact_selection_screen.dart - OPTIMIZED

class _ContactSelectionScreenState extends State<ContactSelectionScreen>
    with AutomaticKeepAliveClientMixin {
  final _searchController = TextEditingController();
  List<Contact> _allContacts = [];
  List<Contact> _filteredContacts = [];
  bool _isLoading = true;
  String _searchQuery = '';
  AppUser? _currentUser;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeScreen();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    try {
      final user = await SupabaseService.getCurrentUser();
      if (user != null && mounted) {
        setState(() => _currentUser = user);
      }
    } catch (e) {
      print('Error getting user: $e');
    } finally {
      await _loadContacts();
    }
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
      final user = _currentUser ?? widget.user;
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

        if (contacts.isNotEmpty) {
          _showSnackBar('تم تحميل ${contacts.length} عميل بنجاح', false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('فشل في تحميل قائمة العملاء', true);
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

  void _selectContact(Contact contact) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            DateSelectionScreen(user: widget.user, contact: contact),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.03, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              )),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  Future<void> _logout() async {
    try {
      await SupabaseService.signOut();
      await Helpers.setLoggedIn(false);
      await Helpers.clearUserData();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const WebLoginScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 200),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('فشل في تسجيل الخروج', true);
      }
    }
  }

  void _navigateToGroups() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            ContactGroupsListScreen(user: widget.user),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.03, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              )),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  int _getCrossAxisCount(double screenWidth) {
    if (screenWidth < 600) return 1;
    if (screenWidth < 900) return 2;
    if (screenWidth < 1200) return 3;
    return 4;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;
    final isMobile = size.width < 768;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: _LightAppBar(
          user: widget.user,
          onLogout: _logout,
          onRefresh: _loadContacts,
          onGroupsPressed: _navigateToGroups,
          isDesktop: isDesktop,
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 1000 : double.infinity,
            ),
            child: Column(
              children: [
                // Search Section
                Padding(
                  padding: EdgeInsets.all(isMobile ? 16 : 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildSearchField(isMobile),
                      if (_filteredContacts.isNotEmpty) ...[
                        SizedBox(height: isMobile ? 12 : 16),
                        _buildResultsCount(isMobile),
                      ],
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: _buildContent(size.width, isDesktop, isMobile),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField(bool isMobile) {
    return TextField(
      controller: _searchController,
      textDirection: TextDirection.rtl,
      decoration: InputDecoration(
        labelText: 'البحث عن عميل',
        hintText: 'ادخل اسم العميل أو رقمه',
        hintTextDirection: TextDirection.rtl,
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
    );
  }

  Widget _buildResultsCount(bool isMobile) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 16,
          vertical: isMobile ? 6 : 8,
        ),
        decoration: BoxDecoration(
          color: const Color(AppConstants.accentColor).withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(AppConstants.accentColor).withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.people,
              size: isMobile ? 14 : 16,
              color: const Color(AppConstants.accentColor),
            ),
            const SizedBox(width: 6),
            Text(
              '${_filteredContacts.length} عميل',
              style: TextStyle(
                color: const Color(AppConstants.accentColor),
                fontWeight: FontWeight.w600,
                fontSize: isMobile ? 12 : 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(double screenWidth, bool isDesktop, bool isMobile) {
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(isMobile ? 24 : 32),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Icon(
                Icons.people_outline,
                size: isMobile ? 60 : 80,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _allContacts.isEmpty ? 'لا توجد عملاء' : 'لا توجد نتائج للبحث',
              style: TextStyle(
                fontSize: isMobile ? 18 : 20,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _allContacts.isEmpty
                  ? 'لم يتم العثور على أي عملاء في النظام'
                  : 'جرب البحث بكلمات مختلفة',
              style: TextStyle(
                fontSize: isMobile ? 14 : 16,
                color: Colors.grey.shade500,
              ),
            ),
            if (_allContacts.isEmpty) ...[
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loadContacts,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(AppConstants.accentColor),
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 24 : 32,
                    vertical: isMobile ? 12 : 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'إعادة التحميل',
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: 8,
      ),
      physics: const BouncingScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _getCrossAxisCount(screenWidth),
        crossAxisSpacing: isMobile ? 12 : 16,
        mainAxisSpacing: isMobile ? 12 : 16,
        mainAxisExtent: isMobile ? 70 : 75,
      ),
      itemCount: _filteredContacts.length,
      itemBuilder: (context, index) {
        final contact = _filteredContacts[index];
        return _LightContactCard(
          key: ValueKey(contact.code),
          contact: contact,
          onTap: () => _selectContact(contact),
          isMobile: isMobile,
        );
      },
    );
  }
}

class _LightContactCard extends StatelessWidget {
  final Contact contact;
  final VoidCallback onTap;
  final bool isMobile;

  const _LightContactCard({
    super.key,
    required this.contact,
    required this.onTap,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
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
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              // Avatar
              Container(
                width: isMobile ? 40 : 42,
                height: isMobile ? 40 : 42,
                decoration: BoxDecoration(
                  color: const Color(AppConstants.accentColor),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    contact.nameAr.isNotEmpty ? contact.nameAr[0] : 'ع',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: isMobile ? 16 : 16,
                    ),
                  ),
                ),
              ),

              SizedBox(width: isMobile ? 12 : 14),

              // Contact Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      ArabicTextHelper.cleanText(contact.nameAr),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: isMobile ? 14 : 13,
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
                        fontSize: isMobile ? 12 : 11,
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

              // Arrow
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.arrow_forward_ios,
                  size: 12,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LightAppBar extends StatelessWidget implements PreferredSizeWidget {
  final AppUser user;
  final VoidCallback onLogout;
  final VoidCallback onRefresh;
  final VoidCallback onGroupsPressed; // NEW
  final bool isDesktop;

  const _LightAppBar({
    required this.user,
    required this.onLogout,
    required this.onRefresh,
    required this.onGroupsPressed, // NEW
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back,
            color: Color(AppConstants.primaryColor)),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: const Text(
        'اختيار العميل',
        style: TextStyle(
          color: Color(AppConstants.primaryColor),
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        // NEW: Groups button
        IconButton(
          icon: const Icon(
            Icons.group,
            color: Color(AppConstants.accentColor),
          ),
          onPressed: onGroupsPressed,
          tooltip: 'مجموعات العملاء',
        ),

        if (isDesktop)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Chip(
              label: Text(
                user.username,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              backgroundColor:
                  const Color(AppConstants.accentColor).withOpacity(0.1),
              side: BorderSide.none,
            ),
          ),
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'logout') {
              onLogout();
            } else if (value == 'refresh') {
              onRefresh();
            }
          },
          icon: const Icon(
            Icons.more_vert,
            color: Color(AppConstants.primaryColor),
          ),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'refresh',
              child: Row(
                children: [
                  Icon(
                    Icons.refresh,
                    color: const Color(AppConstants.accentColor),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  const Text('تحديث'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(
                    Icons.logout,
                    color: Colors.red.shade400,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  const Text('تسجيل الخروج'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
