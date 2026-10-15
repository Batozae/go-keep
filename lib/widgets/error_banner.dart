import 'package:flutter/material.dart';

/// Banner pesan error dari validasi backend atau jaringan
class ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onDismiss;

  const ErrorBanner({
    super.key,
    required this.message,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDE8E8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFF8B4B4),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFF9B1C1C),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF9B1C1C),
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
          if (onDismiss != null)
            GestureDetector(
              onTap: onDismiss,
              child: const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(
                  Icons.close_rounded,
                  color: Color(0xFF9B1C1C),
                  size: 18,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

