import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ReminderPicker extends StatelessWidget {
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  const ReminderPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final initial = value ?? now.add(const Duration(hours: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (date == null) return;
    if (!context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;
    onChanged(
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _pick(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.alarm),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value == null
                    ? 'No reminder'
                    : DateFormat.yMMMd().add_jm().format(value!),
              ),
            ),
            if (value != null)
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Clear reminder',
                onPressed: () => onChanged(null),
              ),
          ],
        ),
      ),
    );
  }
}
