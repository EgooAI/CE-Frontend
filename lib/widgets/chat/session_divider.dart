import 'package:flutter/material.dart';

class SessionDivider extends StatelessWidget {
  const SessionDivider({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final lineColor = const Color(0x669E9E9E);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 0.5,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, lineColor],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF9E9E9E),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 0.5,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [lineColor, Colors.transparent],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
