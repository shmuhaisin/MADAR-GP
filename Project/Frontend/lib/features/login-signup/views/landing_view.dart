// ignore_for_file: unused_element

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../common_theme/ui/app_colors.dart';
import 'login_view.dart';
import 'signup_view.dart';

class LandingView extends StatefulWidget {
  const LandingView({super.key});

  @override
  State<LandingView> createState() => _LandingViewState();
}

class _LandingViewState extends State<LandingView>
    with TickerProviderStateMixin {
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
      duration: const Duration(milliseconds: 900),
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
    super.dispose();
  }

  void _goToLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginView()),
    );
  }

  void _goToSignup() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SignUpView()),
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

  Widget _glassPill({
    required IconData icon,
    required String text,
    required double scale,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: 13 * scale,
            vertical: 8 * scale,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.10),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withOpacity(0.16)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15 * scale, color: Colors.white),
              SizedBox(width: 6 * scale),
              Text(
                text,
                style: TextStyle(
                  fontFamily: 'NotoSansArabic',
                  color: Colors.white,
                  fontSize: 12 * scale,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _button({
    required String text,
    required VoidCallback onTap,
    required bool primary,
    required double scale,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54 * scale,
      child: primary
          ? ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.navy,
                elevation: 0,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: Text(
                text,
                style: TextStyle(
                  fontFamily: 'NotoSansArabic',
                  fontSize: 16 * scale,
                  fontWeight: FontWeight.w900,
                ),
              ),
            )
          : OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(
                  color: Colors.white.withOpacity(0.52),
                  width: 1.4,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: Text(
                text,
                style: TextStyle(
                  fontFamily: 'NotoSansArabic',
                  fontSize: 16 * scale,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
    );
  }

  Widget _promiseCard({required double scale}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: 16 * scale,
            vertical: 14 * scale,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.09),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withOpacity(0.14),
            ),
            boxShadow: [
              BoxShadow(
                blurRadius: 20,
                offset: const Offset(0, 10),
                color: Colors.black.withOpacity(0.08),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 38 * scale,
                height: 38 * scale,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.10),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.12),
                  ),
                ),
                child: Icon(
                  Icons.menu_book_rounded,
                  color: Colors.white,
                  size: 18 * scale,
                ),
              ),
              SizedBox(width: 12 * scale),
              Expanded(
                child: Text(
             'مع مدار، لا تضيع بين العناوين. اختر اهتماماتك، وتابع الأخبار والملخصات والتنبيهات في مساحة واحدة مرتبة وواضحة',
                  textAlign: TextAlign.right,
                  maxLines: 4,
                  overflow: TextOverflow.visible,
                  style: TextStyle(
                    fontFamily: 'NotoSansArabic',
                    color: Colors.white,
                    fontSize: 12.8 * scale,
                    fontWeight: FontWeight.w800,
                    height: 1.55,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _subtleTag({
    required String text,
    required double scale,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 10 * scale,
        vertical: 5.5 * scale,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withOpacity(0.10),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'NotoSansArabic',
          color: Colors.white.withOpacity(0.78),
          fontSize: 10.5 * scale,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
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

                      return Padding(
                        padding: EdgeInsets.fromLTRB(
                          24,
    compact ? 52 : 68,
    24,
    compact ? 10 : 14,
                        ),
                        child: FadeTransition(
                          opacity: _fade,
                          child: SlideTransition(
                            position: _slide,
                            child: Column(
                              children: [
                                _logoCore(logoSize),

                                SizedBox(height: 22 * scale),

                                Text(
                                  'في مَدار',
                                  style: TextStyle(
                                    fontFamily: 'NotoSansArabic',
                                    color: Colors.white,
                                    fontSize: 37 * scale,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.3,
                                  ),
                                ),

                                SizedBox(height: 8 * scale),

                                Text(
                                  'يقترب منك الخبر، ويدور حول ما يهمّك',
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'NotoSansArabic',
                                    color: Colors.white,
                                    fontSize: 20 * scale,
                                    fontWeight: FontWeight.w900,
                                    height: 1.28,
                                  ),
                                ),

                                SizedBox(height: 20 * scale),



   _promiseCard(scale: scale),



                                SizedBox(height: 16 * scale),

                                Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 8 * scale,
                                  runSpacing: 8 * scale,
                                  children: [
                                    _glassPill(
                                      icon: Icons.article_rounded,
                                      text: 'أخبار',
                                      scale: scale,
                                    ),
                                    _glassPill(
                                      icon: Icons.summarize_rounded,
                                      text: 'ملخصات',
                                      scale: scale,
                                    ),
                                    _glassPill(
                                      icon: Icons.groups_rounded,
                                      text: 'مجموعات',
                                      scale: scale,
                                    ),
                                    _glassPill(
                                      icon: Icons.notifications_rounded,
                                      text: 'تنبيهات',
                                      scale: scale,
                                    ),
                                  ],
                                ),

SizedBox(height: compact ? 54 * scale : 68 * scale),

                                _button(
                                  text: 'تسجيل الدخول',
                                  onTap: _goToLogin,
                                  primary: true,
                                  scale: scale,
                                ),

                                SizedBox(height: 11 * scale),

                                _button(
                                  text: 'إنشاء حساب جديد',
                                  onTap: _goToSignup,
                                  primary: false,
                                  scale: scale,
                                ),

                                SizedBox(height: 10 * scale),

                                Text(
                                  'كل ما تحتاجه لمتابعة الأخبار، في مدار واحد.',
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'NotoSansArabic',
                                    color: Colors.white.withOpacity(0.56),
                                    fontSize: 11.5 * scale,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
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