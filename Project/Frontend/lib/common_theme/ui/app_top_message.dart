import 'dart:async';
import 'package:flutter/material.dart';
import 'app_colors.dart';

enum TopMsgType {
  success,
  error,
  info,
}

class AppTopMessage {
  static OverlayEntry? _entry;
  static Timer? _timer;

  static void show(
    BuildContext context, {
    required String text,
    TopMsgType type = TopMsgType.info,
    Duration duration = const Duration(seconds: 2),
  }) {
    hide();

    final overlay = Overlay.of(context);
    final topPadding = MediaQuery.of(context).padding.top;

    final colors = _colors(type);
    final icon = _icon(type);

    _entry = OverlayEntry(
      builder: (_) {
        return Positioned(
          top: topPadding + 10,
          left: 10,
          right: 10,
          child: Material(
            color: Colors.transparent,
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: colors.background,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colors.border,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      icon,
                      color: colors.icon,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        text,
                        textAlign: TextAlign.right,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'NotoSansArabic',
                          height: 1.35,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: hide,
                      child: Icon(
                        Icons.close_rounded,
                        color: colors.icon,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(_entry!);

    _timer = Timer(duration, hide);
  }

  static void hide() {
    _timer?.cancel();
    _timer = null;

    _entry?.remove();
    _entry = null;
  }

  static _TopMessageColors _colors(TopMsgType type) {
    switch (type) {
      case TopMsgType.success:
        return const _TopMessageColors(
          background: Color(0xFFEAFBF3),
          border: Color(0xFFBDEDD7),
          text: Color(0xFF087A3D),
          icon: Color(0xFF17C37B),
        );

      case TopMsgType.error:
        return const _TopMessageColors(
          background: Color(0xFFFFEEF0),
          border: Color(0xFFFFC7CF),
          text: Color(0xFFD83A4B),
          icon: Color(0xFFD83A4B),
        );

      case TopMsgType.info:
        return const _TopMessageColors(
          background: Color(0xFFEFF5FF),
          border: Color(0xFFCFE0FF),
          text: AppColors.navy,
          icon: AppColors.navy,
        );
    }
  }

  static IconData _icon(TopMsgType type) {
    switch (type) {
      case TopMsgType.success:
        return Icons.check_circle_rounded;
      case TopMsgType.error:
        return Icons.error_rounded;
      case TopMsgType.info:
        return Icons.info_rounded;
    }
  }
}

class _TopMessageColors {
  final Color background;
  final Color border;
  final Color text;
  final Color icon;

  const _TopMessageColors({
    required this.background,
    required this.border,
    required this.text,
    required this.icon,
  });
}