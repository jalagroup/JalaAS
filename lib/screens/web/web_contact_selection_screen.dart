// lib/screens/web/web_contact_selection_screen.dart
import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../models/contact.dart';
import '../../services/supabase_service.dart';
import '../../utils/helpers.dart';
import '../../utils/constants.dart';
import '../../utils/arabic_text_helper.dart';
import 'web_date_selection_screen.dart';
import 'web_login_screen.dart';

class ContactSelectionScreen extends StatefulWidget {
  final AppUser user;

  const ContactSelectionScreen({
    super.key,
    required this.user,
  });

  @override
  State<ContactSelectionScreen> createState() => _ContactSelectionScreenState();
}

class _ContactSelectionScreenState extends State<ContactSelectionScreen> {
  final _searchController = TextEditingController();
  List<Contact> _allContacts = [];
  List<Contact> _filteredContacts = [];
  bool _isLoading = true;
  String _searchQuery = '';

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
      setState(() {
        _isLoading = true;
      });

      List<Contact> contacts;
      if (widget.user.isAdmin) {
        contacts = await SupabaseService.getContacts();
      } else {
        print('----------------------s');
        print(widget.user.salesman);
        print('----------------------a');
        print(widget.user.area);

        contacts = await SupabaseService.getUserContacts(
          salesman: widget.user.salesman,
          area: widget.user.area,
        );
      }

      if (mounted) {
        setState(() {
          _allContacts = contacts;
          _filteredContacts = contacts;
          _isLoading = false;
        });

        if (contacts.isNotEmpty) {
          Helpers.showSnackBar(
            context,
            'تم تحميل ${contacts.length} عميل بنجاح',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        Helpers.showSnackBar(
          context,
          'فشل في تحميل قائمة العملاء: ${e.toString()}',
          isError: true,
        );
      }
    }
  }

  void _selectContact(Contact contact) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DateSelectionScreen(
          user: widget.user,
          contact: contact,
        ),
      ),
    );
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'تسجيل الخروج',
            style: TextStyle(
              color: Color(AppConstants.primaryColor),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text('هل تريد تسجيل الخروج؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text(
                'إلغاء',
                style: TextStyle(color: Color(AppConstants.primaryColor)),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(AppConstants.accentColor),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'تسجيل الخروج',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      try {
        await SupabaseService.signOut();
        await Helpers.setLoggedIn(false);
        await Helpers.clearUserData();
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const WebLoginScreen(),
            ),
          );
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
  }

  int _getCrossAxisCount(double screenWidth) {
    if (screenWidth < 600) return 1; // Mobile
    if (screenWidth < 900) return 2; // Tablet
    if (screenWidth < 1200) return 3; // Small desktop
    if (screenWidth < 1600) return 4; // Medium desktop
    return 5; // Large desktop
  }

  String _getGreetingMessage() {
    final hour = DateTime.now().hour;

    if (hour >= 5 && hour < 12) {
      return 'صباح الخير ☀️';
    } else if (hour >= 12 && hour < 17) {
      return 'مساء الخير 🌤️';
    } else {
      return 'مساء الخير 🌙';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: _WebAppBar(
          user: widget.user,
          onLogout: _logout,
          onRefresh: _loadContacts,
          greeting: _getGreetingMessage(),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 1400 : double.infinity,
            ),
            child: Column(
              children: [
                const SizedBox(height: 16),

                // Enhanced Search Section
                Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 20),
                  child: Column(
                    children: [
                      // Search Field
                      Container(
                        constraints: BoxConstraints(
                          maxWidth: isDesktop ? 800 : double.infinity,
                        ),
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
                          textDirection: TextDirection.rtl,
                          decoration: InputDecoration(
                            labelText: 'البحث عن عميل',
                            hintText: 'ادخل اسم العميل أو رقمه',
                            hintTextDirection: TextDirection.rtl,
                            prefixIcon: Container(
                              margin: const EdgeInsets.all(12),
                              padding: const EdgeInsets.all(8),
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
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.clear,
                                      color: Color(AppConstants.primaryColor),
                                    ),
                                    onPressed: () {
                                      _searchController.clear();
                                    },
                                  )
                                : null,
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
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: isDesktop ? 20 : 16,
                              vertical: isDesktop ? 14 : 12,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Contact count badge
                      if (_filteredContacts.isNotEmpty) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isDesktop ? 20 : 16,
                                vertical: isDesktop ? 10 : 8,
                              ),
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
                                    size: isDesktop ? 18 : 16,
                                    color:
                                        const Color(AppConstants.accentColor),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${_filteredContacts.length} عميل',
                                    style: TextStyle(
                                      color:
                                          const Color(AppConstants.accentColor),
                                      fontWeight: FontWeight.w600,
                                      fontSize: isDesktop ? 14 : 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: _isLoading
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: EdgeInsets.all(isDesktop ? 32 : 24),
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
                              const SizedBox(height: 16),
                              Text(
                                'جاري تحميل العملاء...',
                                style: TextStyle(
                                  color: const Color(AppConstants.primaryColor),
                                  fontWeight: FontWeight.w500,
                                  fontSize: isDesktop ? 18 : 16,
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
                                    padding:
                                        EdgeInsets.all(isDesktop ? 40 : 32),
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
                                      size: isDesktop ? 100 : 80,
                                      color: Colors.grey[300],
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    _allContacts.isEmpty
                                        ? 'لا توجد عملاء'
                                        : 'لا توجد نتائج للبحث',
                                    style: TextStyle(
                                      fontSize: isDesktop ? 24 : 20,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _allContacts.isEmpty
                                        ? 'لم يتم العثور على أي عملاء في النظام'
                                        : 'جرب البحث بكلمات مختلفة',
                                    style: TextStyle(
                                      fontSize: isDesktop ? 16 : 14,
                                      color: Colors.grey[500],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  if (_allContacts.isEmpty) ...[
                                    const SizedBox(height: 24),
                                    ElevatedButton(
                                      onPressed: _loadContacts,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                            AppConstants.accentColor),
                                        padding: EdgeInsets.symmetric(
                                          horizontal: isDesktop ? 40 : 32,
                                          vertical: isDesktop ? 16 : 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(25),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: Text(
                                        'إعادة التحميل',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: isDesktop ? 16 : 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            )
                          : Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: isDesktop ? 32 : 20,
                                vertical: 8,
                              ),
                              child: GridView.builder(
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount:
                                      _getCrossAxisCount(screenWidth),
                                  crossAxisSpacing: isDesktop ? 16 : 12,
                                  mainAxisSpacing: isDesktop ? 16 : 12,
                                  childAspectRatio: isDesktop ? 2.8 : 3.5,
                                ),
                                itemCount: _filteredContacts.length,
                                itemBuilder: (context, index) {
                                  final contact = _filteredContacts[index];
                                  return _ContactCard(
                                    contact: contact,
                                    onTap: () => _selectContact(contact),
                                    isDesktop: isDesktop,
                                  );
                                },
                              ),
                            ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WebAppBar extends StatelessWidget implements PreferredSizeWidget {
  final AppUser user;
  final VoidCallback onLogout;
  final VoidCallback onRefresh;
  final String greeting;

  const _WebAppBar({
    required this.user,
    required this.onLogout,
    required this.onRefresh,
    required this.greeting,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AppBar(
        elevation: 4,
        backgroundColor: const Color(AppConstants.primaryColor),
        automaticallyImplyLeading: false,
        toolbarHeight: kToolbarHeight,
        title: Padding(
          padding: EdgeInsets.symmetric(horizontal: isDesktop ? 16 : 8),
          child: Row(
            children: [
              // Back Button
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                  ),
                  iconSize: isDesktop ? 24 : 22,
                  tooltip: 'العودة للرئيسية',
                ),
              ),

              SizedBox(width: isDesktop ? 12 : 8),

              // Logo with white background
              Container(
                padding: EdgeInsets.all(isDesktop ? 8 : 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Image.asset(
                  AppConstants.logoPath,
                  width: isDesktop ? 32 : 28,
                  height: isDesktop ? 32 : 28,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: isDesktop ? 32 : 28,
                      height: isDesktop ? 32 : 28,
                      decoration: BoxDecoration(
                        color: const Color(AppConstants.accentColor),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.account_balance,
                        size: isDesktop ? 18 : 16,
                        color: Colors.white,
                      ),
                    );
                  },
                ),
              ),

              SizedBox(width: isDesktop ? 16 : 12),

              // Title
              const Expanded(
                child: Text(
                  'اختيار العميل',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // User info for desktop
              if (isDesktop) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.person,
                        size: 16,
                        color: Colors.white.withOpacity(0.9),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        user.username,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(left: isDesktop ? 16 : 12),
            child: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'logout') {
                  onLogout();
                } else if (value == 'refresh') {
                  onRefresh();
                }
              },
              icon: const Icon(
                Icons.more_vert,
                color: Colors.white,
                size: 20,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'refresh',
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: Row(
                      children: [
                        Icon(
                          Icons.refresh,
                          color: const Color(AppConstants.accentColor),
                          size: 18,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'تحديث',
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
                PopupMenuItem(
                  value: 'logout',
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: Row(
                      children: [
                        Icon(
                          Icons.logout,
                          color: const Color(AppConstants.errorColor),
                          size: 18,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'تسجيل الخروج',
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _ContactCard extends StatefulWidget {
  final Contact contact;
  final VoidCallback onTap;
  final bool isDesktop;

  const _ContactCard({
    required this.contact,
    required this.onTap,
    required this.isDesktop,
  });

  @override
  State<_ContactCard> createState() => _ContactCardState();
}

class _ContactCardState extends State<_ContactCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: EdgeInsets.all(widget.isDesktop ? 8 : 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isHovered
                        ? const Color(AppConstants.accentColor)
                        : Colors.transparent,
                    width: _isHovered ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(_isHovered ? 0.08 : 0.04),
                      blurRadius: _isHovered ? 12 : 8,
                      spreadRadius: _isHovered ? 2 : 1,
                      offset: const Offset(0, 0),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Enhanced Avatar
                    Container(
                      width: widget.isDesktop ? 48 : 48,
                      height: widget.isDesktop ? 48 : 48,
                      decoration: BoxDecoration(
                        color: const Color(AppConstants.accentColor),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(AppConstants.accentColor)
                                .withOpacity(0.3),
                            blurRadius: 6,
                            spreadRadius: 0,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          widget.contact.nameAr.isNotEmpty
                              ? widget.contact.nameAr[0]
                              : 'ع',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: widget.isDesktop ? 18 : 18,
                          ),
                        ),
                      ),
                    ),

                    SizedBox(width: widget.isDesktop ? 16 : 14),

                    // Contact Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Contact Name
                          Flexible(
                            child: Text(
                              ArabicTextHelper.cleanText(widget.contact.nameAr),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: widget.isDesktop ? 13 : 14,
                                color: const Color(AppConstants.primaryColor),
                                height: 1.1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                          SizedBox(height: widget.isDesktop ? 6 : 8),

                          // Contact Code with better styling
                          Flexible(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: widget.isDesktop ? 6 : 8,
                                    vertical: widget.isDesktop ? 3 : 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(AppConstants.accentColor)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '#',
                                    style: TextStyle(
                                      fontSize: widget.isDesktop ? 9 : 10,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          const Color(AppConstants.accentColor),
                                    ),
                                  ),
                                ),
                                SizedBox(width: widget.isDesktop ? 6 : 8),
                                Flexible(
                                  child: Text(
                                    widget.contact.code,
                                    style: TextStyle(
                                      fontSize: widget.isDesktop ? 11 : 12,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          const Color(AppConstants.accentColor),
                                      height: 1.1,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Area info for desktop - only if there's space
                          if (widget.contact.area != null &&
                              widget.isDesktop) ...[
                            SizedBox(height: 4),
                            Flexible(
                              child: Text(
                                'المنطقة: ${widget.contact.area}',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w400,
                                  height: 1.1,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Enhanced Arrow
                    Container(
                      padding: EdgeInsets.all(widget.isDesktop ? 8 : 10),
                      decoration: BoxDecoration(
                        color: const Color(AppConstants.primaryColor)
                            .withOpacity(_isHovered ? 0.12 : 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.arrow_back_ios,
                        size: widget.isDesktop ? 14 : 16,
                        color: _isHovered
                            ? const Color(AppConstants.accentColor)
                            : const Color(AppConstants.primaryColor),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
