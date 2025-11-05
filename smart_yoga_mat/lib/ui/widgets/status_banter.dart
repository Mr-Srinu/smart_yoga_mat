import 'package:flutter/material.dart';

class StatusBanner extends StatelessWidget {
  final bool ok;
  final String okText;
  final String badText;
  final VoidCallback onRetry;

  const StatusBanner({
    super.key,
    required this.ok,
    required this.okText,
    required this.badText,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final color = ok ? Colors.green : Colors.red;
    final icon = ok ? Icons.check_circle : Icons.error;
    final text = ok ? okText : badText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: color.shade700))),
          if (!ok)
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
        ],
      ),
    );
  }
}
