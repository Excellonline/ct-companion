import 'package:flutter/material.dart';

import '../models/note.dart';

class ChecklistItemTile extends StatefulWidget {
  final ChecklistItem item;
  final ValueChanged<ChecklistItem> onChanged;
  final VoidCallback onDelete;
  final VoidCallback? onSubmitted;
  final bool autoFocus;

  const ChecklistItemTile({
    super.key,
    required this.item,
    required this.onChanged,
    required this.onDelete,
    this.onSubmitted,
    this.autoFocus = false,
  });

  @override
  State<ChecklistItemTile> createState() => _ChecklistItemTileState();
}

class _ChecklistItemTileState extends State<ChecklistItemTile> {
  late TextEditingController _ctl;
  late FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _ctl = TextEditingController(text: widget.item.text);
    _focus = FocusNode();
    if (widget.autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(ChecklistItemTile old) {
    super.didUpdateWidget(old);
    if (widget.item.text != _ctl.text && !_focus.hasFocus) {
      _ctl.text = widget.item.text;
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Checkbox(
          value: widget.item.done,
          onChanged: (v) =>
              widget.onChanged(widget.item.copyWith(done: v ?? false)),
        ),
        Expanded(
          child: TextField(
            controller: _ctl,
            focusNode: _focus,
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              hintText: 'Item',
            ),
            style: TextStyle(
              decoration: widget.item.done ? TextDecoration.lineThrough : null,
              color: widget.item.done ? Theme.of(context).hintColor : null,
            ),
            textInputAction: TextInputAction.next,
            onChanged: (t) => widget.onChanged(widget.item.copyWith(text: t)),
            onSubmitted: (_) => widget.onSubmitted?.call(),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, size: 18),
          onPressed: widget.onDelete,
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}
