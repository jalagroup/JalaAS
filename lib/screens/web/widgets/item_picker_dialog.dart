// lib/screens/web/item_picker_dialog.dart - IMPROVED VERSION WITH SEARCH

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:jala_as/models/returns_models.dart';
import 'dart:ui' as ui;

class ItemPickerDialog extends StatefulWidget {
  final List<Item> items;

  const ItemPickerDialog({
    Key? key,
    required this.items,
  }) : super(key: key);

  @override
  State<ItemPickerDialog> createState() => _ItemPickerDialogState();
}

class _ItemPickerDialogState extends State<ItemPickerDialog> {
  late final TextEditingController _searchController;
  late List<Item> _filteredItems;
  Timer? _debounceTimer;

  // Cached styles
  static const _primaryColor = Color(0xFF135467);

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _filteredItems = widget.items;
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _filterItems(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) return;

      setState(() {
        if (query.trim().isEmpty) {
          _filteredItems = widget.items;
        } else {
          final lowerQuery = query.toLowerCase().trim();
          _filteredItems = widget.items.where((item) {
            final code = item.code.toLowerCase();
            final nameAr = item.nameAr.toLowerCase();
            final nameEn = (item.nameEn ?? '').toLowerCase();

            return code.contains(lowerQuery) ||
                nameAr.contains(lowerQuery) ||
                nameEn.contains(lowerQuery);
          }).toList();
        }
      });
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _filteredItems = widget.items);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth =
        screenSize.width > 600 ? 580.0 : screenSize.width * 0.95;
    final dialogHeight = screenSize.height * 0.9;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Container(
          width: dialogWidth,
          height: dialogHeight,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              // Header
              _buildHeader(),

              // Search field
              _buildSearchField(),

              // Divider
              Divider(height: 1, color: Colors.grey.shade200),

              // Items count
              _buildItemsCount(),

              // Items list
              Expanded(child: _buildItemsList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _primaryColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.inventory_2, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'اختيار صنف',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: TextField(
        controller: _searchController,
        onChanged: _filterItems,
        textDirection: ui.TextDirection.rtl,
        decoration: InputDecoration(
            hintText: 'ابحث بالكود أو اسم الصنف...',
            hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            prefixIcon: const Icon(Icons.search, color: _primaryColor),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    onPressed: _clearSearch,
                    icon: Icon(Icons.clear,
                        color: Colors.grey.shade600, size: 20),
                  )
                : null,
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _primaryColor, width: 2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            isDense: true),
        style: const TextStyle(fontSize: 14),
        autofocus: true,
      ),
    );
  }

  Widget _buildItemsCount() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey.shade50,
      child: Row(
        children: [
          Icon(Icons.list, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text(
            _searchController.text.isEmpty
                ? 'إجمالي الأصناف: ${widget.items.length}'
                : 'نتائج البحث: ${_filteredItems.length} من ${widget.items.length}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList() {
    if (_filteredItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد نتائج',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'جرب البحث بكلمات مختلفة',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: _filteredItems.length,
      itemBuilder: (context, index) {
        final item = _filteredItems[index];
        return _ItemListTile(
          item: item,
          searchQuery: _searchController.text,
          onTap: () => Navigator.pop(context, item),
          isLast: index == _filteredItems.length - 1,
        );
      },
    );
  }
}

// Separate widget for item tile to improve performance
class _ItemListTile extends StatelessWidget {
  final Item item;
  final String searchQuery;
  final VoidCallback onTap;
  final bool isLast;

  const _ItemListTile({
    required this.item,
    required this.searchQuery,
    required this.onTap,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: !isLast
              ? Border(bottom: BorderSide(color: Colors.grey.shade200))
              : null,
        ),
        child: Row(
          children: [
            // Item icon
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: const Color(0xFF135467).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Icon(
                  Icons.inventory,
                  color: Color(0xFF135467),
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Item details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Code and Name in one line
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: item.code,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF135467),
                            fontFamily: 'monospace',
                          ),
                        ),
                        TextSpan(
                          text: ' - ',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade400,
                          ),
                        ),
                        TextSpan(
                          text: item.nameAr,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Arrow indicator
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}
