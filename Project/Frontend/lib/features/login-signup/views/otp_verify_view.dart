// otp_verify_view.dart
// ignore_for_file: deprecated_member_use

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../common_theme/ui/app_colors.dart';
import '../../../common_theme/ui/app_top_message.dart';

import '../viewmodel/otp_verify_viewmodel.dart';
import 'login_view.dart';
import 'reset_password_view.dart';

enum OtpFlow { signup, forgotPassword, changePhone }

class OtpVerifyView extends StatefulWidget {
  final String phone;
  final OtpFlow flow;
  final String? prefillIdentifier;

  const OtpVerifyView({
    super.key,
    required this.phone,
    required this.flow,
    this.prefillIdentifier,
  });

  @override
  State<OtpVerifyView> createState() => _OtpVerifyViewState();
}

class _OtpVerifyViewState extends State<OtpVerifyView>
    with TickerProviderStateMixin {
  late final List<TextEditingController> _ctrs;
  late final List<FocusNode> _fns;

  late final AnimationController _backgroundController;
  late final AnimationController _fadeController;

  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();

    _ctrs = List.generate(6, (_) => TextEditingController());
    _fns = List.generate(6, (_) => FocusNode());

    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..forward();

    _fade = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _slide = Tween<Offset>(
      begin: const Offset(0, 0.045),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: Curves.easeOutCubic,
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fns.first.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _fadeController.dispose();

    for (final controller in _ctrs) {
      controller.dispose();
    }

    for (final focusNode in _fns) {
      focusNode.dispose();
    }

    super.dispose();
  }

  void _syncCtrsFromVm(OtpVerifyViewModel vm) {
    for (int i = 0; i < 6; i++) {
      final wanted = vm.digits[i];

      if (_ctrs[i].text != wanted) {
        _ctrs[i].text = wanted;
        _ctrs[i].selection = TextSelection.collapsed(offset: wanted.length);
      }
    }
  }

  String _normalizeDigits(String input) {
    const arabicToEnglish = {
      '٠': '0',
      '١': '1',
      '٢': '2',
      '٣': '3',
      '٤': '4',
      '٥': '5',
      '٦': '6',
      '٧': '7',
      '٨': '8',
      '٩': '9',
      '۰': '0',
      '۱': '1',
      '۲': '2',
      '۳': '3',
      '۴': '4',
      '۵': '5',
      '۶': '6',
      '۷': '7',
      '۸': '8',
      '۹': '9',
    };

    return input.split('').map((ch) => arabicToEnglish[ch] ?? ch).join();
  }

  void _handleChange(OtpVerifyViewModel vm, int index, String value) {
    final digitsOnly = _normalizeDigits(value).replaceAll(RegExp(r'\D'), '');

    if (digitsOnly.isEmpty) {
      vm.setDigit(index, '');

      if (index > 0) {
        _fns[index - 1].requestFocus();
      }

      return;
    }

    if (digitsOnly.length > 1) {
      vm.setCodeFromPaste(digitsOnly, startIndex: index);

      final nextIndex = (index + digitsOnly.length).clamp(0, 6);

      if (nextIndex < 6) {
        _fns[nextIndex].requestFocus();
      } else {
        FocusScope.of(context).unfocus();
      }

      return;
    }

    vm.setDigit(index, digitsOnly[0]);

    if (index < 5) {
      _fns[index + 1].requestFocus();
    } else {
      FocusScope.of(context).unfocus();
    }
  }

  Future<void> _verify(OtpVerifyViewModel vm) async {
    FocusScope.of(context).unfocus();

    if (widget.flow == OtpFlow.signup) {
      final ok = await vm.verifySignupOtp();
      if (!mounted) return;

      if (!ok) return;

      AppTopMessage.show(
        context,
        text: 'تم توثيق الحساب، يمكنك الآن تسجيل الدخول',
        type: TopMsgType.success,
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => LoginView(
            prefillIdentifier: widget.prefillIdentifier,
          ),
        ),
        (_) => false,
      );

      return;
    }

    if (widget.flow == OtpFlow.forgotPassword) {
      final resetToken = await vm.verifyForgotPasswordOtpAndGetResetToken();
      if (!mounted) return;

      if (resetToken == null) return;

      AppTopMessage.show(
        context,
        text: 'تم التحقق من الرمز',
        type: TopMsgType.success,
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResetPasswordView(resetToken: resetToken),
        ),
      );

      return;
    }

    final phoneChangeVerificationToken =
        await vm.verifyPhoneChangeOtpAndGetToken();

    if (!mounted) return;

    if (phoneChangeVerificationToken == null ||
        phoneChangeVerificationToken.trim().isEmpty) {
      return;
    }

    Navigator.pop(context, {
      'verified': true,
      'phoneChangeVerificationToken': phoneChangeVerificationToken.trim(),
    });
  }

  Future<void> _resend(OtpVerifyViewModel vm) async {
    vm.resendLocalOnly();

    if (!mounted) return;

    AppTopMessage.show(
      context,
      text:
          'تمت إعادة تهيئة حقل الرمز. اربط زر إعادة الإرسال مع الخادم لإرسال رمز جديد فعليًا',
      type: TopMsgType.info,
    );

    _fns.first.requestFocus();
  }

  String get _title {
    switch (widget.flow) {
      case OtpFlow.signup:
        return 'رمز التحقق';
      case OtpFlow.forgotPassword:
        return 'رمز التحقق';
      case OtpFlow.changePhone:
        return 'رمز التحقق';
    }
  }

  String get _subtitle {
    switch (widget.flow) {
      case OtpFlow.signup:
        return 'أدخل الرمز المرسل لتوثيق حسابك في مدار.';
      case OtpFlow.forgotPassword:
        return 'أدخل الرمز المرسل لإعادة تعيين كلمة المرور.';
      case OtpFlow.changePhone:
        return 'أدخل الرمز المرسل لتوثيق رقم الجوال الجديد.';
    }
  }

  Widget _logoCore(double size) {
    final radius = size * 0.24;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            blurRadius: 38,
            spreadRadius: 4,
            color: AppColors.accentBlue.withOpacity(0.28),
          ),
          BoxShadow(
            blurRadius: 22,
            offset: const Offset(0, 14),
            color: Colors.black.withOpacity(0.22),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: EdgeInsets.all(size * 0.08),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: Colors.white.withOpacity(0.24),
                width: 1.2,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.18),
                  Colors.white.withOpacity(0.06),
                ],
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius * 0.72),
              child: Image.asset(
                'assets/images/madar-logo1.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _otpTextField(OtpVerifyViewModel vm, int index) {
    return TextField(
      controller: _ctrs[index],
      focusNode: _fns[index],
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      keyboardType: TextInputType.number,
      maxLength: 1,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩]')),
        TextInputFormatter.withFunction((oldValue, newValue) {
          final converted = _normalizeDigits(newValue.text);

          return TextEditingValue(
            text: converted,
            selection: TextSelection.collapsed(offset: converted.length),
          );
        }),
      ],
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w900,
        color: AppColors.navy,
        fontFamily: 'NotoSansArabic',
      ),
      decoration: const InputDecoration(
        border: InputBorder.none,
        counterText: '',
        contentPadding: EdgeInsets.zero,
      ),
      onChanged: (value) => _handleChange(vm, index, value),
    );
  }

  Widget _otpBox(
    OtpVerifyViewModel vm,
    int index, {
    required double width,
    required double height,
  }) {
    final filled = vm.digits[index].isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: filled
              ? AppColors.accentBlue.withOpacity(0.95)
              : Colors.white.withOpacity(0.75),
          width: filled ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 10),
            color: Colors.black.withOpacity(0.14),
          ),
        ],
      ),
      child: _otpTextField(vm, index),
    );
  }

  Widget _otpRow(OtpVerifyViewModel vm) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = ((constraints.maxWidth - 36) / 6).clamp(40.0, 50.0);
        final boxHeight = (boxWidth + 8).clamp(50.0, 58.0);

        return Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              6,
              (index) => _otpBox(
                vm,
                index,
                width: boxWidth,
                height: boxHeight,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _primaryBtn({
    required String label,
    required VoidCallback onTap,
    required bool loading,
    required bool enabled,
    required double scale,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54 * scale,
      child: ElevatedButton(
        onPressed: enabled && !loading ? onTap : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          disabledBackgroundColor: Colors.white.withOpacity(0.35),
          foregroundColor: AppColors.navy,
          disabledForegroundColor: Colors.white.withOpacity(0.70),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.navy,
                ),
              )
            : Text(
                label,
                style: TextStyle(
                  fontSize: 16 * scale,
                  fontWeight: FontWeight.w900,
                  color: AppColors.navy,
                  fontFamily: 'NotoSansArabic',
                ),
              ),
      ),
    );
  }

  Widget _apiErrorBox(String message) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: AppColors.danger.withOpacity(0.14),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.danger.withOpacity(0.35),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFFFD6D6),
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFFFD6D6),
                    height: 1.4,
                    fontFamily: 'NotoSansArabic',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _form(OtpVerifyViewModel vm, double scale) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20 * scale,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              fontFamily: 'NotoSansArabic',
            ),
          ),

          SizedBox(height: 8 * scale),

          Text(
            _subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13 * scale,
              fontWeight: FontWeight.w800,
              color: Colors.white.withOpacity(0.78),
              height: 1.55,
              fontFamily: 'NotoSansArabic',
            ),
          ),

          SizedBox(height: 6 * scale),

          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              widget.phone,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13 * scale,
                fontWeight: FontWeight.w900,
                color: Colors.white.withOpacity(0.90),
                height: 1.45,
                fontFamily: 'NotoSansArabic',
              ),
            ),
          ),

          SizedBox(height: 24 * scale),

          _otpRow(vm),

          if (vm.otpError != null) ...[
            SizedBox(height: 10 * scale),
            Text(
              vm.otpError!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                color: Color(0xFFFFD6D6),
                fontFamily: 'NotoSansArabic',
              ),
            ),
          ],

          if (vm.apiError != null) ...[
            SizedBox(height: 10 * scale),
            _apiErrorBox(vm.apiError!),
          ],

          SizedBox(height: 18 * scale),

          _primaryBtn(
            label: 'تحقق',
            loading: vm.loading,
            enabled: vm.canVerify,
            scale: scale,
            onTap: () => _verify(vm),
          ),

          SizedBox(height: 16 * scale),

          Center(
            child: GestureDetector(
              onTap: vm.canResend ? () => _resend(vm) : null,
              child: Text(
                vm.seconds == 0
                    ? 'إعادة إرسال الرمز'
                    : 'إعادة الإرسال خلال ${vm.seconds} ثانية',
                style: TextStyle(
                  fontSize: 13 * scale,
                  fontWeight: FontWeight.w900,
                  color: vm.seconds == 0
                      ? Colors.white
                      : Colors.white.withOpacity(0.55),
                  decoration: vm.seconds == 0
                      ? TextDecoration.underline
                      : TextDecoration.none,
                  decorationColor: Colors.white,
                  fontFamily: 'NotoSansArabic',
                ),
              ),
            ),
          ),

          SizedBox(height: 12 * scale),

          Center(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Text(
                'رجوع',
                style: TextStyle(
                  fontSize: 13 * scale,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.white,
                  fontFamily: 'NotoSansArabic',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => OtpVerifyViewModel(phone: widget.phone),
      child: Consumer<OtpVerifyViewModel>(
        builder: (context, vm, _) {
          _syncCtrsFromVm(vm);

          return Directionality(
            textDirection: TextDirection.rtl,
            child: Theme(
              data: Theme.of(context).copyWith(
                textTheme: Theme.of(context).textTheme.apply(
                      fontFamily: 'NotoSansArabic',
                    ),
              ),
              child: Scaffold(
                backgroundColor: AppColors.navy,
                body: AnimatedBuilder(
                  animation: _backgroundController,
                  builder: (context, _) {
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topRight,
                                end: Alignment.bottomLeft,
                                colors: [
                                  Color(0xFF06152F),
                                  Color(0xFF173B7E),
                                  Color(0xFF05132B),
                                ],
                              ),
                            ),
                          ),
                        ),

                        Positioned.fill(
                          child: CustomPaint(
                            painter: _SoftParticlesPainter(
                              progress: _backgroundController.value,
                            ),
                          ),
                        ),

                        Positioned.fill(
                          child: CustomPaint(
                            painter: _SoftRibbonsPainter(
                              progress: _backgroundController.value,
                            ),
                          ),
                        ),

                        Positioned(
                          top: -130,
                          right: -90,
                          child: Container(
                            width: 280,
                            height: 280,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.045),
                            ),
                          ),
                        ),

                        Positioned(
                          bottom: -160,
                          left: -115,
                          child: Container(
                            width: 340,
                            height: 340,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.accentBlue.withOpacity(0.10),
                            ),
                          ),
                        ),

                        SafeArea(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final h = constraints.maxHeight;
                              final compact = h < 760;
                              final scale = compact ? 0.90 : 1.0;
                              final logoSize = compact ? 126.0 : 145.0;

                              return SingleChildScrollView(
                                keyboardDismissBehavior:
                                    ScrollViewKeyboardDismissBehavior.onDrag,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(minHeight: h),
                                  child: Padding(
                                    padding: EdgeInsets.fromLTRB(
                                      24,
                                      compact ? 28 : 42,
                                      24,
                                      22,
                                    ),
                                    child: FadeTransition(
                                      opacity: _fade,
                                      child: SlideTransition(
                                        position: _slide,
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            _logoCore(logoSize),
                                            SizedBox(height: 38 * scale),
                                            _form(vm, scale),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SoftParticlesPainter extends CustomPainter {
  final double progress;

  _SoftParticlesPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()..color = Colors.white.withOpacity(0.20);

    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.040)
      ..strokeWidth = 1;

    final points = <Offset>[];

    for (int i = 0; i < 24; i++) {
      final seed = i * 39.0;

      final x =
          (math.sin(seed + progress * math.pi * 2) * 0.5 + 0.5) * size.width;

      final y = ((i * 79.0) % size.height) +
          math.sin(progress * math.pi * 2 + i) * 8;

      points.add(Offset(x, y % size.height));
    }

    for (int i = 0; i < points.length; i++) {
      final p = points[i];

      canvas.drawCircle(
        p,
        i % 4 == 0 ? 1.8 : 1.1,
        dotPaint,
      );

      if (i > 0 && i % 4 == 0) {
        final prev = points[i - 1];

        if ((p - prev).distance < 140) {
          canvas.drawLine(p, prev, linePaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SoftParticlesPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _SoftRibbonsPainter extends CustomPainter {
  final double progress;

  _SoftRibbonsPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white.withOpacity(0.025);

    final paint2 = Paint()
      ..style = PaintingStyle.fill
      ..color = AppColors.accentBlue.withOpacity(0.035);

    final shift = math.sin(progress * math.pi * 2) * 18;

    final path1 = Path()
      ..moveTo(-40, size.height * 0.18 + shift)
      ..quadraticBezierTo(
        size.width * 0.35,
        size.height * 0.10 + shift,
        size.width + 40,
        size.height * 0.22 + shift,
      )
      ..lineTo(size.width + 40, size.height * 0.36 + shift)
      ..quadraticBezierTo(
        size.width * 0.40,
        size.height * 0.24 + shift,
        -40,
        size.height * 0.32 + shift,
      )
      ..close();

    final path2 = Path()
      ..moveTo(-40, size.height * 0.68 - shift)
      ..quadraticBezierTo(
        size.width * 0.45,
        size.height * 0.56 - shift,
        size.width + 40,
        size.height * 0.72 - shift,
      )
      ..lineTo(size.width + 40, size.height * 0.90 - shift)
      ..quadraticBezierTo(
        size.width * 0.42,
        size.height * 0.78 - shift,
        -40,
        size.height * 0.86 - shift,
      )
      ..close();

    canvas.drawPath(path1, paint1);
    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant _SoftRibbonsPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}