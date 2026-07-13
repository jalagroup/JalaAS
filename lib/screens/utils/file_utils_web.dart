// lib/utils/file_utils_web.dart

import 'dart:convert';
import 'dart:typed_data';
import 'dart:html' as html;
import 'dart:async';
import 'file_utils.dart';

class FileUtilsImpl extends FileUtils {
  void _safeComplete<T>(Completer<T> c, T value) {
    if (!c.isCompleted) c.complete(value);
  }

  @override
  Future<List<Uint8List>> pickImages() async {
    final completer = Completer<List<Uint8List>>();

    final uploadInput = html.FileUploadInputElement()
      ..multiple = true
      ..accept = 'image/*'
      ..style.display = 'none';

    html.document.body?.children.add(uploadInput);

    StreamSubscription<html.Event>? changeSub;
    StreamSubscription<html.Event>? visibilitySub;
    StreamSubscription<html.Event>? focusSub;
    StreamSubscription<html.Event>? touchSub;
    Timer? cancelTimer;
    Timer? touchSetupTimer;
    bool fileSelected = false;

    void cleanup() {
      changeSub?.cancel();
      visibilitySub?.cancel();
      focusSub?.cancel();
      touchSub?.cancel();
      cancelTimer?.cancel();
      touchSetupTimer?.cancel();
      try {
        uploadInput.remove();
      } catch (_) {}
    }

    // Called when the browser signals the file picker has closed (select OR
    // cancel). Waits 2 s for onChange to fire before treating as cancellation.
    // Android needs this grace period to deliver onChange for multiple files.
    void onPickerClosed() {
      if (fileSelected || completer.isCompleted) return;
      cancelTimer?.cancel();
      cancelTimer = Timer(const Duration(milliseconds: 2000), () {
        if (!fileSelected) {
          cleanup();
          _safeComplete(completer, <Uint8List>[]);
        }
      });
    }

    changeSub = uploadInput.onChange.listen((event) async {
      fileSelected = true;
      visibilitySub?.cancel();
      focusSub?.cancel();
      touchSub?.cancel();
      cancelTimer?.cancel();
      touchSetupTimer?.cancel();

      final files = uploadInput.files;
      if (files == null || files.isEmpty) {
        cleanup();
        _safeComplete(completer, <Uint8List>[]);
        return;
      }

      // Sequential reads keep peak memory low on iOS Safari.
      final result = <Uint8List>[];
      for (final file in files) {
        final bytes = await readFileAsBytes(file);
        if (bytes != null) result.add(bytes);
      }
      cleanup();
      _safeComplete(completer, result);
    });

    // Android / iPad: visibilitychange fires when the picker sheet closes.
    visibilitySub = html.document.onVisibilityChange.listen((_) {
      if (html.document.visibilityState == 'visible') onPickerClosed();
    });

    // Desktop fallback: window regains focus when the picker dialog closes.
    focusSub = html.window.onFocus.listen((_) => onPickerClosed());

    // iOS Safari: the picker opens as a system sheet — neither visibilitychange
    // nor window focus fires. The user's first touch after dismissing the
    // picker is the only reliable signal. We start listening 300 ms after the
    // click so the triggering tap itself is not captured.
    uploadInput.click();
    touchSetupTimer = Timer(const Duration(milliseconds: 300), () {
      if (completer.isCompleted || fileSelected) return;
      touchSub = html.document.onTouchStart.listen((_) {
        touchSub?.cancel();
        onPickerClosed();
      });
    });

    return completer.future;
  }

  @override
  Future<Uint8List?> pickSingleImage() async {
    final completer = Completer<Uint8List?>();

    final uploadInput = html.FileUploadInputElement()
      ..accept = 'image/*'
      ..style.display = 'none';

    html.document.body?.children.add(uploadInput);

    StreamSubscription<html.Event>? changeSub;
    StreamSubscription<html.Event>? visibilitySub;
    StreamSubscription<html.Event>? focusSub;
    StreamSubscription<html.Event>? touchSub;
    Timer? cancelTimer;
    Timer? touchSetupTimer;
    bool fileSelected = false;

    void cleanup() {
      changeSub?.cancel();
      visibilitySub?.cancel();
      focusSub?.cancel();
      touchSub?.cancel();
      cancelTimer?.cancel();
      touchSetupTimer?.cancel();
      try {
        uploadInput.remove();
      } catch (_) {}
    }

    void onPickerClosed() {
      if (fileSelected || completer.isCompleted) return;
      cancelTimer?.cancel();
      cancelTimer = Timer(const Duration(milliseconds: 2000), () {
        if (!fileSelected) {
          cleanup();
          _safeComplete(completer, null);
        }
      });
    }

    changeSub = uploadInput.onChange.listen((event) async {
      fileSelected = true;
      visibilitySub?.cancel();
      focusSub?.cancel();
      touchSub?.cancel();
      cancelTimer?.cancel();
      touchSetupTimer?.cancel();

      final files = uploadInput.files;
      if (files == null || files.isEmpty) {
        cleanup();
        _safeComplete(completer, null);
        return;
      }
      final bytes = await readFileAsBytes(files[0]);
      cleanup();
      _safeComplete(completer, bytes);
    });

    visibilitySub = html.document.onVisibilityChange.listen((_) {
      if (html.document.visibilityState == 'visible') onPickerClosed();
    });

    focusSub = html.window.onFocus.listen((_) => onPickerClosed());

    uploadInput.click();
    touchSetupTimer = Timer(const Duration(milliseconds: 300), () {
      if (completer.isCompleted || fileSelected) return;
      touchSub = html.document.onTouchStart.listen((_) {
        touchSub?.cancel();
        onPickerClosed();
      });
    });

    return completer.future;
  }

  @override
  Future<void> downloadFile(Uint8List bytes, String filename,
      {String? mimeType}) async {
    final blob = html.Blob([bytes], mimeType ?? 'application/octet-stream');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.document.createElement('a') as html.AnchorElement
      ..href = url
      ..download = filename
      ..style.display = 'none';

    html.document.body?.children.add(anchor);
    anchor.click();
    html.document.body?.children.remove(anchor);
    html.Url.revokeObjectUrl(url);
  }

  @override
  Future<Uint8List?> readFileAsBytes(dynamic file) async {
    if (file is! html.File) return null;

    final completer = Completer<Uint8List?>();
    final reader = html.FileReader();

    reader.onLoadEnd.listen((event) {
      if (reader.readyState == html.FileReader.DONE) {
        completer.complete(reader.result as Uint8List?);
      }
    });

    reader.onError.listen((event) {
      completer.complete(null);
    });

    reader.readAsArrayBuffer(file);
    return completer.future;
  }
}

FileUtils getFileUtils() => FileUtilsImpl();
