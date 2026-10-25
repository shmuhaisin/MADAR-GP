// reset_password_view.dart
// ignore_for_file: deprecated_member_use

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../common_theme/ui/app_colors.dart';
import '../../../common_theme/ui/app_top_message.dart';

import '../viewmodel/reset_password_viewmodel.dart';
import 'login_view.dart';

class ResetPasswordView extends StatefulWidget {
  final String resetToken;

  const ResetPasswordView({
    super.key,
    required this.resetToken,
  });

  @override
  State<ResetPasswordView> createState() => _ResetPasswordViewState();
}

class _ResetPasswordViewState extends State<ResetPasswordView>
    with TickerProviderStateMixin {
  final TextEditingController _newPassCtrl = TextEditingController();
  final TextEditingController _confirmPassCtrl = TextEditingController();

  final FocusNode _newPassFocus = FocusNode();
  final FocusNode _confirmPassFocus = FocusNode();

  late final AnimationController _backgroundController;
  late final AnimationController _fadeController;

  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();

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
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _fadeController.dispose();

    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    _newPassFocus.dispose();
    _confirmPassFocus.dispose();

    super.dispose();
  }

  void _syncControllersFromVm(ResetPasswordViewModel vm) {
    if (_newPassCtrl.text != vm.newPassword) {
      _newPassCtrl.text = vm.newPassword;
      _newPassCtrl.selection = TextSelection.collapsed(
        offset: _newPassCtrl.text.length,
      );
    }

    if (_confirmPassCtrl.text != vm.confirmPassword) {
      _confirmPassCtrl.text = vm.confirmPassword;
      _confirmPassCtrl.selection = TextSelection.collapsed(
        offset: _confirmPassCtrl.text.length,
      );
    }
  }

  Future<void> _submit(ResetPasswordViewModel vm) async {
    FocusScope.of(context).unfocus();

    if (vm.loading) return;

    final ok = await vm.submit();
    if (!mounted) return;

    if (!ok) return;

    AppTopMessage.show(
      context,
      text: 'تم تغيير كلمة المرور بنجاح',
      type: TopMsgType.success,
    );

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginView()),
      (_) => false,
    );
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

  Widget _labelWithStar(String text, {bool required = false}) {
    return RichText(
      textDirection: TextDirection.rtl,
      text: TextSpan(
        style: TextStyle(
          fontFamily: 'NotoSansArabic',
          fontSize: 14,
          fontWeight: FontWeight.w900,
          color: AppColors.text.withOpacity(0.58),
        ),
        children: [
          TextSpan(text: text),
          if (required) ...const [
            TextSpan(text: ' '),
            TextSpan(
              text: '*',
              style: TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.w900,
                fontFamily: 'NotoSansArabic',
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }

  InputDecoration _pillDec({
    required String label,
    required IconData icon,
    bool requiredMark = false,
    Widget? suffix,
  }) {
    return InputDecoration(
      label: _labelWithStar(label, required: requiredMark),
      floatingLabelBehavior: FloatingLabelBehavior.never,
      hintTextDirection: TextDirection.rtl,
      hintStyle: TextStyle(
        color: AppColors.text.withOpacity(0.35),
        fontWeight: FontWeight.w800,
        fontFamily: 'NotoSansArabic',
        fontSize: 13,
      ),
      filled: true,
      fillColor: Colors.white,
      prefixIcon: Icon(
        icon,
        color: AppColors.navy,
        size: 20,
      ),
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 15,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: BorderSide(
          color: Colors.white.withOpacity(0.75),
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: BorderSide(
          color: AppColors.accentBlue.withOpacity(0.95),
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: const BorderSide(
          color: AppColors.danger,
          width: 1.2,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: const BorderSide(
          color: AppColors.danger,
          width: 1.4,
        ),
      ),
    );
  }

  Widget _fieldError(String message) {
    return Text(
      message,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w900,
        color: Color(0xFFFFD6D6),
        fontFamily: 'NotoSansArabic',
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

  Widget _primaryBtn({
    required String label,
    required bool loading,
    required bool enabled,
    required VoidCallback onTap,
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

  Widget _form(ResetPasswordViewModel vm, double scale) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'تعيين كلمة مرور جديدة',
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
            'اكتب كلمة مرور جديدة لحسابك، ثم أكدها لإكمال إعادة التعيين.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13 * scale,
              fontWeight: FontWeight.w800,
              color: Colors.white.withOpacity(0.78),
              height: 1.55,
              fontFamily: 'NotoSansArabic',
            ),
          ),

          SizedBox(height: 24 * scale),

          TextField(
            controller: _newPassCtrl,
            focusNode: _newPassFocus,
            textDirection: TextDirection.ltr,
            obscureText: vm.obscure1,
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.deny(
                RegExp(
                  r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]',
                ),
              ),
            ],
            onChanged: vm.setNewPassword,
            onSubmitted: (_) {
              FocusScope.of(context).requestFocus(_confirmPassFocus);
            },
            decoration: _pillDec(
              label: 'كلمة المرور الجديدة',
              requiredMark: true,
              icon: Icons.lock_outline_rounded,
              suffix: IconButton(
                onPressed: vm.toggleObscure1,
                icon: Icon(
                  vm.obscure1
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.navy,
                ),
              ),
            ),
          ),

          if (vm.newPassError != null) ...[
            SizedBox(height: 8 * scale),
            _fieldError(vm.newPassError!),
          ],

          SizedBox(height: 13 * scale),

          TextField(
            controller: _confirmPassCtrl,
            focusNode: _confirmPassFocus,
            textDirection: TextDirection.ltr,
            obscureText: vm.obscure2,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.deny(
                RegExp(
                  r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]',
                ),
              ),
            ],
            onChanged: vm.setConfirmPassword,
            onSubmitted: (_) {
              if (vm.canSubmit && !vm.loading) {
                _submit(vm);
              }
            },
            decoration: _pillDec(
              label: 'تأكيد كلمة المرور',
              requiredMark: true,
              icon: Icons.lock_outline_rounded,
              suffix: IconButton(
                onPressed: vm.toggleObscure2,
                icon: Icon(
                  vm.obscure2
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.navy,
                ),
              ),
            ),
          ),

          if (vm.confirmError != null) ...[
            SizedBox(height: 8 * scale),
            _fieldError(vm.confirmError!),
          ],

          if (vm.apiError != null) ...[
            SizedBox(height: 10 * scale),
            _apiErrorBox(vm.apiError!),
          ],

          SizedBox(height: 18 * scale),

          _primaryBtn(
            label: 'تغيير كلمة المرور',
            loading: vm.loading,
            enabled: vm.canSubmit,
            scale: scale,
            onTap: () => _submit(vm),
          ),

          SizedBox(height: 16 * scale),

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
      create: (_) => ResetPasswordViewModel(resetToken: widget.resetToken),
      child: Consumer<ResetPasswordViewModel>(
        builder: (context, vm, _) {
          _syncControllersFromVm(vm);

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