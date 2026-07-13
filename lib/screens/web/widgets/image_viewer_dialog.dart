// lib/screens/web/image_viewer_dialog.dart

import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:jala_as/screens/utils/file_utils.dart';
import '../../../models/new_customer.dart';

class ImageViewerDialog extends StatefulWidget {
  final List<NewCustomerImage> images;
  final String customerName;
  final int initialIndex;

  const ImageViewerDialog({
    super.key,
    required this.images,
    required this.customerName,
    this.initialIndex = 0,
  });

  @override
  State<ImageViewerDialog> createState() => _ImageViewerDialogState();
}

class _ImageViewerDialogState extends State<ImageViewerDialog> {
  late PageController _pageController;
  late int _currentIndex;
  bool _isDownloading = false;
  final TransformationController _transformationController =
      TransformationController();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  /// Download image using cross-platform FileUtils
  Future<void> _downloadImage() async {
    if (_isDownloading) return;

    setState(() {
      _isDownloading = true;
    });

    try {
      final image = widget.images[_currentIndex];
      final imageUrl = image.imageUrl;

      // Fetch image bytes
      final response = await http.get(Uri.parse(imageUrl));

      if (response.statusCode == 200) {
        final imageBytes = response.bodyBytes;

        // Generate filename
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final extension = _getFileExtension(image.imageName);
        final fileName =
            '${widget.customerName}_image_${_currentIndex + 1}_$timestamp$extension';

        // Detect mime type from extension
        final mimeType = _getMimeTypeFromExtension(extension);

        // Download using cross-platform FileUtils
        await FileUtils.instance.downloadFile(
          imageBytes,
          fileName,
          mimeType: mimeType,
        );

        if (mounted) {
          _showSnackBar('تم تحميل الصورة بنجاح', false);
        }
      } else {
        throw Exception('Failed to download image: ${response.statusCode}');
      }
    } catch (e) {
      print('Error downloading image: $e');
      if (mounted) {
        _showSnackBar('فشل في تحميل الصورة', true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  /// Get file extension from filename
  String _getFileExtension(String fileName) {
    if (fileName.contains('.')) {
      return fileName.substring(fileName.lastIndexOf('.'));
    }
    return '.jpg'; // Default to jpg
  }

  /// Get MIME type from file extension
  String _getMimeTypeFromExtension(String extension) {
    switch (extension.toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.bmp':
        return 'image/bmp';
      case '.svg':
        return 'image/svg+xml';
      default:
        return 'image/jpeg'; // Default
    }
  }

  /// Show snackbar message
  void _showSnackBar(String message, bool isError) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  /// Reset zoom on page change
  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 1200,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            _buildHeader(),

            // Image viewer
            Expanded(
              child: _buildImageViewer(),
            ),

            // Footer with navigation
            if (widget.images.length > 1) _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        border: Border(
          bottom: BorderSide(color: const Color(0xFFE1E5E9)),
        ),
      ),
      child: Row(
        children: [
          // Close button
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, size: 24),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF546E7A),
            ),
            tooltip: 'إغلاق',
          ),

          const SizedBox(width: 16),

          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.customerName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2C3E50),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'الصورة ${_currentIndex + 1} من ${widget.images.length}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF546E7A),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // Download button
          ElevatedButton.icon(
            onPressed: _isDownloading ? null : _downloadImage,
            icon: _isDownloading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.download, size: 18),
            label: Text(_isDownloading ? 'جارٍ التحميل...' : 'تحميل'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageViewer() {
    return Container(
      color: const Color(0xFF1E1E1E),
      child: PageView.builder(
        controller: _pageController,
        itemCount: widget.images.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
          _resetZoom();
        },
        itemBuilder: (context, index) {
          final image = widget.images[index];
          return _buildImagePage(image);
        },
      ),
    );
  }

  Widget _buildImagePage(NewCustomerImage image) {
    return InteractiveViewer(
      transformationController: _transformationController,
      minScale: 0.5,
      maxScale: 4.0,
      child: Center(
        child: Image.network(
          image.imageUrl,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;

            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'جارٍ التحميل...',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.broken_image,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'فشل في تحميل الصورة',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        border: Border(
          top: BorderSide(color: const Color(0xFFE1E5E9)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Previous button
          IconButton(
            onPressed: _currentIndex > 0
                ? () {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                : null,
            icon: const Icon(Icons.arrow_back_ios_rounded),
            style: IconButton.styleFrom(
              backgroundColor: _currentIndex > 0
                  ? const Color(0xFF135467)
                  : const Color(0xFFE1E5E9),
              foregroundColor:
                  _currentIndex > 0 ? Colors.white : const Color(0xFF9CA3AF),
              disabledBackgroundColor: const Color(0xFFE1E5E9),
              disabledForegroundColor: const Color(0xFF9CA3AF),
            ),
            tooltip: 'السابق',
          ),

          const SizedBox(width: 24),

          // Page indicators
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE1E5E9)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                widget.images.length > 5 ? 5 : widget.images.length,
                (index) {
                  if (widget.images.length > 5) {
                    // Show first, current-1, current, current+1, last
                    int displayIndex;
                    if (index == 0) {
                      displayIndex = 0;
                    } else if (index == 4) {
                      displayIndex = widget.images.length - 1;
                    } else {
                      displayIndex = (_currentIndex - 1 + index)
                          .clamp(1, widget.images.length - 2);
                    }

                    return _buildPageIndicator(
                        displayIndex, displayIndex == _currentIndex);
                  } else {
                    return _buildPageIndicator(index, index == _currentIndex);
                  }
                },
              ),
            ),
          ),

          const SizedBox(width: 24),

          // Next button
          IconButton(
            onPressed: _currentIndex < widget.images.length - 1
                ? () {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                : null,
            icon: const Icon(Icons.arrow_forward_ios_rounded),
            style: IconButton.styleFrom(
              backgroundColor: _currentIndex < widget.images.length - 1
                  ? const Color(0xFF135467)
                  : const Color(0xFFE1E5E9),
              foregroundColor: _currentIndex < widget.images.length - 1
                  ? Colors.white
                  : const Color(0xFF9CA3AF),
              disabledBackgroundColor: const Color(0xFFE1E5E9),
              disabledForegroundColor: const Color(0xFF9CA3AF),
            ),
            tooltip: 'التالي',
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator(int index, bool isCurrent) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isCurrent ? 32 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isCurrent ? const Color(0xFF135467) : const Color(0xFFE1E5E9),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
