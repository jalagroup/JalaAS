// lib/screens/mobile/pin_enter_screen.dart
import 'package:flutter/material.dart';
import 'package:jala_as/screens/mobile/mobile_contact_selection_screen.dart';
import 'package:jala_as/screens/mobile/mobile_login_screen.dart';
import 'package:jala_as/screens/mobile/welcome_screen.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';

class PinEnterScreen extends StatefulWidget {
  final VoidCallback onPinVerified;

  const PinEnterScreen({
    super.key,
    required this.onPinVerified,
  });

  @override
  State<PinEnterScreen> createState() => _PinEnterScreenState();
}

class _PinEnterScreenState extends State<PinEnterScreen> {
  String _enteredPin = '';
  bool _isLoading = false;
  int _attemptCount = 0;
  static const int _maxAttempts = 3;

  // Key to force rebuild of PinCodeTextField when needed
  Key _pinFieldKey = UniqueKey();

  void _onPinChanged(String value) {
    if (!mounted) return;

    setState(() {
      _enteredPin = value;
    });

    if (value.length == AppConstants.pinLength) {
      _verifyPin();
    }
  }

  void _clearPin() {
    if (!mounted) return;

    setState(() {
      _enteredPin = '';
      _pinFieldKey = UniqueKey(); // Force rebuild to clear the field
    });
  }

  Future<void> _verifyPin() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Use the verifyPin method from Helpers which handles hashing comparison
      final isCorrect = await Helpers.verifyPin(_enteredPin);

      if (!mounted) return;

      if (isCorrect) {
        await Helpers.updateLastActiveTime();

        if (!mounted) return;

        Helpers.showSnackBar(context, 'تم التحقق من رمز PIN بنجاح');

        await Future.delayed(const Duration(milliseconds: 500));

        if (!mounted) return;

        widget.onPinVerified();

        // Check if user is logged in to determine where to navigate
        final isLoggedIn = await Helpers.isLoggedIn();

        if (!mounted) return;

        if (isLoggedIn) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const WelcomeScreen()),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        }
      } else {
        _attemptCount++;

        if (!mounted) return;

        if (_attemptCount >= _maxAttempts) {
          Helpers.showSnackBar(
            context,
            'تم تجاوز عدد المحاولات المسموح. يرجى إعادة تشغيل التطبيق.',
            isError: true,
          );
        } else {
          Helpers.showSnackBar(
            context,
            'رمز PIN غير صحيح. المحاولات المتبقية: ${_maxAttempts - _attemptCount}',
            isError: true,
          );

          // Clear the PIN by rebuilding the widget
          _clearPin();
        }
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(
          context,
          'خطأ في التحقق من رمز PIN. حاول مرة أخرى.',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

// lib/screens/mobile/pin_enter_screen.dart - Updated build method for responsiveness
  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    return Scaffold(
      backgroundColor: const Color(AppConstants.backgroundColor),
      body: SafeArea(
        child: Center(
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(
              maxWidth: isTablet ? 500 : screenSize.width * 0.9,
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 40 : 20,
                vertical: 20,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Add top spacing for tablets
                  SizedBox(height: isTablet ? screenSize.height * 0.1 : 40),

                  // App Logo with white background
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(AppConstants.primaryColor)
                              .withOpacity(0.15),
                          spreadRadius: 3,
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      AppConstants
                          .logoPath, // Use your logo path from constants
                      height: isTablet ? 80 : 60,
                      width: isTablet ? 80 : 60,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: isTablet ? 80 : 60,
                          width: isTablet ? 80 : 60,
                          decoration: BoxDecoration(
                            color: const Color(AppConstants.primaryColor),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.lock_outline,
                            size: isTablet ? 40 : 30,
                            color: Colors.white,
                          ),
                        );
                      },
                    ),
                  ),

                  SizedBox(height: isTablet ? 40 : 30),

                  // App Name
                  Text(
                    AppConstants.appName,
                    style: TextStyle(
                      fontSize: isTablet ? 32 : 24,
                      fontWeight: FontWeight.bold,
                      color: const Color(AppConstants.primaryColor),
                    ),
                    textAlign: TextAlign.center,
                  ),

                  SizedBox(height: isTablet ? 50 : 40),

                  // PIN Title
                  Text(
                    'أدخل رمز PIN',
                    style: TextStyle(
                      fontSize: isTablet ? 24 : 20,
                      fontWeight: FontWeight.w600,
                      color: const Color(AppConstants.primaryColor),
                    ),
                    textAlign: TextAlign.center,
                  ),

                  SizedBox(height: isTablet ? 20 : 15),

                  // PIN Description
                  Text(
                    'أدخل رمز PIN المكون من ${AppConstants.pinLength} أرقام للمتابعة',
                    style: TextStyle(
                      fontSize: isTablet ? 18 : 16,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),

                  SizedBox(height: isTablet ? 40 : 30),

                  // PIN Input Field - Responsive
                  Container(
                    width: double.infinity,
                    constraints: BoxConstraints(
                      maxWidth: isTablet ? 300 : 250,
                    ),
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: PinCodeTextField(
                        key: _pinFieldKey,
                        appContext: context,
                        length: AppConstants.pinLength,
                        onChanged: _onPinChanged,
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        obscuringCharacter: '●',
                        animationType: AnimationType.fade,
                        pinTheme: PinTheme(
                          shape: PinCodeFieldShape.box,
                          borderRadius: BorderRadius.circular(12),
                          fieldHeight: isTablet ? 70 : 60,
                          fieldWidth: isTablet ? 60 : 50,
                          activeFillColor: Colors.white,
                          inactiveFillColor:
                              const Color(AppConstants.surfaceColor),
                          selectedFillColor: Colors.white,
                          activeColor: const Color(AppConstants.primaryColor),
                          inactiveColor: Colors.grey[300],
                          selectedColor: const Color(AppConstants.primaryColor),
                          borderWidth: 2,
                        ),
                        enableActiveFill: true,
                        autoFocus: true,
                        showCursor: true,
                        cursorColor: const Color(AppConstants.primaryColor),
                        textStyle: TextStyle(
                          fontSize: isTablet ? 24 : 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: isTablet ? 40 : 30),

                  // Loading Indicator
                  if (_isLoading)
                    Container(
                      padding: const EdgeInsets.all(20),
                      child: CircularProgressIndicator(
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(AppConstants.primaryColor)),
                        strokeWidth: 3,
                      ),
                    ),

                  SizedBox(height: isTablet ? 40 : 30),

                  // Attempts Warning
                  if (_attemptCount > 0)
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(isTablet ? 20 : 16),
                      decoration: BoxDecoration(
                        color: const Color(AppConstants.errorColor)
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(AppConstants.errorColor)
                              .withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.warning_rounded,
                            color: const Color(AppConstants.errorColor),
                            size: isTablet ? 24 : 20,
                          ),
                          SizedBox(width: isTablet ? 12 : 8),
                          Flexible(
                            child: Text(
                              'المحاولات المتبقية: ${_maxAttempts - _attemptCount}',
                              style: TextStyle(
                                color: const Color(AppConstants.errorColor),
                                fontWeight: FontWeight.w600,
                                fontSize: isTablet ? 18 : 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Bottom spacing for tablets
                  SizedBox(height: isTablet ? screenSize.height * 0.1 : 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
