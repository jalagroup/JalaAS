// lib/services/pdf_service.dart - Complete Enhanced Version with Language Chunks
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:jala_as/models/contact_group.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/contact.dart';
import '../models/account_statement.dart';
import '../utils/arabic_text_helper.dart';
import 'package:jala_as/models/returns_models.dart';

// ==================== CHARACTER TYPE ENUMERATION ====================

/// Character type enumeration for better classification
enum _CharType {
  arabic,
  english,
  number,
  symbol,
  space,
  other,
}

enum WordType {
  arabic,
  english,
  number,
  numberSequence,
  symbol,
  separator,
}

/// Data class for customer information lines
class CustomerDataLine {
  final String label;
  final String value;
  final bool isSection;
  final bool hasValue;

  CustomerDataLine({
    required this.label,
    required this.value,
    this.isSection = false,
    this.hasValue = true,
  });
}

class ProcessedWord {
  final String content;
  final WordType type;
  final pw.TextDirection direction;

  ProcessedWord({
    required this.content,
    required this.type,
    required this.direction,
  });
}

class ProcessedChunk {
  final List<ProcessedWord> words;
  final pw.TextDirection direction;
  final String content;
  final String dominantLanguage; // 'arabic', 'english', 'mixed', 'neutral'

  ProcessedChunk({
    required this.words,
    required this.direction,
    required this.content,
    required this.dominantLanguage,
  });
}

class ProcessedSentence {
  final List<ProcessedChunk> chunks;
  final String originalText;

  ProcessedSentence({
    required this.chunks,
    required this.originalText,
  });
}

class PdfService {
  // Font cache for performance
  static pw.Font? _arabicFont;
  static pw.Font? _arabicBoldFont;
  static pw.Font? _englishFont;
  static pw.Font? _englishBoldFont;

// Updated _loadFonts method - use local fonts instead of Google Fonts
  static Future<void> _loadFonts() async {
    if (_arabicFont == null) {
      // Load local fonts from assets
      final arabicRegularData =
          await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf');
      final arabicBoldData =
          await rootBundle.load('assets/fonts/NotoSansArabic-Bold.ttf');
      final englishRegularData = await rootBundle.load(
          'assets/fonts/NotoSansArabic-Regular.ttf'); // Use Arabic font for English too
      final englishBoldData = await rootBundle.load(
          'assets/fonts/NotoSansArabic-Bold.ttf'); // Use Arabic font for English too

      _arabicFont = pw.Font.ttf(arabicRegularData);
      _arabicBoldFont = pw.Font.ttf(arabicBoldData);
      _englishFont = pw.Font.ttf(englishRegularData);
      _englishBoldFont = pw.Font.ttf(englishBoldData);
    }
  }

  // ==================== ENHANCED TEXT SEPARATION WITH LANGUAGE CHUNKS ====================

  /// Enhanced process text by creating language-based chunks with separate directions
  static ProcessedSentence _processTextWithLanguageChunks(String text) {
    if (text.trim().isEmpty) {
      return ProcessedSentence(
        chunks: [],
        originalText: text,
      );
    }

    text = text.trim();

    // First, apply intelligent text separation for mixed languages and symbols
    String separatedText = _intelligentTextSeparation(text);

    // Then tokenize the separated text
    List<String> tokens = _tokenizeTextWithNumberSequences(separatedText);
    List<ProcessedWord> allWords = [];

    for (String token in tokens) {
      if (token.trim().isEmpty) continue;

      WordType type = _determineWordType(token);
      pw.TextDirection direction = _getDirectionForWordType(type);

      allWords.add(ProcessedWord(
        content: token,
        type: type,
        direction: direction,
      ));
    }

    // Group words into language-based chunks
    List<ProcessedChunk> chunks = _createLanguageChunks(allWords);

    return ProcessedSentence(
      chunks: chunks,
      originalText: text,
    );
  }

  /// Create language-based chunks from processed words
  static List<ProcessedChunk> _createLanguageChunks(List<ProcessedWord> words) {
    if (words.isEmpty) return [];

    List<ProcessedChunk> chunks = [];
    List<ProcessedWord> currentChunk = [];
    String currentLanguage = '';

    for (int i = 0; i < words.length; i++) {
      ProcessedWord word = words[i];
      String wordLanguage = _getWordLanguage(word);

      // Start new chunk if language changes (but keep symbols with their context)
      if (currentLanguage.isNotEmpty &&
          _shouldStartNewChunk(
              currentLanguage, wordLanguage, word, currentChunk)) {
        // Finish current chunk
        if (currentChunk.isNotEmpty) {
          chunks.add(_createChunk(currentChunk, currentLanguage));
          currentChunk = [];
        }
        currentLanguage = wordLanguage;
      } else if (currentLanguage.isEmpty) {
        currentLanguage = wordLanguage;
      }

      currentChunk.add(word);
    }

    // Add final chunk
    if (currentChunk.isNotEmpty) {
      chunks.add(_createChunk(currentChunk, currentLanguage));
    }

    return chunks;
  }

  /// Determine the language of a word for chunking purposes
  static String _getWordLanguage(ProcessedWord word) {
    switch (word.type) {
      case WordType.arabic:
        return 'arabic';
      case WordType.english:
        return 'english';
      case WordType.number:
      case WordType.numberSequence:
        return 'number';
      case WordType.symbol:
      case WordType.separator:
        return 'symbol';
      default:
        return 'neutral';
    }
  }

  /// Determine if we should start a new chunk
  static bool _shouldStartNewChunk(
      String currentLanguage,
      String newWordLanguage,
      ProcessedWord newWord,
      List<ProcessedWord> currentChunk) {
    // ALWAYS break for symbols - treat each symbol as a separate chunk
    if (newWordLanguage == 'symbol') {
      return true;
    }

    // ALWAYS break when we encounter a symbol in current chunk
    if (currentLanguage == 'symbol') {
      return true;
    }

    // Never break for numbers - they stick with the previous language
    if (newWordLanguage == 'number') {
      return false;
    }

    // Break when switching between actual languages (arabic <-> english)
    if ((currentLanguage == 'arabic' && newWordLanguage == 'english') ||
        (currentLanguage == 'english' && newWordLanguage == 'arabic')) {
      return true;
    }

    // If current chunk only has numbers, adopt the new language
    if (currentLanguage == 'number') {
      return false;
    }

    return false;
  }

  /// Create a chunk from a list of words
  static ProcessedChunk _createChunk(
      List<ProcessedWord> words, String dominantLanguage) {
    if (words.isEmpty) {
      return ProcessedChunk(
        words: [],
        direction: pw.TextDirection.rtl,
        content: '',
        dominantLanguage: 'neutral',
      );
    }

    // Determine chunk direction based on dominant language
    pw.TextDirection chunkDirection =
        _getChunkDirection(words, dominantLanguage);

    // Build content string
    String content = words.map((w) => w.content).join(' ');

    // Analyze the actual language distribution in the chunk
    String analyzedLanguage = _analyzeChunkLanguage(words);

    return ProcessedChunk(
      words: words,
      direction: chunkDirection,
      content: content,
      dominantLanguage: analyzedLanguage,
    );
  }

  /// Determine direction for a chunk based on its content
  static pw.TextDirection _getChunkDirection(
      List<ProcessedWord> words, String dominantLanguage) {
    // Count actual language content
    int arabicWords = words.where((w) => w.type == WordType.arabic).length;
    int englishWords = words.where((w) => w.type == WordType.english).length;

    // If we have clear language dominance
    if (arabicWords > englishWords) {
      return pw.TextDirection.rtl;
    } else if (englishWords > arabicWords) {
      return pw.TextDirection.ltr;
    }

    // If equal or no clear language, use the dominant language hint
    switch (dominantLanguage) {
      case 'arabic':
        return pw.TextDirection.rtl;
      case 'english':
        return pw.TextDirection.ltr;
      default:
        // For symbols/numbers, use RTL as default in Arabic context
        return pw.TextDirection.rtl;
    }
  }

  /// Analyze the actual language distribution in a chunk
  static String _analyzeChunkLanguage(List<ProcessedWord> words) {
    int arabicWords = words.where((w) => w.type == WordType.arabic).length;
    int englishWords = words.where((w) => w.type == WordType.english).length;
    int numberWords = words
        .where((w) =>
            w.type == WordType.number || w.type == WordType.numberSequence)
        .length;
    int symbolWords = words
        .where((w) => w.type == WordType.symbol || w.type == WordType.separator)
        .length;

    if (arabicWords > 0 && englishWords > 0) {
      return 'mixed';
    } else if (arabicWords > 0) {
      return 'arabic';
    } else if (englishWords > 0) {
      return 'english';
    } else if (numberWords > 0) {
      return 'number';
    } else if (symbolWords > 0) {
      return 'symbol';
    } else {
      return 'neutral';
    }
  }

  /// Generate multiple PDFs for group account statements
  static Future<Map<String, Uint8List>> generateGroupAccountStatementPdfs({
    required List<ContactStatementResult> results,
    required String fromDate,
    required String toDate,
    Function(int current, int total, String contactName)? onProgress,
  }) async {
    final pdfs = <String, Uint8List>{};
    int current = 0;

    for (final result in results) {
      current++;
      if (onProgress != null) {
        onProgress(current, results.length, result.contact.nameAr);
      }

      if (result.success && result.statements.isNotEmpty) {
        try {
          final pdfBytes = await generateAccountStatementPdf(
            contact: result.contact,
            statements: result.statements,
            fromDate: fromDate,
            toDate: toDate,
          );

          // Use contact code as key for unique identification
          pdfs[result.contact.code] = pdfBytes;
        } catch (e) {
          print('Error generating PDF for ${result.contact.nameAr}: $e');
        }
      }
    }

    return pdfs;
  }

  /// Generate Sales Return PDF for small thermal printers (58mm, 80mm)
  static Future<Uint8List> generateSalesReturnPdf({
    required String returnCode,
    required String contactCode,
    required String contactName,
    required String returnDate,
    required String returnReasonName,
    required String warehouseCode,
    required String warehouseName,
    required List<ReturnItem> items,
    required String username,
    String? comment,
    double paperWidth = 80, // 80mm default, can be 58mm or 80mm
  }) async {
    // ✅ CRITICAL FIX: Load fonts using the class method
    await _loadFonts();

    final pdf = pw.Document();

    // Calculate width in points (1mm = 2.83465 points)
    final pageWidth = paperWidth * 2.83465;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          pageWidth,
          double.infinity,
          marginAll: 5 * 2.83465, // 5mm margins
        ),
        textDirection: pw.TextDirection.rtl,
        // ✅ CRITICAL FIX: Use the cached fonts with fallback
        theme: pw.ThemeData.withFont(
          base: _arabicFont!,
          bold: _arabicBoldFont!,
          fontFallback: [
            _arabicFont!,
            _arabicBoldFont!,
            _englishFont!,
            _englishBoldFont!,
          ],
        ),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Center(
                child: pw.Text(
                  'مرتجع مبيعات',
                  style: pw.TextStyle(
                    font: _arabicBoldFont!,
                    fontSize: paperWidth >= 80 ? 16 : 14,
                    fontWeight: pw.FontWeight.bold,
                    fontFallback: [_arabicFont!, _englishFont!],
                  ),
                  textDirection: pw.TextDirection.rtl,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Divider(thickness: 1),
              pw.SizedBox(height: 3),

              // Return Info
              _buildPdfRow('رقم المرتجع:', returnCode, paperWidth),
              _buildPdfRow('التاريخ:', returnDate, paperWidth),
              pw.SizedBox(height: 3),

              // Contact Info
              _buildPdfRow('كود الدليل:', contactCode, paperWidth),
              _buildPdfRow('اسم الدليل:', _cleanText(contactName), paperWidth),
              pw.SizedBox(height: 3),

              // Warehouse & Reason
              _buildPdfRow(
                  'المخزن:',
                  '$warehouseCode - ${_cleanText(warehouseName ?? '')}',
                  paperWidth),
              _buildPdfRow(
                  'سبب الإرجاع:', _cleanText(returnReasonName), paperWidth),

              pw.SizedBox(height: 3),
              pw.Divider(thickness: 1),
              pw.SizedBox(height: 3),

              // Items Header
              pw.Text(
                'الأصناف:',
                style: pw.TextStyle(
                  font: _arabicBoldFont!,
                  fontSize: paperWidth >= 80 ? 10 : 9,
                  fontWeight: pw.FontWeight.bold,
                  fontFallback: [_arabicFont!],
                ),
                textDirection: pw.TextDirection.rtl,
              ),
              pw.SizedBox(height: 2),

              // Items List
              ...items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      '${index + 1}. ${_cleanText(item.itemName ?? item.itemCode ?? 'غير محدد')}',
                      style: pw.TextStyle(
                        font: _arabicFont!,
                        fontSize: paperWidth >= 80 ? 9 : 8,
                        fontFallback: [_arabicBoldFont!, _englishFont!],
                      ),
                      textDirection: pw.TextDirection.rtl,
                    ),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'الكمية: ${item.quantity.toStringAsFixed(2)}',
                          style: pw.TextStyle(
                            font: _arabicFont!,
                            fontSize: paperWidth >= 80 ? 8 : 7,
                            fontFallback: [_englishFont!],
                          ),
                          textDirection: pw.TextDirection.rtl,
                        ),
                        pw.Text(
                          'الكود: ${item.itemCode ?? '-'}',
                          style: pw.TextStyle(
                            font: _arabicFont!,
                            fontSize: paperWidth >= 80 ? 8 : 7,
                            fontFallback: [_englishFont!],
                          ),
                          textDirection: pw.TextDirection.rtl,
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 2),
                  ],
                );
              }).toList(),

              pw.SizedBox(height: 3),
              pw.Divider(thickness: 1),
              pw.SizedBox(height: 3),

              // Summary
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'إجمالي الأصناف: ${items.length}',
                    style: pw.TextStyle(
                      font: _arabicBoldFont!,
                      fontSize: paperWidth >= 80 ? 9 : 8,
                      fontWeight: pw.FontWeight.bold,
                      fontFallback: [_arabicFont!, _englishFont!],
                    ),
                    textDirection: pw.TextDirection.rtl,
                  ),
                  pw.Text(
                    'إجمالي الكمية: ${items.fold(0.0, (sum, item) => sum + item.quantity).toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      font: _arabicBoldFont!,
                      fontSize: paperWidth >= 80 ? 9 : 8,
                      fontWeight: pw.FontWeight.bold,
                      fontFallback: [_arabicFont!, _englishFont!],
                    ),
                    textDirection: pw.TextDirection.rtl,
                  ),
                ],
              ),

              // Comment
              if (comment != null && comment.isNotEmpty) ...[
                pw.SizedBox(height: 3),
                pw.Divider(thickness: 1),
                pw.SizedBox(height: 3),
                pw.Text(
                  'ملاحظة:',
                  style: pw.TextStyle(
                    font: _arabicBoldFont!,
                    fontSize: paperWidth >= 80 ? 9 : 8,
                    fontWeight: pw.FontWeight.bold,
                    fontFallback: [_arabicFont!],
                  ),
                  textDirection: pw.TextDirection.rtl,
                ),
                pw.Text(
                  _cleanText(comment),
                  style: pw.TextStyle(
                    font: _arabicFont!,
                    fontSize: paperWidth >= 80 ? 8 : 7,
                    fontFallback: [_arabicBoldFont!],
                  ),
                  textDirection: pw.TextDirection.rtl,
                ),
              ],

              pw.SizedBox(height: 5),
              pw.Divider(thickness: 1),
              pw.SizedBox(height: 3),

              // Footer
              pw.Center(
                child: pw.Text(
                  'المستخدم: ${_cleanText(username)}',
                  style: pw.TextStyle(
                    font: _arabicFont!,
                    fontSize: paperWidth >= 80 ? 8 : 7,
                    fontFallback: [_arabicBoldFont!, _englishFont!],
                  ),
                  textDirection: pw.TextDirection.rtl,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Center(
                child: pw.Text(
                  DateTime.now().toString().substring(0, 19),
                  style: pw.TextStyle(
                    font: _englishFont!,
                    fontSize: paperWidth >= 80 ? 7 : 6,
                    fontFallback: [_arabicFont!],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

// ✅ UPDATED: _buildPdfRow method - removed font parameter
  static pw.Widget _buildPdfRow(
    String label,
    String value,
    double paperWidth,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: paperWidth >= 80 ? 60 : 50,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                font: _arabicBoldFont!,
                fontSize: paperWidth >= 80 ? 9 : 8,
                fontWeight: pw.FontWeight.bold,
                fontFallback: [_arabicFont!, _englishFont!],
              ),
              textDirection: pw.TextDirection.rtl,
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                font: _arabicFont!,
                fontSize: paperWidth >= 80 ? 9 : 8,
                fontFallback: [_arabicBoldFont!, _englishFont!],
              ),
              textDirection: pw.TextDirection.rtl,
            ),
          ),
        ],
      ),
    );
  }

  /// Generate single PDF from contact statement result
  static Future<Uint8List> generateSingleContactPdf({
    required ContactStatementResult result,
    required String fromDate,
    required String toDate,
  }) async {
    return await generateAccountStatementPdf(
      contact: result.contact,
      statements: result.statements,
      fromDate: fromDate,
      toDate: toDate,
    );
  }

  /// Legacy method for backward compatibility
  static List<ProcessedWord> _processTextByWords(String text) {
    ProcessedSentence sentence = _processTextWithLanguageChunks(text);
    // Flatten all chunks into a single word list
    List<ProcessedWord> allWords = [];
    for (ProcessedChunk chunk in sentence.chunks) {
      allWords.addAll(chunk.words);
    }
    return allWords;
  }

  /// Intelligent text separation for mixed languages and symbols
  static String _intelligentTextSeparation(String text) {
    if (text.isEmpty) return text;

    StringBuffer result = StringBuffer();
    int i = 0;

    while (i < text.length) {
      String currentChar = text[i];

      // If we encounter a transition point, add space
      if (i > 0 && _shouldAddSpaceAt(text, i)) {
        result.write(' ');
      }

      result.write(currentChar);
      i++;
    }

    // Clean up multiple spaces
    return result.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Determine if a space should be added at the current position
  static bool _shouldAddSpaceAt(String text, int position) {
    if (position <= 0 || position >= text.length) return false;

    String prevChar = text[position - 1];
    String currentChar = text[position];

    // Get character types
    _CharType prevType = _getCharacterType(prevChar);
    _CharType currentType = _getCharacterType(currentChar);

    // Don't add space if previous character is already a space
    if (prevChar == ' ') return false;

    // Add space between different language scripts
    if (_isDifferentLanguageTransition(prevType, currentType)) {
      return true;
    }

    // Add space before and after symbols (except within number sequences)
    if (_isSymbolTransition(prevType, currentType, text, position)) {
      return true;
    }

    return false;
  }

  /// Check if there's a transition between different languages
  static bool _isDifferentLanguageTransition(
      _CharType prevType, _CharType currentType) {
    // Arabic to English/Number
    if (prevType == _CharType.arabic &&
        (currentType == _CharType.english || currentType == _CharType.number)) {
      return true;
    }

    // English to Arabic
    if (prevType == _CharType.english && currentType == _CharType.arabic) {
      return true;
    }

    // Number to Arabic (but not to English - numbers and English can be together)
    if (prevType == _CharType.number && currentType == _CharType.arabic) {
      return true;
    }

    return false;
  }

  /// Check if there's a symbol transition that needs spacing
  static bool _isSymbolTransition(
      _CharType prevType, _CharType currentType, String text, int position) {
    // Add space before symbols (except if it's part of a number sequence)
    if (currentType == _CharType.symbol &&
        !_isPartOfNumberSequence(text, position)) {
      return true;
    }

    // Add space after symbols (except if it's part of a number sequence)
    if (prevType == _CharType.symbol &&
        !_isPartOfNumberSequence(text, position - 1)) {
      return true;
    }

    return false;
  }

  /// Check if a symbol at given position is part of a number sequence
  static bool _isPartOfNumberSequence(String text, int position) {
    if (position < 0 || position >= text.length) return false;

    String char = text[position];
    if (!_isNumberSequenceChar(char)) return false;

    // Look for digits before and after the symbol
    bool hasDigitBefore = false;
    bool hasDigitAfter = false;

    // Check before (within reasonable distance)
    for (int i = position - 1; i >= 0 && i >= position - 5; i--) {
      String checkChar = text[i];
      if (RegExp(r'\d').hasMatch(checkChar)) {
        hasDigitBefore = true;
        break;
      }
      if (!_isNumberSequenceChar(checkChar)) break;
    }

    // Check after (within reasonable distance)
    for (int i = position + 1; i < text.length && i <= position + 5; i++) {
      String checkChar = text[i];
      if (RegExp(r'\d').hasMatch(checkChar)) {
        hasDigitAfter = true;
        break;
      }
      if (!_isNumberSequenceChar(checkChar)) break;
    }

    return hasDigitBefore && hasDigitAfter;
  }

  /// Get the type of a character
  static _CharType _getCharacterType(String char) {
    if (char == ' ') return _CharType.space;
    if (RegExp(r'[\u0600-\u06FF]').hasMatch(char)) return _CharType.arabic;
    if (RegExp(r'[a-zA-Z]').hasMatch(char)) return _CharType.english;
    if (RegExp(r'[0-9]').hasMatch(char)) return _CharType.number;
    if (_isSymbolChar(char)) return _CharType.symbol;
    return _CharType.other;
  }

  /// Check if character is a symbol that should be separated
  static bool _isSymbolChar(String char) {
    return char == '/' ||
        char == '\\' ||
        char == '&' ||
        char == '+' ||
        char == '-' ||
        char == '*' ||
        char == '#' ||
        char == '@' ||
        char == '%' ||
        char == '|' ||
        char == '=' ||
        char == '<' ||
        char == '>' ||
        char == '!' ||
        char == '?' ||
        char == ':' ||
        char == ';' ||
        char == ',' ||
        char == '.' ||
        char == '(' ||
        char == ')' ||
        char == '[' ||
        char == ']' ||
        char == '{' ||
        char == '}';
  }

  // ==================== ADVANCED NUMBER SEQUENCE DETECTION ====================

  /// Advanced tokenization that identifies and preserves number sequences
  static List<String> _tokenizeTextWithNumberSequences(String text) {
    List<String> tokens = [];
    int i = 0;

    while (i < text.length) {
      // Skip spaces at the beginning
      while (i < text.length && text[i] == ' ') {
        i++;
      }

      if (i >= text.length) break;

      // Check if we're starting a number sequence
      if (_isNumberSequenceStart(text, i)) {
        String numberSequence = _extractNumberSequence(text, i);
        tokens.add(numberSequence);
        i += numberSequence.length;
      } else {
        // Extract regular word
        String word = _extractRegularWord(text, i);
        tokens.add(word);
        i += word.length;
      }
    }

    return tokens;
  }

  /// Check if position starts a number sequence
  static bool _isNumberSequenceStart(String text, int position) {
    if (position >= text.length) return false;

    // Must start with a digit
    return RegExp(r'\d').hasMatch(text[position]);
  }

  /// Extract a complete number sequence from the given position
  static String _extractNumberSequence(String text, int startPos) {
    StringBuffer sequence = StringBuffer();
    int i = startPos;
    bool hasDigit = false;

    while (i < text.length) {
      String char = text[i];

      if (RegExp(r'\d').hasMatch(char)) {
        // Always include digits
        sequence.write(char);
        hasDigit = true;
        i++;
      } else if (_isNumberSequenceChar(char) && hasDigit) {
        // Include spaces, symbols, separators if we have digits
        // Look ahead to see if there are more digits coming
        if (_hasDigitsAhead(text, i + 1)) {
          sequence.write(char);
          i++;
        } else {
          // No more digits ahead, stop here
          break;
        }
      } else {
        // Not a number sequence character, stop
        break;
      }
    }

    return sequence.toString();
  }

  /// Check if character can be part of a number sequence
  static bool _isNumberSequenceChar(String char) {
    return char == ' ' || // Spaces: "123 456"
        char == '/' || // Slashes: "123/456"
        char == '-' || // Dashes: "123-456"
        char == '.' || // Dots: "123.456"
        char == ':' || // Colons: "12:30"
        char == '(' || // Parentheses: "(123)"
        char == ')' ||
        char == '+' || // Plus: "+123"
        char == '#' || // Hash: "#123"
        char == '*' || // Asterisk: "*123"
        char == ',' || // Comma: "1,234"
        char == ';'; // Semicolon: "123;456"
  }

  /// Check if there are digits ahead in the text
  static bool _hasDigitsAhead(String text, int position) {
    for (int i = position; i < text.length && i < position + 10; i++) {
      String char = text[i];
      if (RegExp(r'\d').hasMatch(char)) {
        return true;
      }
      if (!_isNumberSequenceChar(char)) {
        break; // Hit a non-sequence character
      }
    }
    return false;
  }

  /// Extract a regular (non-number-sequence) word
  static String _extractRegularWord(String text, int startPos) {
    StringBuffer word = StringBuffer();
    int i = startPos;

    while (i < text.length) {
      String char = text[i];

      if (char == ' ') {
        break; // Stop at space for regular words
      } else if (_isSeparator(char)) {
        // If we haven't collected anything yet, include the separator
        if (word.isEmpty) {
          word.write(char);
          i++;
        }
        break;
      } else if (RegExp(r'\d').hasMatch(char)) {
        // If we hit a digit, this might be start of number sequence
        // Only include if we already have content
        if (word.isNotEmpty) {
          break;
        } else {
          // This shouldn't happen due to our logic, but just in case
          word.write(char);
          i++;
        }
      } else {
        word.write(char);
        i++;
      }
    }

    return word.toString();
  }

  /// Enhanced word type determination with number sequence detection
  static WordType _determineWordType(String token) {
    if (_isSeparator(token)) return WordType.separator;

    // Check for number sequences first
    if (_isNumberSequence(token)) {
      return WordType.numberSequence;
    }

    int arabicChars = 0;
    int englishChars = 0;
    int numberChars = 0;
    int totalChars = 0;

    for (int i = 0; i < token.length; i++) {
      String char = token[i];
      if (char == ' ' || _isNumberSequenceChar(char))
        continue; // Skip in counting

      totalChars++;

      if (RegExp(r'[\u0600-\u06FF]').hasMatch(char)) {
        arabicChars++;
      } else if (RegExp(r'[a-zA-Z]').hasMatch(char)) {
        englishChars++;
      } else if (RegExp(r'[0-9]').hasMatch(char)) {
        numberChars++;
      }
    }

    if (totalChars == 0) return WordType.symbol;

    // Determine primary type
    if (arabicChars > 0 && englishChars == 0) return WordType.arabic;
    if (englishChars > 0 && arabicChars == 0) return WordType.english;
    if (numberChars == totalChars) return WordType.number;
    if (numberChars > 0) return WordType.number;

    return WordType.symbol;
  }

  /// Check if token is a number sequence
  static bool _isNumberSequence(String token) {
    // Must contain at least one digit
    if (!RegExp(r'\d').hasMatch(token)) return false;

    // Check if all characters are either digits or valid number sequence characters
    for (int i = 0; i < token.length; i++) {
      String char = token[i];
      if (!RegExp(r'\d').hasMatch(char) && !_isNumberSequenceChar(char)) {
        return false;
      }
    }

    return true;
  }

  /// Enhanced direction determination
  static pw.TextDirection _getDirectionForWordType(WordType type) {
    switch (type) {
      case WordType.arabic:
        return pw.TextDirection.rtl;
      case WordType.english:
      case WordType.number:
      case WordType.numberSequence:
      case WordType.symbol:
      case WordType.separator:
      default:
        return pw.TextDirection.ltr;
    }
  }

  /// Check if character is a separator (restrictive definition)
  static bool _isSeparator(String char) {
    return char == '|' || char == '\\';
  }

  // ==================== ENHANCED WIDGET CREATION WITH LANGUAGE CHUNKS ====================

  /// Create text widget with language-based chunks (each chunk has its own direction)
  static pw.Widget createWordLevelTextWidget(
    String text, {
    bool isBold = false,
    double fontSize = 10,
    pw.TextAlign? textAlign,
    bool useLanguageChunks = true, // NEW: Use language chunks by default
  }) {
    if (useLanguageChunks) {
      return createLanguageChunksTextWidget(
        text,
        isBold: isBold,
        fontSize: fontSize,
        textAlign: textAlign,
      );
    } else {
      // Fallback to original word-level processing
      return _createOriginalWordLevelTextWidget(
        text,
        isBold: isBold,
        fontSize: fontSize,
        textAlign: textAlign,
      );
    }
  }

  /// Create text widget with language-based chunks
  static pw.Widget createLanguageChunksTextWidget(
    String text, {
    bool isBold = false,
    double fontSize = 10,
    pw.TextAlign? textAlign,
  }) {
    ProcessedSentence sentence = _processTextWithLanguageChunks(text);

    if (sentence.chunks.isEmpty) {
      return pw.Text('');
    }

    // If only one chunk, create simple directional text widget
    if (sentence.chunks.length == 1) {
      ProcessedChunk chunk = sentence.chunks.first;
      return _createChunkWidget(chunk,
          isBold: isBold, fontSize: fontSize, textAlign: textAlign);
    }

    // For multiple chunks, create a row of directional chunks
    List<pw.Widget> chunkWidgets = [];

    for (int i = 0; i < sentence.chunks.length; i++) {
      ProcessedChunk chunk = sentence.chunks[i];

      // Add the chunk widget
      chunkWidgets
          .add(_createChunkWidget(chunk, isBold: isBold, fontSize: fontSize));

      // Add space between chunks (except for the last chunk)
      if (i < sentence.chunks.length - 1) {
        chunkWidgets.add(pw.SizedBox(
            width: fontSize * 0.5)); // Slightly larger space between chunks
      }
    }

    // Use Row to display chunks side by side
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      mainAxisAlignment: _getRowMainAxisAlignment(textAlign),
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: chunkWidgets,
    );
  }

  /// Create a widget for a single language chunk
  static pw.Widget _createChunkWidget(
    ProcessedChunk chunk, {
    bool isBold = false,
    double fontSize = 10,
    pw.TextAlign? textAlign,
  }) {
    if (chunk.words.isEmpty) {
      return pw.Container();
    }

    // If chunk has only one word, create simple text
    if (chunk.words.length == 1) {
      ProcessedWord word = chunk.words.first;
      return pw.Text(
        word.content,
        style: _getStyleForWordType(
          word.type,
          word.content,
          isBold: isBold,
          fontSize: fontSize,
        ),
        textDirection: chunk.direction, // Use chunk direction
      );
    }

    // For multiple words in chunk, create directional row
    List<pw.Widget> wordWidgets = [];

    for (int i = 0; i < chunk.words.length; i++) {
      ProcessedWord word = chunk.words[i];

      // Add the word widget
      wordWidgets.add(
        pw.Text(
          word.content,
          style: _getStyleForWordType(
            word.type,
            word.content,
            isBold: isBold,
            fontSize: fontSize,
          ),
          textDirection: word
              .direction, // Individual word direction for proper font rendering
        ),
      );

      // Add space between words within chunk
      if (i < chunk.words.length - 1) {
        if (word.type != WordType.separator &&
            (i + 1 < chunk.words.length &&
                chunk.words[i + 1].type != WordType.separator)) {
          wordWidgets.add(pw.SizedBox(width: fontSize * 0.25));
        }
      }
    }

    // DON'T reverse the words - just use the chunk direction for the container
    return pw.Directionality(
      textDirection: chunk.direction,
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        mainAxisAlignment: chunk.direction == pw.TextDirection.rtl
            ? pw.MainAxisAlignment.end
            : pw.MainAxisAlignment.start,
        children: wordWidgets, // Keep original order, don't reverse
      ),
    );
  }

  /// Get appropriate MainAxisAlignment for row based on textAlign
  static pw.MainAxisAlignment _getRowMainAxisAlignment(
      pw.TextAlign? textAlign) {
    switch (textAlign) {
      case pw.TextAlign.center:
        return pw.MainAxisAlignment.center;
      case pw.TextAlign.left:
        return pw.MainAxisAlignment.start;
      case pw.TextAlign.right:
        return pw.MainAxisAlignment.end;
      default:
        return pw.MainAxisAlignment.start; // Default to start for mixed content
    }
  }

  /// Backward compatibility methods
  static pw.Widget createSentenceDirectionTextWidget(
    String text, {
    bool isBold = false,
    double fontSize = 10,
    pw.TextAlign? textAlign,
  }) {
    // Redirect to language chunks method
    return createLanguageChunksTextWidget(
      text,
      isBold: isBold,
      fontSize: fontSize,
      textAlign: textAlign,
    );
  }

  /// Original word-level text widget creation (for backward compatibility)
  static pw.Widget _createOriginalWordLevelTextWidget(
    String text, {
    bool isBold = false,
    double fontSize = 10,
    pw.TextAlign? textAlign,
  }) {
    List<ProcessedWord> words = _processTextByWords(text);

    if (words.isEmpty) {
      return pw.Text('');
    }

    // If only one word, create simple text widget
    if (words.length == 1) {
      ProcessedWord word = words.first;
      return pw.Text(
        word.content,
        style: _getStyleForWordType(
          word.type,
          word.content,
          isBold: isBold,
          fontSize: fontSize,
        ),
        textDirection: word.direction,
        textAlign: textAlign,
      );
    }

    // For multiple words, create a row that keeps content on same line
    List<pw.Widget> wordWidgets = [];

    for (int i = 0; i < words.length; i++) {
      ProcessedWord word = words[i];

      // Add the word widget
      wordWidgets.add(
        pw.Text(
          word.content,
          style: _getStyleForWordType(
            word.type,
            word.content,
            isBold: isBold,
            fontSize: fontSize,
          ),
          textDirection: word.direction,
        ),
      );

      // Add space between words (except for the last word)
      if (i < words.length - 1) {
        // Don't add space after separators or if next word is separator
        if (word.type != WordType.separator &&
            (i + 1 < words.length && words[i + 1].type != WordType.separator)) {
          wordWidgets.add(pw.SizedBox(width: fontSize * 0.25));
        }
      }
    }

    // Use Row instead of Wrap to keep everything on the same line
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      mainAxisAlignment: textAlign == pw.TextAlign.center
          ? pw.MainAxisAlignment.center
          : textAlign == pw.TextAlign.right
              ? pw.MainAxisAlignment.end
              : pw.MainAxisAlignment.start,
      children: wordWidgets,
    );
  }

  /// Enhanced style determination with better font fallback
  static pw.TextStyle _getStyleForWordType(
    WordType type,
    String content, {
    bool isBold = false,
    double fontSize = 10,
  }) {
    bool useArabicFont =
        type == WordType.arabic || RegExp(r'[\u0600-\u06FF]').hasMatch(content);

    return pw.TextStyle(
      font: useArabicFont
          ? (isBold ? _arabicBoldFont! : _arabicFont!)
          : (isBold ? _englishBoldFont! : _englishFont!),
      fontSize: fontSize,
      fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
      // Enhanced font fallback to handle problematic Unicode characters
      fontFallback: [
        _arabicFont!,
        _englishFont!,
        _arabicBoldFont!,
        _englishBoldFont!,
      ],
    );
  }

  /// Create text widget with newline support - handles \n as line breaks
  static pw.Widget createWordLevelTextWidgetWithNewlines(
    String text, {
    bool isBold = false,
    double fontSize = 10,
    pw.TextAlign? textAlign,
    bool useLanguageChunks = true,
    int? maxLines,
    pw.TextOverflow? overflow,
  }) {
    // Check if text contains newlines
    if (text.contains('\n')) {
      List<String> lines = text.split('\n');

      // Create a column of text widgets for each line
      return pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        crossAxisAlignment: _getCrossAxisAlignment(textAlign),
        children: lines.map((line) {
          return createWordLevelTextWidget(
            line.trim(),
            isBold: isBold,
            fontSize: fontSize,
            textAlign: textAlign,
            useLanguageChunks: useLanguageChunks,
          );
        }).toList(),
      );
    } else {
      // No newlines, use regular text widget
      return createWordLevelTextWidget(
        text,
        isBold: isBold,
        fontSize: fontSize,
        textAlign: textAlign,
        useLanguageChunks: useLanguageChunks,
      );
    }
  }

  /// Helper method to get CrossAxisAlignment from TextAlign
  static pw.CrossAxisAlignment _getCrossAxisAlignment(pw.TextAlign? textAlign) {
    switch (textAlign) {
      case pw.TextAlign.center:
        return pw.CrossAxisAlignment.center;
      case pw.TextAlign.left:
        return pw.CrossAxisAlignment.start;
      case pw.TextAlign.right:
        return pw.CrossAxisAlignment.end;
      default:
        return pw.CrossAxisAlignment.start;
    }
  }

  /// Create table cell with newline support and minimal vertical padding
  static pw.Widget createTableCell(
    String text, {
    bool isHeader = false,
    bool isBold = false,
    double minHeight = 8.0, // Reduced from 12.0 to 8.0
    bool greyBackground = false,
    pw.TextAlign? textAlign,
    double? fixedWidth,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(
          horizontal: 1, vertical: 0.5), // Reduced to minimal padding
      constraints: pw.BoxConstraints(
        minHeight: minHeight,
        maxWidth: fixedWidth ?? double.infinity,
      ),
      width: fixedWidth,
      decoration: greyBackground
          ? const pw.BoxDecoration(color: PdfColors.grey200)
          : null,
      child: pw.Center(
        child: createWordLevelTextWidgetWithNewlines(
          text,
          isBold: isHeader || isBold,
          fontSize: 7, // Reduced font size from 8 to 7
          textAlign: pw.TextAlign.center,
          maxLines: text.contains('\n')
              ? null
              : 2, // Allow unlimited lines if newlines present
        ),
      ),
    );
  }

  /// Create table cell specifically for notes column with minimal vertical padding
  static pw.Widget createNotesTableCell(
    String text, {
    bool isHeader = false,
    bool isBold = false,
    bool greyBackground = false,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(
          horizontal: 1, vertical: 0.5), // Reduced to minimal padding
      constraints: const pw.BoxConstraints(
        minHeight: 8.0, // Reduced from 12.0 to 8.0
        maxWidth: 120,
      ),
      decoration: greyBackground
          ? const pw.BoxDecoration(color: PdfColors.grey200)
          : null,
      child: pw.Center(
        // Use Center widget for perfect centering
        child: pw.Text(
          _cleanText(text),
          style: _getStyleForWordType(
            WordType.arabic,
            text,
            fontSize: 7, // Reduced font size from 8 to 7
            isBold: isHeader || isBold,
          ),
          textAlign: pw.TextAlign.center,
          textDirection: pw.TextDirection.rtl,
          maxLines: 2,
          overflow: pw.TextOverflow.clip,
        ),
      ),
    );
  }

  /// Create regular table cell with minimal vertical padding
  static pw.Widget createRegularTableCell(
    String text, {
    bool isHeader = false,
    bool isBold = false,
    bool greyBackground = false,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(
          horizontal: 1, vertical: 0.5), // Reduced to minimal padding
      constraints: const pw.BoxConstraints(
        minHeight: 8.0, // Reduced from 12.0 to 8.0
      ),
      decoration: greyBackground
          ? const pw.BoxDecoration(color: PdfColors.grey200)
          : null,
      child: pw.Center(
        child: createWordLevelTextWidgetWithNewlines(
          text,
          isBold: isHeader || isBold,
          fontSize: 7, // Reduced font size from 8 to 7
          textAlign: pw.TextAlign.center,
        ),
      ),
    );
  }

  /// Create empty table cell with minimal height
  static pw.Widget createEmptyCell({
    double minHeight = 8.0, // Reduced from 12.0 to 8.0
    bool greyBackground = false,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(
          horizontal: 1, vertical: 0.5), // Reduced to minimal padding
      constraints: pw.BoxConstraints(minHeight: minHeight),
      decoration: greyBackground
          ? const pw.BoxDecoration(color: PdfColors.grey200)
          : null,
      child: pw.Center(
        child: pw.Text(''),
      ),
    );
  }

  /// Create contact information section with minimal vertical spacing
  static pw.Widget createContactInfoSection(Contact contact) {
    return pw.Container(
      width: 200,
      child: pw.Table(
        border: pw.TableBorder.all(color: PdfColors.black, width: 1),
        children: [
          // Header row with contact code
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 2, vertical: 1), // Minimal padding
                child: createWordLevelTextWidgetWithNewlines(
                  contact.code,
                  isBold: true,
                  fontSize: 9, // Reduced from 10 to 9
                  textAlign: pw.TextAlign.center,
                ),
              ),
            ],
          ),
          // Contact details row
          pw.TableRow(
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 2, vertical: 1), // Minimal padding
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    // Name
                    pw.Container(
                      width: double.infinity,
                      alignment: pw.Alignment.centerRight,
                      margin: const pw.EdgeInsets.only(
                          bottom: 0.5), // Minimal margin
                      child: createWordLevelTextWidgetWithNewlines(
                        _cleanText(contact.nameAr),
                        isBold: true,
                        fontSize: 9, // Reduced from 10 to 9
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                    // Address - WITH NEWLINE SUPPORT
                    if (contact.streetAddress?.isNotEmpty == true)
                      pw.Container(
                        width: double.infinity,
                        constraints: const pw.BoxConstraints(maxWidth: 180),
                        alignment: pw.Alignment.centerRight,
                        margin: const pw.EdgeInsets.only(
                            bottom: 0.5), // Minimal margin
                        child: createWordLevelTextWidgetWithNewlines(
                          _cleanText(contact.streetAddress!),
                          fontSize: 8, // Reduced from 9 to 8
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    // Tax ID
                    if (contact.taxId?.isNotEmpty == true)
                      pw.Container(
                        width: double.infinity,
                        alignment: pw.Alignment.centerRight,
                        margin: const pw.EdgeInsets.only(
                            bottom: 0.5), // Minimal margin
                        child: createWordLevelTextWidgetWithNewlines(
                          'رقم الضريبة: ${contact.taxId}',
                          fontSize: 8, // Reduced from 9 to 8
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    // Phone
                    if (contact.phone?.isNotEmpty == true)
                      pw.Container(
                        width: double.infinity,
                        alignment: pw.Alignment.centerRight,
                        child: createWordLevelTextWidgetWithNewlines(
                          'تلفون: ${contact.phone}',
                          fontSize: 8, // Reduced from 9 to 8
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Create notes section with minimal vertical spacing
  static pw.Widget createNotesSection(String notes) {
    return pw.Container(
      width: 200,
      child: pw.Table(
        border: pw.TableBorder.all(color: PdfColors.black, width: 1),
        children: [
          // Header
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 2, vertical: 1), // Minimal padding
                child: createWordLevelTextWidget(
                  'ملاحظة',
                  isBold: true,
                  fontSize: 9, // Reduced from 10 to 9
                  textAlign: pw.TextAlign.center,
                ),
              ),
            ],
          ),
          // Content
          pw.TableRow(
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 2, vertical: 1), // Minimal padding
                width: double.infinity,
                alignment: pw.Alignment.centerRight,
                child: createWordLevelTextWidget(
                  notes.isNotEmpty ? _cleanText(notes) : '-',
                  fontSize: 8, // Reduced from 9 to 8
                  textAlign: pw.TextAlign.right,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Create document header - BALANCED SPACING
  static pw.Widget createDocumentHeader({
    required String docType,
    required String docNumber,
    required String docDate,
  }) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Left - Date - BALANCED SPACING
        pw.Expanded(
          flex: 2,
          child: pw.Align(
            alignment: pw.Alignment.centerLeft,
            child: createWordLevelTextWidget(
              'نسخة: $docDate',
              fontSize: 8,
              textAlign: pw.TextAlign.left,
            ),
          ),
        ),
        // Center - Title - BALANCED SPACING
        pw.Expanded(
          flex: 6,
          child: pw.Center(
            child: createWordLevelTextWidget(
              '$docType: $docNumber',
              isBold: true,
              fontSize: 12,
              textAlign: pw.TextAlign.center,
            ),
          ),
        ),
        // Right - Empty - BALANCED SPACING
        pw.Expanded(flex: 2, child: pw.Container()),
      ],
    );
  }

  /// Create license info - RIGHT ALIGNED
  static pw.Widget createLicenseInfo() {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          createWordLevelTextWidget(
            'مشتغل مرخص',
            isBold: true,
            fontSize: 9,
            textAlign: pw.TextAlign.right,
          ),
          createWordLevelTextWidget(
            '562495317',
            isBold: true,
            fontSize: 9,
            textAlign: pw.TextAlign.right,
          ),
        ],
      ),
    );
  }

// Updated createItemsTable method - show discount and after-discount rows always
  static pw.Widget createItemsTable({
    required List<AccountStatementDetail> items,
    required double totalAmount,
    required double discount,
    required double tax,
    required double afterDiscount,
    required double netAmount,
  }) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 1),
      children: [
        // Headers - ALL WITH SAME HEIGHT
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            createRegularTableCell('مجموع',
                isHeader: true, greyBackground: true),
            createRegularTableCell('سعر', isHeader: true, greyBackground: true),
            createRegularTableCell('كمية',
                isHeader: true, greyBackground: true),
            createRegularTableCell('وحدة',
                isHeader: true, greyBackground: true),
            createRegularTableCell('بيان',
                isHeader: true, greyBackground: true),
            createRegularTableCell('صنف', isHeader: true, greyBackground: true),
            createRegularTableCell('#', isHeader: true, greyBackground: true),
          ],
        ),

        // Item rows with consistent height
        ...items.asMap().entries.map((entry) {
          final index = entry.key + 1;
          final item = entry.value;

          return pw.TableRow(
            children: [
              createRegularTableCell(item.amount),
              createRegularTableCell(item.price),
              createRegularTableCell(item.quantity),
              createRegularTableCell(item.unit),
              createRegularTableCell(_cleanText(item.name)),
              createRegularTableCell(item.item),
              createRegularTableCell(index.toString()),
            ],
          );
        }),

        // Totals with consistent height
        pw.TableRow(
          children: [
            createRegularTableCell(_formatNumber(totalAmount.toString()),
                isBold: true),
            createRegularTableCell('المجموع',
                isHeader: true, greyBackground: true),
            createEmptyCell(greyBackground: true),
            createEmptyCell(greyBackground: true),
            createEmptyCell(greyBackground: true),
            createEmptyCell(greyBackground: true),
            createEmptyCell(greyBackground: true),
          ],
        ),

        // Tax row (show always, even if 0)
        pw.TableRow(
          children: [
            createRegularTableCell(_formatNumber(tax.toString())),
            createRegularTableCell('ضريبة ال 16%',
                isHeader: true, greyBackground: true),
            createEmptyCell(greyBackground: true),
            createEmptyCell(greyBackground: true),
            createEmptyCell(greyBackground: true),
            createEmptyCell(greyBackground: true),
            createEmptyCell(greyBackground: true),
          ],
        ),

        // Discount row (show always, even if 0 or negative)
        if (discount != 0 && discount != null)
          pw.TableRow(
            children: [
              createRegularTableCell(_formatNumber(discount.toString())),
              createRegularTableCell('الخصم',
                  isHeader: true, greyBackground: true),
              createEmptyCell(greyBackground: true),
              createEmptyCell(greyBackground: true),
              createEmptyCell(greyBackground: true),
              createEmptyCell(greyBackground: true),
              createEmptyCell(greyBackground: true),
            ],
          ),

        // After discount row (show always)
        if (discount != 0 && discount != null)
          pw.TableRow(
            children: [
              createRegularTableCell(_formatNumber(afterDiscount.toString())),
              createRegularTableCell('بعد الخصم',
                  isHeader: true, greyBackground: true),
              createEmptyCell(greyBackground: true),
              createEmptyCell(greyBackground: true),
              createEmptyCell(greyBackground: true),
              createEmptyCell(greyBackground: true),
              createEmptyCell(greyBackground: true),
            ],
          ),

        // Net total with consistent height
        pw.TableRow(
          children: [
            createRegularTableCell(_formatNumber(netAmount.toString()),
                isBold: true),
            createRegularTableCell('الصافي',
                isHeader: true, greyBackground: true),
            createEmptyCell(greyBackground: true),
            createEmptyCell(greyBackground: true),
            createEmptyCell(greyBackground: true),
            createEmptyCell(greyBackground: true),
            createEmptyCell(greyBackground: true),
          ],
        ),
      ],
    );
  }

  /// Create invoice footer with legal text and signature lines - FIXED ALIGNMENT
  static List<pw.Widget> createInvoiceFooter() {
    return [
      pw.SizedBox(height: 25),
      pw.Center(
        child: createWordLevelTextWidget(
          'استلمت البضاعة المذكورة أعلاه سليمة و خالية من أي خلل أو عيب و التزم بتسديد قيمتها بعد الاستلام مباشرة',
          fontSize: 10,
          textAlign: pw.TextAlign.center,
        ),
      ),

      pw.SizedBox(height: 70),

      // FIXED: Signature lines - properly aligned in single row
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
        children: [
          // Left spacer
          pw.Expanded(flex: 2, child: pw.Container()),

          // Name section
          pw.Expanded(
            flex: 3,
            child: pw.Column(
              children: [
                pw.Container(
                  height: 1,
                  width: double.infinity,
                  color: PdfColors.black,
                ),
                pw.SizedBox(height: 4),
                createWordLevelTextWidget(
                  'الاسم',
                  fontSize: 8,
                  textAlign: pw.TextAlign.center,
                ),
              ],
            ),
          ),

          // Middle spacer
          pw.Expanded(flex: 1, child: pw.Container()),

          // Signature section
          pw.Expanded(
            flex: 3,
            child: pw.Column(
              children: [
                pw.Container(
                  height: 1,
                  width: double.infinity,
                  color: PdfColors.black,
                ),
                pw.SizedBox(height: 4),
                createWordLevelTextWidget(
                  ')التوقيع(',
                  fontSize: 8,
                  textAlign: pw.TextAlign.center,
                ),
              ],
            ),
          ),

          // Right spacer
          pw.Expanded(flex: 2, child: pw.Container()),
        ],
      ),
    ];
  }

  /// Create account statement table headers with minimal spacing
  static List<pw.TableRow> createAccountStatementHeaders() {
    return [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
        children: [
          createRegularTableCell('الرصيد الجاري',
              isHeader: true, greyBackground: true),
          createRegularTableCell('دائن', isHeader: true, greyBackground: true),
          createRegularTableCell('مدين', isHeader: true, greyBackground: true),
          createRegularTableCell('مستند', isHeader: true, greyBackground: true),
          createRegularTableCell('تاريخ', isHeader: true, greyBackground: true),
        ],
      ),
    ];
  }

  /// Create payment receipt table with minimal vertical spacing
  static pw.Widget createPaymentReceiptTable(
      List<AccountStatementDetail> details) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 1),
      children: [
        // Headers - ALL WITH SAME HEIGHT
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            createRegularTableCell('القيمة',
                isHeader: true, greyBackground: true),
            createRegularTableCell('التاريخ',
                isHeader: true, greyBackground: true),
            createRegularTableCell('رقم', isHeader: true, greyBackground: true),
            createRegularTableCell('طريقة الدفع',
                isHeader: true, greyBackground: true),
            createRegularTableCell('#', isHeader: true, greyBackground: true),
          ],
        ),
        // Data with consistent height and newline support
        if (details.isNotEmpty)
          pw.TableRow(
            children: [
              createRegularTableCell(details.first.credit),
              createRegularTableCell(details.first.check.isEmpty
                  ? '-'
                  : details.first.checkDueDate),
              createRegularTableCell(details.first.check.isEmpty
                  ? '-'
                  : details.first.checkNumber),
              createRegularTableCell(
                  details.first.check.isEmpty ? 'كاش' : 'شيكات'),
              createRegularTableCell('1'),
            ],
          ),
      ],
    );
  }

  /// Create period information section - ALIGNED TO FAR RIGHT
  static pw.Widget createPeriodInfo({
    required String fromDate,
    required String toDate,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Align(
          alignment: pw.Alignment.topRight,
          child: pw.Text(
            'فترة: من $fromDate إلى $toDate',
            style: pw.TextStyle(
              font: _arabicBoldFont!,
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
            ),
            textAlign: pw.TextAlign.right,
            textDirection: pw.TextDirection.rtl,
          ),
        ),
      ],
    );
  }
  // ==================== UTILITY METHODS ====================

  /// Parse numeric values safely
  static double _parseNumber(String numberStr) {
    if (numberStr.isEmpty) return 0;
    try {
      return double.parse(numberStr.replaceAll(',', ''));
    } catch (e) {
      return 0;
    }
  }

  /// Format numbers for display
  static String _formatNumber(String numberStr) {
    if (numberStr.isEmpty) return '';
    try {
      final number = _parseNumber(numberStr);
      if (number == 0) return '';
      return NumberFormat('#,##0.00').format(number);
    } catch (e) {
      return numberStr;
    }
  }

  /// Clean text safely and remove problematic Unicode characters
  static String _cleanText(String text) {
    if (text.isEmpty) return text;

    // Remove problematic Unicode directional characters that cause font issues
    String cleaned = text
        .replaceAll('\u202A', '') // Left-to-Right Embedding
        .replaceAll('\u202B', '') // Right-to-Left Embedding
        .replaceAll('\u202C', '') // Pop Directional Formatting
        .replaceAll('\u202D', '') // Left-to-Right Override
        .replaceAll('\u202E', '') // Right-to-Left Override
        .replaceAll('\u200E', '') // Left-to-Right Mark
        .replaceAll('\u200F', '') // Right-to-Left Mark
        .replaceAll('\u061C', '') // Arabic Letter Mark
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');

    return cleaned;
  }

  // ==================== SVG HEADER METHODS ====================

  /// Load and create SVG header widget
  static Future<pw.Widget> createSvgHeader() async {
    try {
      // Load SVG file from assets using rootBundle
      final String svgString =
          await rootBundle.loadString('assets/images/header.svg');

      return pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(
            horizontal: 0), // 5% margins handled by Row
        child: pw.Row(
          children: [
            // Left 5% margin
            pw.Expanded(flex: 2, child: pw.Container()),

            // SVG content 90% width
            pw.Expanded(
              flex: 96,
              child: pw.Center(
                child: pw.SvgImage(
                  svg: svgString,
                  fit: pw.BoxFit.contain,
                ),
              ),
            ),

            // Right 5% margin
            pw.Expanded(flex: 2, child: pw.Container()),
          ],
        ),
      );
    } catch (e) {
      // Fallback if SVG fails to load
      return pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(horizontal: 0),
        child: pw.Row(
          children: [
            pw.Expanded(flex: 5, child: pw.Container()),
            pw.Expanded(
              flex: 90,
              child: pw.Container(
                height: 60,
                decoration: const pw.BoxDecoration(
                  color: PdfColors.grey200,
                  border: pw.Border.fromBorderSide(
                    pw.BorderSide(color: PdfColors.grey400, width: 1),
                  ),
                ),
                child: pw.Center(
                  child: pw.Text(
                    'Header SVG Not Found',
                    style: pw.TextStyle(
                      font: _englishFont,
                      fontSize: 12,
                      color: PdfColors.grey600,
                    ),
                  ),
                ),
              ),
            ),
            pw.Expanded(flex: 5, child: pw.Container()),
          ],
        ),
      );
    }
  }

// Updated generateInvoiceDetailPdf method - fix calculation to match mobile screen
  static Future<Uint8List> generateInvoiceDetailPdf({
    required Contact contact,
    required List<AccountStatementDetail> details,
    required String documentTitle,
  }) async {
    await _loadFonts();

    // PRE-LOAD SVG HEADER
    final svgHeader = await createSvgHeader();

    final pdf = pw.Document();

    // Calculate totals - MATCH THE MOBILE SCREEN LOGIC EXACTLY
    double totalAmount = 0;
    double tax = 0;
    double discount = 0;

    final items = details.where((d) => d.item.isNotEmpty).toList();

    // Calculate total amount
    for (final item in items) {
      totalAmount += _parseNumber(item.amount);
    }

    // Get tax and discount from items (same logic as mobile screen)
    if (items.isNotEmpty) {
      for (final item in items) {
        if (item.tax.isNotEmpty) {
          tax = _parseNumber(item.tax);
        }
        if (item.docDiscount.isNotEmpty) {
          discount = _parseNumber(item.docDiscount);
        }
      }
    }

    // Calculate after discount and net amount (match mobile screen exactly)
    final afterDiscount =
        totalAmount - discount; // Don't round here like mobile screen
    final netAmount = afterDiscount; // Add tax to get final net amount

    // Extract document info
    String docDate = details.isNotEmpty && details.first.docDate.isNotEmpty
        ? details.first.docDate
        : DateFormat('dd-MM-yyyy').format(DateTime.now());

    String docType = 'فاتورة';
    String docNumber = documentTitle;

    if (documentTitle.contains('مرتجع')) {
      docType = 'مرتجع مبيعات';
      docNumber = documentTitle.replaceAll('مرتجع مبيعات', '').trim();
    } else if (documentTitle.contains('قبض')) {
      docType = 'قبض';
      docNumber = documentTitle.replaceAll('قبض', '').trim();
    } else if (documentTitle.contains('فاتورة')) {
      docNumber = documentTitle.replaceAll('فاتورة', '').trim();
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.all(16),
        build: (pw.Context context) {
          return pw.Stack(
            children: [
              // Main content
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // SVG HEADER - Pre-loaded, no await needed
                  svgHeader,

                  pw.SizedBox(height: 16),

                  // Document header
                  createDocumentHeader(
                    docType: docType,
                    docNumber: docNumber,
                    docDate: docDate,
                  ),

                  pw.SizedBox(height: 8),

                  // License information
                  createLicenseInfo(),

                  pw.SizedBox(height: 8),

                  // Contact information
                  pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: createContactInfoSection(contact),
                  ),

                  pw.SizedBox(height: 8),

                  // Content based on document type
                  if (docType == 'قبض') ...[
                    // Payment receipt table
                    createPaymentReceiptTable(details),
                  ] else ...[
                    // Items table with totals
                    createItemsTable(
                      items: items,
                      totalAmount: totalAmount,
                      discount: discount,
                      tax: tax,
                      afterDiscount: afterDiscount,
                      netAmount: netAmount,
                    ),
                  ],

                  // Footer for invoices only
                  if (docType == 'فاتورة') ...createInvoiceFooter(),
                ],
              ),

              // FIXED PAGE NUMBER AT BOTTOM (only for multi-page documents)
              if (context.pagesCount > 1)
                pw.Positioned(
                  bottom: 18,
                  left: 0,
                  right: 0,
                  child: pw.Center(
                    child: createWordLevelTextWidget(
                      'صفحة ${context.pageNumber} من ${context.pagesCount}',
                      fontSize: 9,
                      isBold: false,
                      useLanguageChunks: false,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Generate Customer Opening PDF with fixed alignment and separate tables
  static Future<Uint8List> generateCustomerOpeningPdf(
      {required String businessName,
      required String ownerName,
      required String responsiblePerson,
      required String taxId,
      required String idNumber,
      required String mobile,
      required String telephone,
      required String email,
      required String state,
      required String street,
      required String stateType,
      required String beside,
      required String businessType,
      required String visitDays,
      required String paymentMethod,
      required String creditLimit,
      required String date,
      required String contactCode,
      required String createdBy,
      required String salesman}) async {
    try {
      await _loadFonts();
    } catch (e) {
      print('DEBUG: Font loading failed: $e');
    }

    final pdf = pw.Document();

    try {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          textDirection: pw.TextDirection.rtl,
          margin: const pw.EdgeInsets.all(8),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Compact Header
                pw.Container(
                  width: double.infinity,
                  padding:
                      const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey200,
                    border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'شركة جالا فود',
                        style: pw.TextStyle(
                          font: _arabicBoldFont ?? _arabicFont,
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                        textDirection: pw.TextDirection.rtl,
                      ),
                      pw.Text(
                        'استمارة فتح زبون جديد',
                        style: pw.TextStyle(
                          font: _arabicBoldFont ?? _arabicFont,
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                        textDirection: pw.TextDirection.rtl,
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 4),

                // Contact Code and Date Row
                pw.Container(
                  width: double.infinity,
                  padding:
                      const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'رقم العميل: $contactCode',
                        style: pw.TextStyle(
                          font: _arabicBoldFont ?? _arabicFont,
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                        textDirection: pw.TextDirection.rtl,
                      ),
                      pw.Text(
                        'التاريخ: $date',
                        style: pw.TextStyle(
                          font: _arabicFont ?? _arabicBoldFont,
                          fontSize: 10,
                        ),
                        textDirection: pw.TextDirection.rtl,
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 40),

                // Table 1: Personal Information
                _buildTableWithTitle(
                  title: 'بطاقة معلومات شخصية',
                  rows: [
                    ['اسم المندوب', createdBy, 'رقم المندوب', salesman],
                    [
                      'اسم المحل التجاري',
                      businessName,
                      'رقم المشتغل المرخص',
                      taxId.isNotEmpty ? taxId : '-'
                    ],
                    [
                      'اسم مالك المحل',
                      ownerName,
                      'رقم الهوية',
                      idNumber.isNotEmpty ? idNumber : '-'
                    ],
                    ['اسم الشخص المسؤول', responsiblePerson, 'خلوي', mobile],
                    [
                      'هاتف المحل',
                      telephone.isNotEmpty ? telephone : '-',
                      'البريد الإلكتروني',
                      email.isNotEmpty ? email : '-'
                    ],
                  ],
                ),

                pw.SizedBox(height: 16),

                // Table 2: Address Information
                _buildTableWithTitle(
                  title: 'العنوان',
                  rows: [
                    ['المنطقة', state, 'الشارع', street],
                    ['نوع المنطقة', stateType, 'بجانب', beside],
                  ],
                ),

                pw.SizedBox(height: 16),

                // Table 3: Business Information
                _buildTableWithTitle(
                  title: 'بطاقة معلومات تجارية',
                  rows: [
                    [
                      'نوع العمل',
                      businessType,
                      'أيام الزيارات',
                      visitDays.isNotEmpty ? visitDays : '-'
                    ],
                  ],
                ),

                pw.SizedBox(height: 16),

                // Table 4: Payment Methods
                _buildTableWithTitle(
                  title: 'طرق الدفع',
                  rows: [
                    [
                      'طريقة الدفع',
                      paymentMethod.isNotEmpty ? paymentMethod : '-',
                      'الحد الأقصى للدين',
                      creditLimit.isNotEmpty ? creditLimit : '-'
                    ],
                  ],
                ),

                pw.SizedBox(height: 16),

                // Status Information
                pw.Container(
                  width: double.infinity,
                  padding:
                      const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'تاريخ الإنشاء: $date',
                        style: pw.TextStyle(
                          font: _arabicFont ?? _arabicBoldFont,
                          fontSize: 9,
                        ),
                        textDirection: pw.TextDirection.rtl,
                      ),
                    ],
                  ),
                ),

                pw.Spacer(),

                // Footer
                pw.Container(
                  width: double.infinity,
                  padding:
                      const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                  ),
                  child: pw.Text(
                    'ملاحظة: هذا العميل تم إنشاؤه من تطبيق الموبايل',
                    style: pw.TextStyle(
                      font: _arabicFont ?? _arabicBoldFont,
                      fontSize: 8,
                    ),
                    textDirection: pw.TextDirection.rtl,
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              ],
            );
          },
        ),
      );

      print('DEBUG: Fixed PDF generation completed successfully');
      return pdf.save();
    } catch (e) {
      print('DEBUG: PDF generation error: $e');
      return await _createFallbackPdf(
        contactCode: contactCode,
        date: date,
        createdBy: createdBy,
        businessName: businessName,
        ownerName: ownerName,
        responsiblePerson: responsiblePerson,
        taxId: taxId,
        idNumber: idNumber,
        mobile: mobile,
        telephone: telephone,
        email: email,
        state: state,
        street: street,
        stateType: stateType,
        beside: beside,
        businessType: businessType,
        visitDays: visitDays,
        paymentMethod: paymentMethod,
        creditLimit: creditLimit,
      );
    }
  }

  /// Build a table with title
  static pw.Widget _buildTableWithTitle({
    required String title,
    required List<List<String>> rows,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Table Title
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 6),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey300,
            border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
          ),
          child: pw.Text(
            title,
            style: pw.TextStyle(
              font: _arabicBoldFont ?? _arabicFont,
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
            textDirection: pw.TextDirection.rtl,
            textAlign: pw.TextAlign.center,
          ),
        ),

        // Table Content
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(2), // Right label (fixed order)
            1: const pw.FlexColumnWidth(3), // Right value (fixed order)
            2: const pw.FlexColumnWidth(2), // Left label (fixed order)
            3: const pw.FlexColumnWidth(3), // Left value (fixed order)
          },
          children: rows.map((row) {
            return pw.TableRow(
              children: [
                _createFixedCell(row[3]), // Left value
                _createFixedCell(row[2], isLabel: true), // Left label
                _createFixedCell(row[1]), // Right value
                _createFixedCell(row[0], isLabel: true), // Right label
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  /// Create cell with proper right alignment
  static pw.Widget _createFixedCell(
    String text, {
    bool isLabel = false,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.2),
      ),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: isLabel
              ? (_arabicBoldFont ?? _arabicFont)
              : (_arabicFont ?? _arabicBoldFont),
          fontSize: isLabel ? 9 : 8,
          fontWeight: isLabel ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textDirection: pw.TextDirection.rtl,
        textAlign: pw.TextAlign.right, // Fixed to right alignment
        maxLines: 2,
        overflow: pw.TextOverflow.clip,
      ),
    );
  }

  /// Enhanced fallback PDF with proper structure
  static Future<Uint8List> _createFallbackPdf({
    required String contactCode,
    required String date,
    required String createdBy,
    required String businessName,
    required String ownerName,
    required String responsiblePerson,
    required String taxId,
    required String idNumber,
    required String mobile,
    required String telephone,
    required String email,
    required String state,
    required String street,
    required String stateType,
    required String beside,
    required String businessType,
    required String visitDays,
    required String paymentMethod,
    required String creditLimit,
  }) async {
    final fallbackPdf = pw.Document();
    fallbackPdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(8),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Customer Information Form - $contactCode',
                style:
                    pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              pw.Text('Date: $date'),
              pw.SizedBox(height: 12),

              // Personal Information
              _buildFallbackTable(
                title: 'Personal Information',
                data: [
                  ['Sales Rep:', createdBy, 'Rep Code:', '015'],
                  [
                    'Business:',
                    businessName,
                    'Tax ID:',
                    taxId.isNotEmpty ? taxId : '-'
                  ],
                  [
                    'Owner:',
                    ownerName,
                    'ID:',
                    idNumber.isNotEmpty ? idNumber : '-'
                  ],
                  ['Responsible:', responsiblePerson, 'Mobile:', mobile],
                  [
                    'Phone:',
                    telephone.isNotEmpty ? telephone : '-',
                    'Email:',
                    email.isNotEmpty ? email : '-'
                  ],
                ],
              ),

              pw.SizedBox(height: 8),

              // Address Information
              _buildFallbackTable(
                title: 'Address',
                data: [
                  ['State:', state, 'Street:', street],
                  ['State Type:', stateType, 'Beside:', beside],
                ],
              ),

              pw.SizedBox(height: 8),

              // Business Information
              _buildFallbackTable(
                title: 'Business Information',
                data: [
                  [
                    'Business Type:',
                    businessType,
                    'Visit Days:',
                    visitDays.isNotEmpty ? visitDays : '-'
                  ],
                ],
              ),

              pw.SizedBox(height: 8),

              // Payment Methods
              _buildFallbackTable(
                title: 'Payment Methods',
                data: [
                  [
                    'Payment Method:',
                    paymentMethod.isNotEmpty ? paymentMethod : '-',
                    'Credit Limit:',
                    creditLimit.isNotEmpty ? creditLimit : '-'
                  ],
                ],
              ),

              pw.Spacer(),

              pw.Text(
                'Status: Inactive - Pending Review | Created: $date',
                style:
                    pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Note: This customer was created from mobile app and needs activation from management',
                style:
                    pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic),
              ),
            ],
          );
        },
      ),
    );
    return fallbackPdf.save();
  }

  /// Build fallback table with title
  static pw.Widget _buildFallbackTable({
    required String title,
    required List<List<String>> data,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(4),
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          child: pw.Text(
            title,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(1),
            1: const pw.FlexColumnWidth(2),
            2: const pw.FlexColumnWidth(1),
            3: const pw.FlexColumnWidth(2),
          },
          children: data.map((row) {
            return pw.TableRow(
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.all(2),
                  child: pw.Text(row[0],
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(2),
                  child: pw.Text(row[1]),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(2),
                  child: pw.Text(row[2],
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(2),
                  child: pw.Text(row[3]),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  /// Prepare all customer data lines in order
  static List<CustomerDataLine> _prepareCustomerDataLines({
    required String businessName,
    required String ownerName,
    required String responsiblePerson,
    required String taxId,
    required String idNumber,
    required String mobile,
    required String telephone,
    required String email,
    required String state,
    required String street,
    required String stateType,
    required String beside,
    required String businessType,
    required String visitDays,
    required String paymentMethod,
    required String creditLimit,
    required String createdBy,
  }) {
    List<CustomerDataLine> lines = [];

    // Basic Information Section
    lines.add(CustomerDataLine(
        label: 'المعلومات الأساسية', value: '', isSection: true));
    lines
        .add(CustomerDataLine(label: 'اسم المحل التجاري', value: businessName));
    lines.add(CustomerDataLine(label: 'اسم مالك المحل', value: ownerName));
    lines.add(
        CustomerDataLine(label: 'اسم الشخص المسؤول', value: responsiblePerson));

    // Official Information Section
    lines.add(CustomerDataLine(
        label: 'المعلومات الرسمية', value: '', isSection: true));
    lines.add(CustomerDataLine(
        label: 'رقم المشتغل المرخص', value: taxId.isNotEmpty ? taxId : '-'));
    lines.add(CustomerDataLine(
        label: 'رقم الهوية', value: idNumber.isNotEmpty ? idNumber : '-'));

    // Contact Information Section
    lines.add(
        CustomerDataLine(label: 'معلومات الاتصال', value: '', isSection: true));
    lines.add(CustomerDataLine(label: 'خلوي', value: mobile));
    lines.add(CustomerDataLine(
        label: 'هاتف المحل', value: telephone.isNotEmpty ? telephone : '-'));
    lines.add(CustomerDataLine(
        label: 'البريد الإلكتروني', value: email.isNotEmpty ? email : '-'));

    // Address Section
    lines.add(CustomerDataLine(label: 'العنوان', value: '', isSection: true));
    lines.add(CustomerDataLine(label: 'المنطقة', value: state));
    lines.add(CustomerDataLine(label: 'نوع المنطقة', value: stateType));
    lines.add(CustomerDataLine(label: 'الشارع', value: street));
    lines.add(CustomerDataLine(label: 'بجانب', value: beside));

    // Business Details Section
    lines.add(
        CustomerDataLine(label: 'تفاصيل العمل', value: '', isSection: true));
    lines.add(CustomerDataLine(label: 'نوع العمل', value: businessType));
    lines.add(CustomerDataLine(
        label: 'أيام الزيارات', value: visitDays.isNotEmpty ? visitDays : '-'));
    lines.add(CustomerDataLine(
        label: 'طريقة الدفع',
        value: paymentMethod.isNotEmpty ? paymentMethod : '-'));
    lines.add(CustomerDataLine(
        label: 'الحد الأقصى للدين',
        value: creditLimit.isNotEmpty ? creditLimit : '-'));

    // System Information Section
    lines.add(
        CustomerDataLine(label: 'معلومات النظام', value: '', isSection: true));
    lines.add(CustomerDataLine(label: 'تم الإنشاء بواسطة', value: createdBy));
    lines.add(CustomerDataLine(
        label: 'حالة العميل', value: 'غير مفعل - بانتظار المراجعة'));

    return lines;
  }

  /// Paginate customer data lines based on available space
  static List<List<CustomerDataLine>> _paginateCustomerData(
    List<CustomerDataLine> allLines,
    int firstPageMaxLines,
    int otherPageMaxLines,
  ) {
    List<List<CustomerDataLine>> pages = [];
    List<CustomerDataLine> currentPage = [];
    int currentPageIndex = 0;

    for (int i = 0; i < allLines.length; i++) {
      CustomerDataLine line = allLines[i];

      // Determine max lines for current page
      int maxLinesForCurrentPage =
          currentPageIndex == 0 ? firstPageMaxLines : otherPageMaxLines;

      // Check if adding this line would exceed page capacity
      if (currentPage.length >= maxLinesForCurrentPage) {
        // Save current page and start new page
        if (currentPage.isNotEmpty) {
          pages.add(List.from(currentPage));
          currentPage = [];
          currentPageIndex++;
        }
      }

      currentPage.add(line);
    }

    // Add the last page if it has content
    if (currentPage.isNotEmpty) {
      pages.add(currentPage);
    }

    // Ensure at least one page exists
    if (pages.isEmpty) {
      pages.add([]);
    }

    return pages;
  }

  /// Create header widget for customer PDF
  static pw.Widget _createCustomerPdfHeader() {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey200,
        border: pw.Border.all(color: PdfColors.grey400),
      ),
      child: pw.Text(
        'شركة جالا فود',
        style: pw.TextStyle(
          font: _arabicBoldFont ?? _arabicFont,
          fontSize: 18,
          fontWeight: pw.FontWeight.bold,
        ),
        textDirection: pw.TextDirection.rtl,
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  /// Create title widget for customer PDF
  static pw.Widget _createCustomerPdfTitle() {
    return pw.Center(
      child: pw.Text(
        'استمارة فتح زبون جديد',
        style: pw.TextStyle(
          font: _arabicBoldFont ?? _arabicFont,
          fontSize: 16,
          fontWeight: pw.FontWeight.bold,
        ),
        textDirection: pw.TextDirection.rtl,
      ),
    );
  }

  /// Create metadata (contact code and date) for customer PDF
  static pw.Widget _createCustomerPdfMetadata(String contactCode, String date) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          'رقم العميل: $contactCode',
          style: pw.TextStyle(
            font: _arabicBoldFont ?? _arabicFont,
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
          ),
          textDirection: pw.TextDirection.rtl,
        ),
        pw.Text(
          'التاريخ: $date',
          style: pw.TextStyle(
            font: _arabicFont ?? _arabicBoldFont,
            fontSize: 12,
          ),
          textDirection: pw.TextDirection.rtl,
        ),
      ],
    );
  }

  /// Create individual data line widget
  static pw.Widget _createCustomerDataLineWidget(CustomerDataLine line) {
    if (line.isSection) {
      // Section header - takes more vertical space
      return pw.Container(
        margin: const pw.EdgeInsets.only(top: 12, bottom: 8),
        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey300,
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Row(
          children: [
            pw.Expanded(
              child: pw.Text(
                line.label,
                style: pw.TextStyle(
                  font: _arabicBoldFont ?? _arabicFont,
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
                textDirection: pw.TextDirection.rtl,
                textAlign: pw.TextAlign.center,
              ),
            ),
          ],
        ),
      );
    } else {
      // Data line - compact spacing
      return pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Label (bold)
            pw.Container(
              width: 120,
              child: pw.Text(
                line.label + ':',
                style: pw.TextStyle(
                  font: _arabicBoldFont ?? _arabicFont,
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
                textDirection: pw.TextDirection.rtl,
              ),
            ),

            // Spacing
            pw.SizedBox(width: 10),

            // Value (normal)
            pw.Expanded(
              child: pw.Text(
                line.value.isNotEmpty ? line.value : '-',
                style: pw.TextStyle(
                  font: _arabicFont ?? _arabicBoldFont,
                  fontSize: 10,
                ),
                textDirection: pw.TextDirection.rtl,
              ),
            ),
          ],
        ),
      );
    }
  }

  /// Create footer widget for customer PDF
  static pw.Widget _createCustomerPdfFooter() {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Text(
        'ملاحظة: هذا العميل تم إنشاؤه من تطبيق الموبايل ويحتاج إلى تفعيل من الإدارة',
        style: pw.TextStyle(
          font: _arabicFont ?? _arabicBoldFont,
          fontSize: 10,
        ),
        textDirection: pw.TextDirection.rtl,
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  /// Create fallback PDF in case of errors
  static Future<Uint8List> _createFallbackCustomerPdf(
    String contactCode,
    String date,
    String businessName,
    String ownerName,
    String mobile,
  ) {
    final fallbackPdf = pw.Document();
    fallbackPdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Customer Information Form',
                style:
                    pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              pw.Text('Customer Code: $contactCode'),
              pw.Text('Date: $date'),
              pw.SizedBox(height: 20),
              pw.Text('Business Name: $businessName'),
              pw.Text('Owner Name: $ownerName'),
              pw.Text('Mobile: $mobile'),
              pw.Spacer(),
              pw.Text(
                'Note: This customer was created from mobile app and needs activation from management',
                style:
                    pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic),
              ),
            ],
          );
        },
      ),
    );
    return fallbackPdf.save();
  }

  /// Create simple section header for customer opening PDF
  static pw.TableRow _createSimpleSectionHeader(String title) {
    return pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.grey300),
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(
            title,
            style: pw.TextStyle(
              font: _arabicBoldFont ?? _arabicFont,
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
            textDirection: pw.TextDirection.rtl,
            textAlign: pw.TextAlign.center,
          ),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(''),
        ),
      ],
    );
  }

  /// Create simple information row for customer opening PDF
  static pw.TableRow _createSimpleInfoRow(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            border: pw.Border(right: pw.BorderSide(color: PdfColors.grey400)),
          ),
          child: pw.Text(
            label,
            style: pw.TextStyle(
              font: _arabicFont ?? _arabicBoldFont,
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
            ),
            textDirection: pw.TextDirection.rtl,
          ),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(
            value.isNotEmpty ? value : '-',
            style: pw.TextStyle(
              font: _arabicFont ?? _arabicBoldFont,
              fontSize: 11,
            ),
            textDirection: pw.TextDirection.rtl,
          ),
        ),
      ],
    );
  }

  /// Generate Account Statement PDF - WITHOUT NOTES COLUMN
  static Future<Uint8List> generateAccountStatementPdf({
    required Contact contact,
    required List<AccountStatement> statements,
    required String fromDate,
    required String toDate,
  }) async {
    await _loadFonts();

    // PRE-LOAD SVG HEADER
    final svgHeader = await createSvgHeader();

    final pdf = pw.Document();

    // Calculate totals
    double totalDebit = 0;
    double totalCredit = 0;
    double finalBalance = 0;

    for (final statement in statements) {
      totalDebit += _parseNumber(statement.debit);
      totalCredit += _parseNumber(statement.credit);
    }
    if (statements.isNotEmpty) {
      finalBalance = _parseNumber(statements.last.runningBalance);
    }

    // ADJUSTED PAGINATION - More rows per page without notes column
    const int firstPageRows = 26; // Increased due to no notes column
    const int otherPageRows = 46; // Increased due to no notes column

    // Calculate total pages needed
    int totalPages = 1;
    int remainingRows = statements.length;

    if (remainingRows > firstPageRows) {
      remainingRows -= firstPageRows;
      totalPages += (remainingRows / otherPageRows).ceil();
    }

    if (statements.isEmpty) totalPages = 1;

    int currentRowIndex = 0;

    for (int pageIndex = 0; pageIndex < totalPages; pageIndex++) {
      final bool isFirstPage = pageIndex == 0;
      final bool isLastPage = pageIndex == totalPages - 1;
      final int rowsForThisPage = isFirstPage ? firstPageRows : otherPageRows;

      final int startIndex = currentRowIndex;
      final int endIndex =
          (startIndex + rowsForThisPage).clamp(0, statements.length);
      final List<AccountStatement> pageStatements =
          statements.isEmpty ? [] : statements.sublist(startIndex, endIndex);

      currentRowIndex = endIndex;

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          textDirection: pw.TextDirection.rtl,
          margin: const pw.EdgeInsets.only(
            top: 16,
            left: 16,
            right: 16,
            bottom: 25,
          ),
          build: (pw.Context context) {
            return pw.Stack(
              children: [
                // Main content
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // SVG HEADER - Only on first page
                    if (isFirstPage) ...[
                      svgHeader,
                      pw.SizedBox(height: 16),
                    ],

                    // Header - Only on first page
                    if (isFirstPage) ...[
                      pw.Center(
                        child: createWordLevelTextWidgetWithNewlines(
                          'كشف حساب - ${_cleanText(contact.nameAr)}',
                          isBold: true,
                          fontSize: 12,
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.SizedBox(height: 8),

                      // License info
                      createLicenseInfo(),
                      pw.SizedBox(height: 8),

                      // Contact info
                      pw.Align(
                        alignment: pw.Alignment.centerRight,
                        child: createContactInfoSection(contact),
                      ),
                      pw.SizedBox(height: 8),

                      // Period info
                      createPeriodInfo(fromDate: fromDate, toDate: toDate),
                      pw.SizedBox(height: 16),
                    ],

                    // Account statement table - EXPANDED TO FILL AVAILABLE SPACE
                    pw.Expanded(
                      child: pw.Table(
                        border: pw.TableBorder.all(
                            color: PdfColors.black, width: 1),
                        columnWidths: {
                          // REMOVED: Notes column (index 0)
                          0: const pw.FixedColumnWidth(100), // Running Balance
                          1: const pw.FixedColumnWidth(80), // Credit
                          2: const pw.FixedColumnWidth(80), // Debit
                          3: const pw.FixedColumnWidth(120), // Document Name
                          4: const pw.FixedColumnWidth(80), // Date
                        },
                        children: [
                          // Headers on every page
                          ...createAccountStatementHeaders(),

                          // Data rows for this page WITHOUT NOTES COLUMN
                          ...pageStatements.map((statement) {
                            return pw.TableRow(
                              children: [
                                // REMOVED: Notes column
                                createRegularTableCell(
                                    statement.runningBalance),
                                createRegularTableCell(statement.credit),
                                createRegularTableCell(statement.debit),
                                createRegularTableCell(
                                    _cleanText(statement.displayName)),
                                createRegularTableCell(statement.docDate),
                              ],
                            );
                          }),

                          // Total row - ALWAYS show on last page if statements exist
                          if (isLastPage && statements.isNotEmpty)
                            pw.TableRow(
                              decoration: const pw.BoxDecoration(
                                  color: PdfColors.grey100),
                              children: [
                                // REMOVED: Notes column
                                createRegularTableCell(
                                    _formatNumber(finalBalance.toString()),
                                    isBold: true,
                                    greyBackground: true),
                                createRegularTableCell(
                                    _formatNumber(totalCredit.toString()),
                                    isBold: true,
                                    greyBackground: true),
                                createRegularTableCell(
                                    _formatNumber(totalDebit.toString()),
                                    isBold: true,
                                    greyBackground: true),
                                createRegularTableCell('المجموع',
                                    isHeader: true, greyBackground: true),
                                createEmptyCell(greyBackground: true),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),

                // FIXED PAGE NUMBER AT BOTTOM
                if (totalPages > 1)
                  pw.Positioned(
                    bottom: 30,
                    left: 0,
                    right: 0,
                    child: pw.Center(
                      child: createWordLevelTextWidget(
                        'صفحة ${pageIndex + 1} من $totalPages',
                        fontSize: 9,
                        isBold: false,
                        useLanguageChunks: false,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      );
    }

    return pdf.save();
  }
}
