import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/note.dart';
import '../providers/notes_provider.dart';
import 'note_card.dart';

/// Horizontal kanban board with one column per [PipelineStage].
/// Drag a card from one column and drop it on another to change its stage.
class PipelineBoard extends ConsumerWidget {
  final void Function(Note) onTogglePipeline;
  final void Function(BuildContext, Note) onOpen;

  const PipelineBoard({
    super.key,
    required this.onTogglePipeline,
    required this.onOpen,
  });

  Future<void> _moveTo(WidgetRef ref, Note note, PipelineStage stage) async {
    if (note.pipelineStage == stage) return;
    await ref.read(notesServiceProvider).setPipelineStage(note.id, stage);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesStreamProvider);
    final grouped = ref.watch(pipelineByStageProvider);

    return notesAsync.when(
      data: (_) => LayoutBuilder(
        builder: (context, constraints) {
          const stages = PipelineStage.values;
          const gap = 12.0;
          const horizontalPadding = 24.0; // 12 each side
          const minColumnWidth = 200.0;

          final available = constraints.maxWidth - horizontalPadding;
          final fitted =
              (available - gap * (stages.length - 1)) / stages.length;
          final fits = fitted >= minColumnWidth;
          final columnWidth = fits ? fitted : minColumnWidth;

          final row = IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < stages.length; i++) ...[
                  if (i > 0) const SizedBox(width: gap),
                  SizedBox(
                    width: columnWidth,
                    child: _StageColumn(
                      stage: stages[i],
                      notes: grouped[stages[i]] ?? const [],
                      onDropNote: (note) => _moveTo(ref, note, stages[i]),
                      onOpen: onOpen,
                      onTogglePipeline: onTogglePipeline,
                    ),
                  ),
                ],
              ],
            ),
          );

          return Padding(
            padding: const EdgeInsets.all(12),
            child: fits
                ? row
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal, child: row),
          );
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child:
              Text('Failed to load pipeline:\n$e', textAlign: TextAlign.center),
        ),
      ),
    );
  }
}

class _StageColumn extends StatelessWidget {
  final PipelineStage stage;
  final List<Note> notes;
  final Future<void> Function(Note) onDropNote;
  final void Function(BuildContext, Note) onOpen;
  final void Function(Note) onTogglePipeline;

  const _StageColumn({
    required this.stage,
    required this.notes,
    required this.onDropNote,
    required this.onOpen,
    required this.onTogglePipeline,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _stageColor(stage, scheme),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    stage.label,
                    style: Theme.of(context).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${notes.length}',
                  style: TextStyle(
                    color: Theme.of(context).hintColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: DragTarget<Note>(
              onWillAcceptWithDetails: (details) =>
                  details.data.pipelineStage != stage,
              onAcceptWithDetails: (details) => onDropNote(details.data),
              builder: (context, candidate, rejected) {
                final highlighted = candidate.isNotEmpty;
                return Container(
                  decoration: BoxDecoration(
                    color: highlighted
                        ? scheme.primary.withValues(alpha: 0.08)
                        : Colors.transparent,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: notes.isEmpty
                      ? _EmptyDropZone(highlighted: highlighted)
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                          itemCount: notes.length,
                          itemBuilder: (ctx, i) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _DraggableCard(
                              note: notes[i],
                              onOpen: () => onOpen(ctx, notes[i]),
                              onTogglePipeline: () =>
                                  onTogglePipeline(notes[i]),
                            ),
                          ),
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _stageColor(PipelineStage s, ColorScheme scheme) {
    switch (s) {
      case PipelineStage.ideas:
        return Colors.blueGrey;
      case PipelineStage.planning:
        return Colors.indigo;
      case PipelineStage.inProgress:
        return Colors.amber.shade700;
      case PipelineStage.finalStages:
        return Colors.deepOrange;
      case PipelineStage.complete:
        return Colors.green;
    }
  }
}

class _DraggableCard extends StatelessWidget {
  final Note note;
  final VoidCallback onOpen;
  final VoidCallback onTogglePipeline;

  const _DraggableCard({
    required this.note,
    required this.onOpen,
    required this.onTogglePipeline,
  });

  @override
  Widget build(BuildContext context) {
    final card = NoteCard(
      note: note,
      onTap: onOpen,
      onTogglePipeline: onTogglePipeline,
      showPipelineAudit: true,
    );
    return Draggable<Note>(
      data: note,
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(width: 260, child: card),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: card),
      child: card,
    );
  }
}

class _EmptyDropZone extends StatelessWidget {
  final bool highlighted;
  const _EmptyDropZone({required this.highlighted});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          highlighted ? 'Drop here' : 'Empty',
          style: TextStyle(
            color: Theme.of(context).hintColor,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }
}
