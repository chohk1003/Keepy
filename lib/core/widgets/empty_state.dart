import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.message, this.icon = Icons.inbox_outlined});
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 36),
        child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 46, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ])),
      );
}
