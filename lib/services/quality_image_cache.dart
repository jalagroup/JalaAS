// lib/services/quality_image_cache.dart
//
// Persists checkpoint/general images in sessionStorage so they survive an
// iOS Safari memory-pressure page reload (same-tab reloads keep session
// storage intact).  Images are base64-encoded.  All operations are
// best-effort: quota errors and other failures are silently swallowed so the
// form keeps working without caching.

import 'dart:convert';
import 'dart:html' as html;
import 'package:image_picker/image_picker.dart';

class QualityImageCache {
  // ── public API ─────────────────────────────────────────────────────────────

  /// Stable key for a session derived from checklist ID + user ID.
  static String cacheKey(int checklistId, String userId) =>
      'qic_${checklistId}_$userId';

  /// Serialise [generalImages] and [checkpointImages] to sessionStorage.
  /// Called every time the in-memory image lists change.
  static Future<void> saveImages(
    String key, {
    required List<XFile> generalImages,
    required Map<String, List<XFile>> checkpointImages,
  }) async {
    try {
      final generalData = <Map<String, String>>[];
      for (final f in generalImages) {
        final bytes = await f.readAsBytes();
        generalData.add({'name': f.name, 'data': base64Encode(bytes)});
      }

      final cpData = <String, dynamic>{};
      for (final entry in checkpointImages.entries) {
        if (entry.value.isEmpty) continue;
        final imgs = <Map<String, String>>[];
        for (final f in entry.value) {
          final bytes = await f.readAsBytes();
          imgs.add({'name': f.name, 'data': base64Encode(bytes)});
        }
        cpData[entry.key] = imgs;
      }

      final json =
          jsonEncode({'general': generalData, 'checkpoints': cpData});
      html.window.sessionStorage[key] = json;
    } catch (_) {
      // QuotaExceededError or encoding error — silently skip.
    }
  }

  /// Restore previously cached images.  Returns null if nothing is stored.
  static Future<
      ({
        List<XFile> general,
        Map<String, List<XFile>> checkpoints,
      })?> loadImages(String key) async {
    try {
      final raw = html.window.sessionStorage[key];
      if (raw == null || raw.isEmpty) return null;

      final data = jsonDecode(raw) as Map<String, dynamic>;

      final general = <XFile>[];
      for (final item in (data['general'] as List)) {
        final m = item as Map<String, dynamic>;
        final bytes = base64Decode(m['data'] as String);
        general.add(XFile.fromData(bytes,
            name: m['name'] as String, mimeType: 'image/jpeg'));
      }

      final checkpoints = <String, List<XFile>>{};
      final cpRaw = data['checkpoints'] as Map<String, dynamic>;
      for (final entry in cpRaw.entries) {
        checkpoints[entry.key] = [];
        for (final item in entry.value as List) {
          final m = item as Map<String, dynamic>;
          final bytes = base64Decode(m['data'] as String);
          checkpoints[entry.key]!.add(XFile.fromData(bytes,
              name: m['name'] as String, mimeType: 'image/jpeg'));
        }
      }

      return (general: general, checkpoints: checkpoints);
    } catch (_) {
      return null;
    }
  }

  /// Remove cached images after a successful submit.
  static void clearImages(String key) {
    try {
      html.window.sessionStorage.remove(key);
    } catch (_) {}
  }
}
