import 'package:flutter/material.dart';

class ViewsPill extends StatelessWidget {
  final int views;

  const ViewsPill({super.key, required this.views});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.remove_red_eye,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 6),
          Text(
            '$views',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontFamily: 'NotoSansArabic',
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}