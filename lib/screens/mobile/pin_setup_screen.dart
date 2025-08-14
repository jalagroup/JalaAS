// lib/screens/mobile/pin_setup_screen.dart
import 'package:flutter/material.dart';
import 'package:jala_as/screens/mobile/mobile_login_screen.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';

class PinSetupScreen extends StatefulWidget {
  final VoidCallback onPinSet;

  const PinSetupScreen({
    super.key,
    required this.onPinSet,
  });

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  String _currentPin = '';
  String _confirmPin = '';
  bool _isSettingPin = true;
  bool _isLoading = false;
  bool _isDisposed = false;

  // Keys to force rebuild of PinCodeTextField when needed
  Key _setupPinFieldKey = UniqueKey();
  Key _confirmPinFieldKey = UniqueKey();

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  void _onPinChanged(String value) {
    if (!mounted || _isDisposed) {
      return;
    }

    setState(() {
      if (_isSettingPin) {
        _currentPin = value;
      } else {
        _confirmPin = value;
      }
    });

    if (value.length == AppConstants.pinLength) {
      if (_isSettingPin) {
        _proceedToConfirmation();
      } else {
        _validateAndSavePin();
      }
    }
  }

  void _proceedToConfirmation() {
    if (!mounted || _isDisposed) {
      return;
    }

    setState(() {
      _isSettingPin = false;
      _confirmPin = '';
      _confirmPinFieldKey = UniqueKey(); // Force rebuild to clear the field
    });
  }

  Future<void> _validateAndSavePin() async {
    if (!mounted || _isDisposed) {
      return;
    }

    if (_currentPin != _confirmPin) {
      if (mounted && !_isDisposed) {
        Helpers.showSnackBar(
          context,
          'رمز PIN غير متطابق. حاول مرة أخرى.',
          isError: true,
        );
        _resetToStart();
      }
      return;
    }

    if (mounted && !_isDisposed) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      await Helpers.savePinCode(_currentPin);

      if (mounted && !_isDisposed) {
        Helpers.showSnackBar(context, 'تم حفظ رمز PIN بنجاح');

        // Wait a moment for the user to see the success message
        await Future.delayed(const Duration(seconds: 1));

        if (mounted && !_isDisposed) {
          widget.onPinSet();

          Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const LoginScreen()));
        }
      }
    } catch (e) {
      if (mounted && !_isDisposed) {
        Helpers.showSnackBar(
          context,
          'فشل في حفظ رمز PIN. حاول مرة أخرى.',
          isError: true,
        );
      }
    } finally {
      if (mounted && !_isDisposed) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _resetToStart() {
    if (!mounted || _isDisposed) {
      return;
    }

    setState(() {
      _isSettingPin = true;
      _currentPin = '';
      _confirmPin = '';
      _setupPinFieldKey = UniqueKey(); // Force rebuild to clear the field
      _confirmPinFieldKey = UniqueKey();
    });
  }

// lib/screens/mobile/pin_setup_screen.dart - Updated build method for responsiveness
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
                  SizedBox(height: isTablet ? screenSize.height * 0.08 : 30),

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
                            Icons.lock,
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

                  // PIN Setup Title
                  Text(
                    _isSettingPin ? 'قم بإنشاء رمز PIN' : 'أكد رمز PIN',
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
                    _isSettingPin
                        ? 'أدخل رمز PIN مكون من ${AppConstants.pinLength} أرقام لحماية التطبيق'
                        : 'أدخل رمز PIN مرة أخرى للتأكيد',
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
                      maxWidth: isTablet ? 280 : 220,
                    ),
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: _isDisposed
                          ? const SizedBox()
                          : PinCodeTextField(
                              key: _isSettingPin
                                  ? _setupPinFieldKey
                                  : _confirmPinFieldKey,
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
                                activeColor:
                                    const Color(AppConstants.primaryColor),
                                inactiveColor: Colors.grey[300],
                                selectedColor:
                                    const Color(AppConstants.primaryColor),
                                borderWidth: 2,
                              ),
                              enableActiveFill: true,
                              autoFocus: true,
                              showCursor: true,
                              cursorColor:
                                  const Color(AppConstants.primaryColor),
                              textStyle: TextStyle(
                                fontSize: isTablet ? 24 : 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),

                  SizedBox(height: isTablet ? 40 : 30),

                  // Loading or Back Button
                  if (_isLoading)
                    Container(
                      padding: const EdgeInsets.all(20),
                      child: CircularProgressIndicator(
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(AppConstants.primaryColor)),
                        strokeWidth: 3,
                      ),
                    )
                  else if (!_isSettingPin)
                    Container(
                      width: double.infinity,
                      constraints: BoxConstraints(
                        maxWidth: isTablet ? 300 : 250,
                      ),
                      child: OutlinedButton(
                        onPressed: _resetToStart,
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            vertical: isTablet ? 16 : 14,
                          ),
                          side: const BorderSide(
                            color: Color(AppConstants.primaryColor),
                            width: 2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'رجوع',
                          style: TextStyle(
                            color: const Color(AppConstants.primaryColor),
                            fontWeight: FontWeight.w600,
                            fontSize: isTablet ? 18 : 16,
                          ),
                        ),
                      ),
                    ),

                  SizedBox(height: isTablet ? 50 : 40),

                  // Security Note
                  Container(
                    padding: EdgeInsets.all(isTablet ? 20 : 16),
                    decoration: BoxDecoration(
                      color: const Color(AppConstants.accentColor)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(AppConstants.accentColor)
                            .withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: const Color(AppConstants.accentColor),
                          size: isTablet ? 24 : 20,
                        ),
                        SizedBox(width: isTablet ? 12 : 8),
                        Expanded(
                          child: Text(
                            "سيتم طلب رمز PIN عند فتح التطبيق أو بعد عدم الاستخدام لمدة 5 دقائق",
                            style: TextStyle(
                              color: const Color(AppConstants.accentColor),
                              fontSize: isTablet ? 16 : 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Bottom spacing for tablets
                  SizedBox(height: isTablet ? screenSize.height * 0.08 : 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
