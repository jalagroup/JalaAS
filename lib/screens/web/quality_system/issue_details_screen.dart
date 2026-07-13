// lib/screens/web/quality_system/issue_details_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jala_as/models/quality_models.dart';
import 'package:jala_as/screens/utils/file_utils.dart';
import '../../../models/user.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/constants.dart';
import '../../../utils/helpers.dart';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';

class IssueDetailsScreen extends StatefulWidget {
  final QualityCheckpointIssue issue;
  final AppUser user;

  const IssueDetailsScreen({
    super.key,
    required this.issue,
    required this.user,
  });

  @override
  State<IssueDetailsScreen> createState() => _IssueDetailsScreenState();
}

class _IssueDetailsScreenState extends State<IssueDetailsScreen> {
  late QualityCheckpointIssue _issue;
  final _resolutionController = TextEditingController();
  final List<Uint8List> _resolutionImageBytes = [];
  final List<String> _resolutionImageNames = [];
  bool _isResolving = false;
  bool _isPickingImages = false;

  @override
  void initState() {
    super.initState();
    _issue = widget.issue;
  }

  @override
  void dispose() {
    _resolutionController.dispose();
    super.dispose();
  }

  Future<void> _pickResolutionImages() async {
    if (_isPickingImages) return;

    setState(() => _isPickingImages = true);

    try {
      final fileUtils = FileUtils.instance;
      final imagesBytesList = await fileUtils.pickImages();

      if (imagesBytesList.isEmpty) {
        if (mounted) {
          Helpers.showSnackBar(context, 'لم يتم اختيار أي صور');
        }
        return;
      }

      setState(() {
        for (int i = 0; i < imagesBytesList.length; i++) {
          _resolutionImageBytes.add(imagesBytesList[i]);
          _resolutionImageNames.add(
              'resolution_${DateTime.now().millisecondsSinceEpoch}_$i.jpg');
        }
      });

      if (mounted) {
        Helpers.showSnackBar(
            context, 'تم إضافة ${imagesBytesList.length} صورة بنجاح');
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(context, 'فشل في اختيار الصور', isError: true);
      }
    } finally {
      setState(() => _isPickingImages = false);
    }
  }

  Future<void> _resolveIssue() async {
    if (_resolutionController.text.trim().isEmpty) {
      Helpers.showSnackBar(context, 'يرجى إدخال تقرير الحل', isError: true);
      return;
    }

    setState(() => _isResolving = true);

    try {
      final resolvedIssue = await SupabaseService.resolveIssue(
        issueId: _issue.id,
        resolutionNotes: _resolutionController.text.trim(),
        resolutionImageBytes:
            _resolutionImageBytes.isNotEmpty ? _resolutionImageBytes : null,
        resolutionImageNames:
            _resolutionImageNames.isNotEmpty ? _resolutionImageNames : null,
      );

      if (mounted) {
        Helpers.showSnackBar(context, 'تم حل المشكلة بنجاح');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(context, 'فشل في حل المشكلة: $e', isError: true);
      }
    } finally {
      setState(() => _isResolving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back,
                color: Color(AppConstants.primaryColor)),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'تفاصيل المشكلة',
            style: TextStyle(
              color: Color(AppConstants.primaryColor),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Issue Info Card
              _buildIssueInfoCard(isMobile),
              const SizedBox(height: 16),

              // Issue Images
              if (_issue.issueImages.isNotEmpty) ...[
                _buildIssueImagesSection(isMobile),
                const SizedBox(height: 16),
              ],

              // Resolution Section
              if (_issue.status != IssueStatus.resolved) ...[
                _buildResolutionSection(isMobile),
              ] else ...[
                _buildResolvedSection(isMobile),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIssueInfoCard(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _issue.formTitle,
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 18,
                    fontWeight: FontWeight.w600,
                    color: const Color(AppConstants.primaryColor),
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatusColor(_issue.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _issue.status.displayText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _getStatusColor(_issue.status),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.check_circle_outline, 'نقطة الفحص',
              _issue.checkPointTitle, isMobile),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.calendar_today, 'تاريخ التقييم',
              DateFormat('yyyy-MM-dd').format(_issue.responseDate), isMobile),
          const SizedBox(height: 8),
          _buildInfoRow(
              Icons.access_time,
              'تاريخ الإنشاء',
              DateFormat('yyyy-MM-dd HH:mm').format(_issue.createdAt),
              isMobile),
          const Divider(height: 24),
          Text(
            'وصف المشكلة',
            style: TextStyle(
              fontSize: isMobile ? 14 : 16,
              fontWeight: FontWeight.w600,
              color: const Color(AppConstants.primaryColor),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _issue.description,
            style: TextStyle(
              fontSize: isMobile ? 13 : 14,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
      IconData icon, String label, String value, bool isMobile) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: isMobile ? 13 : 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: isMobile ? 13 : 14,
              color: Colors.grey.shade600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIssueImagesSection(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'صور المشكلة',
            style: TextStyle(
              fontSize: isMobile ? 14 : 16,
              fontWeight: FontWeight.w600,
              color: const Color(AppConstants.primaryColor),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _issue.issueImages.length,
              itemBuilder: (context, index) {
                final image = _issue.issueImages[index];
                return GestureDetector(
                  onTap: () => _showImageDialog(image.imageUrl),
                  child: Container(
                    width: 100,
                    height: 100,
                    margin: const EdgeInsets.only(left: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        image.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.broken_image),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResolutionSection(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'حل المشكلة',
            style: TextStyle(
              fontSize: isMobile ? 16 : 18,
              fontWeight: FontWeight.w600,
              color: const Color(AppConstants.primaryColor),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _resolutionController,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: 'تقرير الحل',
              hintText: 'اكتب تقريراً مفصلاً عن كيفية حل المشكلة...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: Color(AppConstants.accentColor),
                  width: 2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _isPickingImages ? null : _pickResolutionImages,
            icon: _isPickingImages
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_photo_alternate),
            label: Text(_isPickingImages
                ? 'جارٍ التحميل...'
                : 'إضافة صور الحل (اختياري)'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          if (_resolutionImageBytes.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _resolutionImageBytes.length,
                itemBuilder: (context, index) {
                  return Stack(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        margin: const EdgeInsets.only(left: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            _resolutionImageBytes[index],
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _resolutionImageBytes.removeAt(index);
                              _resolutionImageNames.removeAt(index);
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isResolving ? null : _resolveIssue,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _isResolving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('تأكيد الحل'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResolvedSection(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 24),
              const SizedBox(width: 8),
              Text(
                'تم حل المشكلة',
                style: TextStyle(
                  fontSize: isMobile ? 16 : 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade900,
                ),
              ),
            ],
          ),
          if (_issue.resolvedAt != null) ...[
            const SizedBox(height: 8),
            Text(
              'تاريخ الحل: ${DateFormat('yyyy-MM-dd HH:mm').format(_issue.resolvedAt!)}',
              style: TextStyle(
                fontSize: isMobile ? 12 : 13,
                color: Colors.green.shade700,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'تقرير الحل:',
            style: TextStyle(
              fontSize: isMobile ? 14 : 16,
              fontWeight: FontWeight.w600,
              color: Colors.green.shade900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _issue.resolutionNotes ?? 'لا يوجد تقرير',
            style: TextStyle(
              fontSize: isMobile ? 13 : 14,
              color: Colors.green.shade800,
            ),
          ),
          if (_issue.resolutionImages.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'صور الحل:',
              style: TextStyle(
                fontSize: isMobile ? 14 : 16,
                fontWeight: FontWeight.w600,
                color: Colors.green.shade900,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _issue.resolutionImages.length,
                itemBuilder: (context, index) {
                  final image = _issue.resolutionImages[index];
                  return GestureDetector(
                    onTap: () => _showImageDialog(image.imageUrl),
                    child: Container(
                      width: 100,
                      height: 100,
                      margin: const EdgeInsets.only(left: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade300),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          image.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.broken_image),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showImageDialog(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('عرض الصورة'),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Expanded(
              child: InteractiveViewer(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Icon(Icons.broken_image, size: 48),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(IssueStatus status) {
    switch (status) {
      case IssueStatus.open:
        return Colors.orange;
      case IssueStatus.inProgress:
        return Colors.blue;
      case IssueStatus.resolved:
        return Colors.green;
    }
  }
}
