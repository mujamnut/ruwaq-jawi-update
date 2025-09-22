import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/services/supabase_service.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String? email;
  final String? message;

  const EmailVerificationScreen({
    super.key,
    this.email,
    this.message,
  });

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen>
    with TickerProviderStateMixin {
  bool _isResending = false;
  bool _isVerifying = false;
  bool _isVerified = false;

  final List<TextEditingController> _otpControllers =
      List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(6, (index) => FocusNode());

  // OTP Timer
  Timer? _otpTimer;
  int _otpTimeLeft = 60; // 1 minute in seconds
  bool _isOTPExpired = false;

  // Resend Cooldown Timer
  Timer? _resendTimer;
  int _resendCooldown = 0;
  bool _canResend = true;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startOTPTimer();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    // Start animations
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _slideController.forward();
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      _scaleController.forward();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    _otpTimer?.cancel();
    _resendTimer?.cancel();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _resendVerificationEmail() async {
    if (widget.email == null) return;

    setState(() => _isResending = true);

    try {
      await SupabaseService.client.auth.resend(
        type: OtpType.signup,
        email: widget.email!,
        emailRedirectTo: 'ruwaqjawi://auth/confirm',
      );

      _resetOTPTimer(); // Reset timer when new OTP is sent
      _clearOTP(); // Clear current OTP
      _startResendCooldown(); // Start cooldown timer
      _showSuccessSnackBar('Kod verifikasi baharu telah dihantar!');
    } on AuthException catch (e) {
      _showErrorSnackBar(e.message);
    } catch (e) {
      _showErrorSnackBar('Terjadi kesalahan. Silakan coba lagi.');
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedAlert01,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.red[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.green[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  Future<void> _verifyOTPToken() async {
    if (widget.email == null) return;

    // Check if OTP is expired
    if (_isOTPExpired) {
      _showErrorSnackBar('Kod telah tamat tempoh. Sila minta kod baharu.');
      return;
    }

    // Get OTP token from input fields
    String token = _otpControllers.map((e) => e.text).join();
    if (token.length != 6) {
      _showErrorSnackBar('Sila masukkan kod 6 digit yang lengkap.');
      return;
    }

    setState(() => _isVerifying = true);

    try {
      final response = await SupabaseService.client.auth.verifyOTP(
        email: widget.email!,
        token: token,
        type: OtpType.email,
      );

      if (response.user != null) {
        _otpTimer?.cancel(); // Stop timer on success
        setState(() => _isVerified = true);
        _showSuccessSnackBar('Email berjaya disahkan!');

        // User is now authenticated with verified email
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          context.go('/auth/welcome');
        }
      } else {
        _showErrorSnackBar('Kod tidak sah atau telah tamat tempoh.');
      }
    } on AuthException catch (e) {
      _showErrorSnackBar(e.message);
    } catch (e) {
      _showErrorSnackBar('Terjadi kesalahan. Silakan coba lagi.');
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  void _clearOTP() {
    for (var controller in _otpControllers) {
      controller.clear();
    }
    _focusNodes[0].requestFocus();
  }

  void _startOTPTimer() {
    _otpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_otpTimeLeft > 0) {
            _otpTimeLeft--;
          } else {
            _isOTPExpired = true;
            timer.cancel();
          }
        });
      }
    });
  }

  void _resetOTPTimer() {
    _otpTimer?.cancel();
    setState(() {
      _otpTimeLeft = 60; // Reset to 1 minute
      _isOTPExpired = false;
    });
    _startOTPTimer();
  }

  void _startResendCooldown() {
    setState(() {
      _resendCooldown = 30; // 30 seconds cooldown
      _canResend = false;
    });

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_resendCooldown > 0) {
            _resendCooldown--;
          } else {
            _canResend = true;
            timer.cancel();
          }
        });
      }
    });
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _onOTPChanged(String value, int index) {
    // Remove any non-digit characters
    if (value.isNotEmpty && !RegExp(r'^[0-9]$').hasMatch(value)) {
      _otpControllers[index].clear();
      return;
    }

    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }

    // Auto verify when all 6 digits are entered
    if (index == 5 && value.isNotEmpty) {
      String fullToken = _otpControllers.map((e) => e.text).join();
      if (fullToken.length == 6) {
        Future.delayed(const Duration(milliseconds: 100), () {
          _verifyOTPToken();
        });
      }
    }
  }

  void _onOTPKeyEvent(KeyEvent event, int index) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.backspace) {
      if (_otpControllers[index].text.isEmpty && index > 0) {
        // If current field is empty and backspace pressed, go to previous field and clear it
        _focusNodes[index - 1].requestFocus();
        _otpControllers[index - 1].clear();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedArrowLeft01,
              color: AppTheme.textPrimaryColor,
              size: 20,
            ),
          ),
          onPressed: () => context.go('/login'),
        ),
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height -
                            MediaQuery.of(context).padding.top -
                            kToolbarHeight - 48,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                  const SizedBox(height: 32),

                  // Email verification icon with animation
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppTheme.primaryColor.withValues(alpha: 0.1),
                            AppTheme.primaryColor.withValues(alpha: 0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Center(
                        child: _isVerified
                            ? HugeIcon(
                                icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                                color: Colors.green[600] ?? Colors.green,
                                size: 60,
                              )
                            : HugeIcon(
                                icon: HugeIcons.strokeRoundedMail02,
                                color: AppTheme.primaryColor,
                                size: 60,
                              ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Title
                  TweenAnimationBuilder(
                    duration: const Duration(milliseconds: 600),
                    tween: Tween<double>(begin: 0, end: 1),
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, 20 * (1 - value)),
                          child: Text(
                            _isVerified
                                ? 'Email Disahkan!'
                                : 'Periksa Email Anda',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimaryColor,
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  // Email display
                  if (widget.email != null) ...[
                    TweenAnimationBuilder(
                      duration: const Duration(milliseconds: 800),
                      tween: Tween<double>(begin: 0, end: 1),
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, 20 * (1 - value)),
                            child: Column(
                              children: [
                                Text(
                                  _isVerified
                                      ? 'Akaun anda telah berjaya diaktifkan'
                                      : 'Kami telah mengirim link verifikasi ke:',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: AppTheme.textSecondaryColor,
                                      ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withValues(
                                      alpha: 0.05,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppTheme.primaryColor.withValues(
                                        alpha: 0.2,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    widget.email!,
                                    style: Theme.of(context).textTheme.bodyLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.primaryColor,
                                        ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Status message
                  if (widget.message != null) ...[
                    TweenAnimationBuilder(
                      duration: const Duration(milliseconds: 1000),
                      tween: Tween<double>(begin: 0, end: 1),
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, 20 * (1 - value)),
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.blue[200]!),
                              ),
                              child: Row(
                                children: [
                                  HugeIcon(
                                    icon: HugeIcons
                                        .strokeRoundedInformationCircle,
                                    color: Colors.blue[700] ?? Colors.blue,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      widget.message!,
                                      style: TextStyle(
                                        color: Colors.blue[800],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                  ],

                  // OTP Input Fields
                  if (!_isVerified) ...[
                    TweenAnimationBuilder(
                      duration: const Duration(milliseconds: 1200),
                      tween: Tween<double>(begin: 0, end: 1),
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, 20 * (1 - value)),
                            child: Column(
                              children: [
                                Text(
                                  'Masukkan kod 6 digit yang dihantar ke email anda:',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: AppTheme.textSecondaryColor,
                                      ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),

                                // Timer Display
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _isOTPExpired
                                        ? Colors.red[50]
                                        : Colors.blue[50],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _isOTPExpired
                                          ? Colors.red[300]!
                                          : Colors.blue[300]!,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      HugeIcon(
                                        icon: _isOTPExpired
                                            ? HugeIcons.strokeRoundedAlert01
                                            : HugeIcons.strokeRoundedTime03,
                                        color: _isOTPExpired
                                            ? Colors.red[600] ?? Colors.red
                                            : Colors.blue[600] ?? Colors.blue,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _isOTPExpired
                                            ? 'Kod Tamat Tempoh'
                                            : 'Tamat dalam: ${_formatTime(_otpTimeLeft)}',
                                        style: TextStyle(
                                          color: _isOTPExpired
                                              ? Colors.red[600] ?? Colors.red
                                              : Colors.blue[600] ?? Colors.blue,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // OTP Input Fields
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: List.generate(6, (index) {
                                    bool isFieldFocused = _focusNodes[index].hasFocus;
                                    bool hasValue = _otpControllers[index].text.isNotEmpty;
                                    bool isDisabled = _isOTPExpired || _isVerifying;

                                    return Container(
                                      width: 50,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: isDisabled
                                              ? Colors.grey[300]!
                                              : isFieldFocused
                                                  ? AppTheme.primaryColor
                                                  : hasValue
                                                      ? Colors.green[400]!
                                                      : Colors.grey[300]!,
                                          width: isFieldFocused && !isDisabled ? 2 : 1,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        color: isDisabled
                                            ? Colors.grey[100]
                                            : hasValue
                                                ? Colors.green[50]
                                                : Colors.grey[50],
                                        boxShadow: isFieldFocused && !isDisabled
                                            ? [
                                                BoxShadow(
                                                  color: AppTheme.primaryColor.withValues(alpha: 0.2),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: KeyboardListener(
                                        focusNode: FocusNode(),
                                        onKeyEvent: (event) => _onOTPKeyEvent(event, index),
                                        child: TextField(
                                          controller: _otpControllers[index],
                                          focusNode: _focusNodes[index],
                                          textAlign: TextAlign.center,
                                          keyboardType: TextInputType.number,
                                          maxLength: 1,
                                          enabled: !isDisabled,
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: isDisabled
                                              ? Colors.grey[400]
                                              : hasValue
                                                  ? Colors.green[700]
                                                  : AppTheme.textPrimaryColor,
                                        ),
                                        decoration: const InputDecoration(
                                          border: InputBorder.none,
                                          enabledBorder: InputBorder.none,
                                          focusedBorder: InputBorder.none,
                                          disabledBorder: InputBorder.none,
                                          errorBorder: InputBorder.none,
                                          focusedErrorBorder: InputBorder.none,
                                          counterText: '',
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                        onChanged: (value) => _onOTPChanged(value, index),
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly,
                                        ],
                                        ),
                                      ),
                                    );
                                  }),
                                ),

                                const SizedBox(height: 16),

                                // Clear OTP Button
                                TextButton.icon(
                                  onPressed: _clearOTP,
                                  icon: HugeIcon(
                                    icon: HugeIcons.strokeRoundedDelete02,
                                    color: AppTheme.textSecondaryColor,
                                    size: 16,
                                  ),
                                  label: Text(
                                    'Kosongkan Kod',
                                    style: TextStyle(
                                      color: AppTheme.textSecondaryColor,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 32),
                  ],

                  // Action buttons
                  TweenAnimationBuilder(
                    duration: const Duration(milliseconds: 1400),
                    tween: Tween<double>(begin: 0, end: 1),
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, 20 * (1 - value)),
                          child: Column(
                            children: [
                              if (!_isVerified) ...[
                                CustomButton(
                                  text: 'Sahkan Kod',
                                  onPressed: !_isVerifying && !_isOTPExpired
                                      ? _verifyOTPToken
                                      : null,
                                  isLoading: _isVerifying,
                                ),
                                const SizedBox(height: 16),

                                CustomButton(
                                  text: _isOTPExpired
                                      ? 'Hantar Kod Baharu'
                                      : !_canResend
                                          ? 'Tunggu ${_resendCooldown}s'
                                          : 'Kirim Ulang Kod',
                                  onPressed: widget.email != null &&
                                            !_isResending &&
                                            _canResend
                                      ? _resendVerificationEmail
                                      : null,
                                  isLoading: _isResending,
                                  isOutlined: true,
                                ),
                                const SizedBox(height: 16),
                              ] else ...[
                                CustomButton(
                                  text: 'Lanjut ke Beranda',
                                  onPressed: () => context.go('/auth/welcome'),
                                ),
                                const SizedBox(height: 16),
                              ],

                              // Back to login button
                              TextButton(
                                onPressed: () => context.go('/login'),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                ),
                                child: Text(
                                  'Kembali ke Login',
                                  style: TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 32),

                  // Info card
                  if (!_isVerified) ...[
                    TweenAnimationBuilder(
                      duration: const Duration(milliseconds: 1600),
                      tween: Tween<double>(begin: 0, end: 1),
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, 20 * (1 - value)),
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey[200]!),
                              ),
                              child: Column(
                                children: [
                                  HugeIcon(
                                    icon: HugeIcons
                                        .strokeRoundedInformationCircle,
                                    color: AppTheme.textSecondaryColor,
                                    size: 24,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Kod akan tamat tempoh dalam 10 minit. Jika tidak menerima kod, sila periksa folder spam.',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: AppTheme.textSecondaryColor,
                                          height: 1.5,
                                        ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
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
