import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;

  const MessageBubble({Key? key, required this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final type = message['type']?.toString() ?? 'chat';
    final isEvent = type == 'event';
    final mine = (message['is_mine'] as bool?) ?? false;
    final body = message['body']?.toString() ?? '';
    final when = message['created_at']?.toString();
    final time = when != null ? _fmtTime(when) : '';

    if (isEvent) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.blueGrey.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.blueGrey.shade100),
          ),
          child: Text(
            body,
            style: TextStyle(
              fontSize: 12,
              color: Colors.blueGrey.shade700,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: mine ? AppColors.primary : Colors.white,
          border: mine ? null : Border.all(color: Colors.black12),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(mine ? 14 : 2),
            bottomRight: Radius.circular(mine ? 2 : 14),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              body,
              style: TextStyle(color: mine ? Colors.white : Colors.black87),
            ),
            const SizedBox(height: 2),
            Text(
              time,
              style: TextStyle(
                fontSize: 9,
                color: mine ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtTime(String iso) {
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
