import 'dart:async';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/live_share.dart';
import '../providers/live_share_provider.dart';
import '../providers/team_provider.dart';
import '../services/pasteboard_service.dart';

class LiveShareScreen extends ConsumerStatefulWidget {
  const LiveShareScreen({super.key});

  @override
  ConsumerState<LiveShareScreen> createState() => _LiveShareScreenState();
}

class _LiveShareScreenState extends ConsumerState<LiveShareScreen> {
  final _canvasKey = GlobalKey();
  final _focusNode = FocusNode();
  final _pasteboard = PasteboardService();
  LiveShareStroke? _draftStroke;
  Color _drawColor = Colors.red;
  double _strokeWidth = 5;
  bool _busy = false;
  int _lastSyncedPointCount = 0;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _createBoard() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final id = await ref.read(liveShareServiceProvider).createBoard();
      ref.read(selectedLiveShareIdProvider.notifier).state = id;
      _focusNode.requestFocus();
    } catch (error) {
      _showError('Could not start live share: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String> _ensureBoard() async {
    final selectedId = ref.read(selectedLiveShareIdProvider);
    if (selectedId != null) return selectedId;
    final id = await ref.read(liveShareServiceProvider).createBoard();
    ref.read(selectedLiveShareIdProvider.notifier).state = id;
    return id;
  }

  Future<void> _pickImage() async {
    if (_busy) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      _showError('Could not read that image.');
      return;
    }
    await _setImage(file.name, bytes);
  }

  Future<void> _pasteImage() async {
    if (_busy) return;
    try {
      final bytes = await _pasteboard.readImage();
      if (bytes == null || bytes.isEmpty) {
        _showError('No image was found on the clipboard.');
        return;
      }
      await _setImage('pasted-live-share.jpg', bytes);
    } on PlatformException catch (error) {
      _showError('Paste failed: ${error.message ?? error.code}');
    } catch (error) {
      _showError('Paste failed: $error');
    }
  }

  Future<void> _setImage(String fileName, Uint8List bytes) async {
    setState(() => _busy = true);
    try {
      final boardId = await _ensureBoard();
      await ref.read(liveShareServiceProvider).updateBoardImage(
            boardId: boardId,
            fileName: fileName,
            bytes: bytes,
          );
      await ref.read(liveShareServiceProvider).clearStrokes(boardId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image shared with the team.')),
        );
      }
    } catch (error) {
      _showError('$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveBoard(String boardId) async {
    setState(() => _busy = true);
    try {
      await ref.read(liveShareServiceProvider).saveBoard(boardId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Live Share saved.')),
        );
      }
    } catch (error) {
      _showError('Save failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pushToPipeline(LiveShareBoard board) async {
    if (!board.hasImage || _busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await _captureCanvas();
      await ref.read(liveShareServiceProvider).pushToPipeline(
            board: board,
            renderedBytes: bytes,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pushed to Pipeline as a note.')),
        );
      }
    } catch (error) {
      _showError('Could not push to Pipeline: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<Uint8List> _captureCanvas() async {
    await WidgetsBinding.instance.endOfFrame;
    final boundary =
        _canvasKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      throw StateError('Could not capture the Live Share canvas.');
    }
    final image = await boundary.toImage(pixelRatio: 2);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData?.buffer.asUint8List();
    if (bytes == null) {
      throw StateError('Could not export the Live Share canvas.');
    }
    return bytes;
  }

  Future<void> _undo(String boardId, List<LiveShareStroke> strokes) async {
    final uid = ref.read(currentMemberProvider).valueOrNull?.uid;
    if (uid == null || strokes.isEmpty) return;
    LiveShareStroke? target;
    for (final stroke in strokes.reversed) {
      if (stroke.createdByUid == uid) {
        target = stroke;
        break;
      }
    }
    if (target == null) return;
    await ref.read(liveShareServiceProvider).deleteStroke(boardId, target.id);
  }

  Future<void> _clear(String boardId) async {
    await ref.read(liveShareServiceProvider).clearStrokes(boardId);
  }

  void _startStroke(String boardId, Size size, Offset localPosition) {
    if (size.width <= 0 || size.height <= 0) return;
    final member = ref.read(currentMemberProvider).valueOrNull;
    final service = ref.read(liveShareServiceProvider);
    final now = DateTime.now();
    final point = _normalize(localPosition, size);
    final stroke = LiveShareStroke(
      id: service.newStrokeId(boardId),
      colorValue: _colorToArgb32(_drawColor),
      width: _strokeWidth,
      points: [point],
      createdByUid: member?.uid ?? '',
      createdByName: member?.label ?? 'Team member',
      createdAt: now,
      updatedAt: now,
    );
    setState(() {
      _draftStroke = stroke;
      _lastSyncedPointCount = 1;
    });
    unawaited(service.upsertStroke(boardId, stroke));
  }

  void _appendStroke(String boardId, Size size, Offset localPosition) {
    final draft = _draftStroke;
    if (draft == null || size.width <= 0 || size.height <= 0) return;
    final updated = LiveShareStroke(
      id: draft.id,
      colorValue: draft.colorValue,
      width: draft.width,
      points: [...draft.points, _normalize(localPosition, size)],
      createdByUid: draft.createdByUid,
      createdByName: draft.createdByName,
      createdAt: draft.createdAt,
      updatedAt: DateTime.now(),
    );
    setState(() => _draftStroke = updated);
    if (updated.points.length - _lastSyncedPointCount >= 4) {
      _lastSyncedPointCount = updated.points.length;
      unawaited(
          ref.read(liveShareServiceProvider).upsertStroke(boardId, updated));
    }
  }

  void _endStroke(String boardId) {
    final draft = _draftStroke;
    if (draft == null) return;
    unawaited(ref.read(liveShareServiceProvider).upsertStroke(boardId, draft));
    setState(() {
      _draftStroke = null;
      _lastSyncedPointCount = 0;
    });
  }

  Offset _normalize(Offset point, Size size) => Offset(
        (point.dx / size.width).clamp(0, 1).toDouble(),
        (point.dy / size.height).clamp(0, 1).toDouble(),
      );

  int _colorToArgb32(Color color) =>
      (color.a * 255).round() << 24 |
      (color.r * 255).round() << 16 |
      (color.g * 255).round() << 8 |
      (color.b * 255).round();

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final boardsAsync = ref.watch(liveShareBoardsProvider);
    final selectedId = ref.watch(selectedLiveShareIdProvider);
    final selectedBoardAsync = ref.watch(selectedLiveShareProvider);

    boardsAsync.whenData((boards) {
      if (selectedId == null && boards.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ref.read(selectedLiveShareIdProvider.notifier).state =
              boards.first.id;
        });
      }
    });

    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.keyV, meta: true):
            _PasteImageIntent(),
        SingleActivator(LogicalKeyboardKey.keyV, control: true):
            _PasteImageIntent(),
      },
      child: Actions(
        actions: {
          _PasteImageIntent: CallbackAction<_PasteImageIntent>(
            onInvoke: (_) {
              _pasteImage();
              return null;
            },
          ),
        },
        child: Focus(
          focusNode: _focusNode,
          autofocus: true,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 720;
              final workspace = _buildWorkspace(
                selectedBoardAsync,
                compact: compact,
              );

              if (compact) {
                return Column(
                  children: [
                    _LiveShareCompactSessionBar(
                      boardsAsync: boardsAsync,
                      selectedId: selectedId,
                      busy: _busy,
                      onSelect: (id) {
                        ref.read(selectedLiveShareIdProvider.notifier).state =
                            id;
                        _focusNode.requestFocus();
                      },
                      onNew: _createBoard,
                    ),
                    const Divider(height: 1),
                    Expanded(child: workspace),
                  ],
                );
              }

              return Row(
                children: [
                  SizedBox(
                    width: 292,
                    child: _LiveShareSessionList(
                      boardsAsync: boardsAsync,
                      selectedId: selectedId,
                      busy: _busy,
                      onSelect: (id) {
                        ref.read(selectedLiveShareIdProvider.notifier).state =
                            id;
                        _focusNode.requestFocus();
                      },
                      onNew: _createBoard,
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: workspace),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildWorkspace(
    AsyncValue<LiveShareBoard?> selectedBoardAsync, {
    required bool compact,
  }) {
    return selectedBoardAsync.when(
      data: (board) {
        if (board == null) {
          return _NoLiveShareSelected(
            busy: _busy,
            onNew: _createBoard,
          );
        }
        return _LiveShareWorkspace(
          board: board,
          busy: _busy,
          compact: compact,
          drawColor: _drawColor,
          strokeWidth: _strokeWidth,
          canvasKey: _canvasKey,
          draftStroke: _draftStroke,
          onColorChanged: (color) => setState(() => _drawColor = color),
          onStrokeWidthChanged: (value) => setState(() => _strokeWidth = value),
          onPickImage: _pickImage,
          onPasteImage: _pasteImage,
          onSave: () => _saveBoard(board.id),
          onPushToPipeline: () => _pushToPipeline(board),
          onRename: (title) => ref
              .read(liveShareServiceProvider)
              .updateBoardTitle(board.id, title),
          onUndo: (strokes) => _undo(board.id, strokes),
          onClear: () => _clear(board.id),
          onStartStroke: (size, point) => _startStroke(board.id, size, point),
          onAppendStroke: (size, point) => _appendStroke(board.id, size, point),
          onEndStroke: () => _endStroke(board.id),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text('Could not load Live Share:\n$error'),
      ),
    );
  }
}

class _LiveShareCompactSessionBar extends StatelessWidget {
  final AsyncValue<List<LiveShareBoard>> boardsAsync;
  final String? selectedId;
  final bool busy;
  final ValueChanged<String> onSelect;
  final VoidCallback onNew;

  const _LiveShareCompactSessionBar({
    required this.boardsAsync,
    required this.selectedId,
    required this.busy,
    required this.onSelect,
    required this.onNew,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      bottom: false,
      minimum: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: boardsAsync.when(
              data: (boards) {
                final selected = boards.any((board) => board.id == selectedId)
                    ? selectedId
                    : null;
                if (boards.isEmpty) {
                  return const InputDecorator(
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: 'Live Share',
                    ),
                    child: Text('No saved boards'),
                  );
                }
                return DropdownButtonFormField<String>(
                  initialValue: selected,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Live Share',
                  ),
                  items: [
                    for (final board in boards)
                      DropdownMenuItem(
                        value: board.id,
                        child: Text(
                          board.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: busy
                      ? null
                      : (id) {
                          if (id != null) onSelect(id);
                        },
                );
              },
              loading: () => const LinearProgressIndicator(minHeight: 4),
              error: (error, _) => InputDecorator(
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Live Share',
                ),
                child: Text(
                  'Could not load boards',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            tooltip: 'New Live Share',
            onPressed: busy ? null : onNew,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

class _LiveShareSessionList extends StatelessWidget {
  final AsyncValue<List<LiveShareBoard>> boardsAsync;
  final String? selectedId;
  final bool busy;
  final ValueChanged<String> onSelect;
  final VoidCallback onNew;

  const _LiveShareSessionList({
    required this.boardsAsync,
    required this.selectedId,
    required this.busy,
    required this.onSelect,
    required this.onNew,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('New Live Share'),
              onPressed: busy ? null : onNew,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: boardsAsync.when(
              data: (boards) => boards.isEmpty
                  ? const Center(child: Text('No saved Live Shares'))
                  : ListView.builder(
                      itemCount: boards.length,
                      itemBuilder: (context, index) {
                        final board = boards[index];
                        return ListTile(
                          selected: board.id == selectedId,
                          leading: Icon(
                            board.hasImage
                                ? Icons.co_present_outlined
                                : Icons.add_photo_alternate_outlined,
                          ),
                          title: Text(
                            board.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            board.savedAt == null
                                ? 'Autosaved edits'
                                : 'Saved ${TimeOfDay.fromDateTime(board.savedAt!).format(context)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => onSelect(board.id),
                        );
                      },
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Could not load saved edits:\n$error'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveShareWorkspace extends ConsumerWidget {
  final LiveShareBoard board;
  final bool busy;
  final bool compact;
  final Color drawColor;
  final double strokeWidth;
  final GlobalKey canvasKey;
  final LiveShareStroke? draftStroke;
  final ValueChanged<Color> onColorChanged;
  final ValueChanged<double> onStrokeWidthChanged;
  final VoidCallback onPickImage;
  final VoidCallback onPasteImage;
  final VoidCallback onSave;
  final VoidCallback onPushToPipeline;
  final ValueChanged<String> onRename;
  final ValueChanged<List<LiveShareStroke>> onUndo;
  final VoidCallback onClear;
  final void Function(Size size, Offset point) onStartStroke;
  final void Function(Size size, Offset point) onAppendStroke;
  final VoidCallback onEndStroke;

  const _LiveShareWorkspace({
    required this.board,
    required this.busy,
    required this.compact,
    required this.drawColor,
    required this.strokeWidth,
    required this.canvasKey,
    required this.draftStroke,
    required this.onColorChanged,
    required this.onStrokeWidthChanged,
    required this.onPickImage,
    required this.onPasteImage,
    required this.onSave,
    required this.onPushToPipeline,
    required this.onRename,
    required this.onUndo,
    required this.onClear,
    required this.onStartStroke,
    required this.onAppendStroke,
    required this.onEndStroke,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strokesAsync = ref.watch(liveShareStrokesProvider(board.id));
    final imageBytes = board.imageBytes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, compact ? 8 : 10, 16, 8),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      key: ValueKey(board.id),
                      initialValue: board.title,
                      decoration: const InputDecoration(
                        isDense: true,
                        labelText: 'Live Share name',
                      ),
                      onChanged: onRename,
                      onFieldSubmitted: onRename,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        IconButton.filledTonal(
                          tooltip: 'Paste image',
                          onPressed: busy ? null : onPasteImage,
                          icon: const Icon(Icons.content_paste_go_outlined),
                        ),
                        IconButton.outlined(
                          tooltip: 'Choose image',
                          onPressed: busy ? null : onPickImage,
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                        ),
                        IconButton.outlined(
                          tooltip: 'Save edits',
                          onPressed: busy ? null : onSave,
                          icon: const Icon(Icons.save_outlined),
                        ),
                        IconButton.filledTonal(
                          tooltip: 'Push to Pipeline',
                          onPressed:
                              board.hasImage && !busy ? onPushToPipeline : null,
                          icon: const Icon(Icons.account_tree_outlined),
                        ),
                      ],
                    ),
                  ],
                )
              : Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 280,
                      child: TextFormField(
                        key: ValueKey(board.id),
                        initialValue: board.title,
                        decoration: const InputDecoration(
                          isDense: true,
                          labelText: 'Live Share name',
                        ),
                        onChanged: onRename,
                        onFieldSubmitted: onRename,
                      ),
                    ),
                    FilledButton.icon(
                      icon: const Icon(Icons.content_paste_go_outlined),
                      label: const Text('Paste image'),
                      onPressed: busy ? null : onPasteImage,
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: const Text('Choose image'),
                      onPressed: busy ? null : onPickImage,
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Save edits'),
                      onPressed: busy ? null : onSave,
                    ),
                    FilledButton.icon(
                      icon: const Icon(Icons.account_tree_outlined),
                      label: const Text('Push to Pipeline'),
                      onPressed:
                          board.hasImage && !busy ? onPushToPipeline : null,
                    ),
                  ],
                ),
        ),
        const Divider(height: 1),
        Expanded(
          child: strokesAsync.when(
            data: (strokes) => Column(
              children: [
                if (compact)
                  _LiveShareToolbar(
                    strokes: strokes,
                    color: drawColor,
                    strokeWidth: strokeWidth,
                    compact: true,
                    onColorChanged: onColorChanged,
                    onStrokeWidthChanged: onStrokeWidthChanged,
                    onUndo: () => onUndo(strokes),
                    onClear: onClear,
                  ),
                Expanded(
                  child: imageBytes == null
                      ? _LiveShareDropZone(
                          busy: busy,
                          showActions: !compact,
                          onPasteImage: onPasteImage,
                          onPickImage: onPickImage,
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final imageSize = _fitImage(
                              board.imageWidth.toDouble(),
                              board.imageHeight.toDouble(),
                              constraints.maxWidth - 24,
                              constraints.maxHeight - 24,
                            );
                            final visibleStrokes = draftStroke == null
                                ? strokes
                                : strokes
                                    .where((stroke) =>
                                        stroke.id != draftStroke!.id)
                                    .toList();
                            return Center(
                              child: RepaintBoundary(
                                key: canvasKey,
                                child: SizedBox(
                                  width: imageSize.width,
                                  height: imageSize.height,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.memory(imageBytes,
                                          fit: BoxFit.fill),
                                      GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onPanStart: (details) => onStartStroke(
                                          imageSize,
                                          details.localPosition,
                                        ),
                                        onPanUpdate: (details) =>
                                            onAppendStroke(
                                          imageSize,
                                          details.localPosition,
                                        ),
                                        onPanEnd: (_) => onEndStroke(),
                                        onPanCancel: onEndStroke,
                                        child: CustomPaint(
                                          painter: _LiveSharePainter([
                                            ...visibleStrokes,
                                            if (draftStroke != null)
                                              draftStroke!,
                                          ]),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                if (!compact)
                  _LiveShareToolbar(
                    strokes: strokes,
                    color: drawColor,
                    strokeWidth: strokeWidth,
                    compact: false,
                    onColorChanged: onColorChanged,
                    onStrokeWidthChanged: onStrokeWidthChanged,
                    onUndo: () => onUndo(strokes),
                    onClear: onClear,
                  ),
              ],
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Text('Could not load realtime edits:\n$error'),
            ),
          ),
        ),
      ],
    );
  }
}

class _LiveShareDropZone extends StatelessWidget {
  final bool busy;
  final bool showActions;
  final VoidCallback onPasteImage;
  final VoidCallback onPickImage;

  const _LiveShareDropZone({
    required this.busy,
    this.showActions = true,
    required this.onPasteImage,
    required this.onPickImage,
  });

  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.co_present_outlined, size: 72, color: hint),
            const SizedBox(height: 16),
            Text(
              'Paste an image to start',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Everyone in CardTrove can draw on the same shared image as edits stream in.',
              style: TextStyle(color: hint),
              textAlign: TextAlign.center,
            ),
            if (showActions) ...[
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.icon(
                    icon: const Icon(Icons.content_paste_go_outlined),
                    label: const Text('Paste image'),
                    onPressed: busy ? null : onPasteImage,
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: const Text('Choose image'),
                    onPressed: busy ? null : onPickImage,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LiveShareToolbar extends StatelessWidget {
  final List<LiveShareStroke> strokes;
  final Color color;
  final double strokeWidth;
  final bool compact;
  final ValueChanged<Color> onColorChanged;
  final ValueChanged<double> onStrokeWidthChanged;
  final VoidCallback onUndo;
  final VoidCallback onClear;

  const _LiveShareToolbar({
    required this.strokes,
    required this.color,
    required this.strokeWidth,
    required this.compact,
    required this.onColorChanged,
    required this.onStrokeWidthChanged,
    required this.onUndo,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final controls = [
      const Icon(Icons.brush_outlined),
      const SizedBox(width: 10),
      for (final swatch in _swatches)
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: _ColorButton(
            color: swatch,
            selected: swatch == color,
            onPressed: () => onColorChanged(swatch),
          ),
        ),
      const SizedBox(width: 8),
      SizedBox(
        width: compact ? 132 : 180,
        child: Slider(
          min: 2,
          max: 18,
          divisions: 8,
          value: strokeWidth,
          label: strokeWidth.round().toString(),
          onChanged: onStrokeWidthChanged,
        ),
      ),
      IconButton(
        tooltip: 'Undo my last stroke',
        onPressed: strokes.isEmpty ? null : onUndo,
        icon: const Icon(Icons.undo),
      ),
      IconButton(
        tooltip: 'Clear canvas',
        onPressed: strokes.isEmpty ? null : onClear,
        icon: const Icon(Icons.delete_sweep_outlined),
      ),
    ];

    if (compact) {
      return SafeArea(
        top: false,
        bottom: false,
        minimum: const EdgeInsets.fromLTRB(12, 6, 12, 4),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: controls,
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          ...controls.take(controls.length - 2),
          const Spacer(),
          ...controls.skip(controls.length - 2),
        ],
      ),
    );
  }
}

class _LiveSharePainter extends CustomPainter {
  final List<LiveShareStroke> strokes;

  const _LiveSharePainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;
      final paint = Paint()
        ..color = stroke.color
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = stroke.width
        ..style = PaintingStyle.stroke;
      if (stroke.points.length == 1) {
        canvas.drawCircle(
            _denormalize(stroke.points.first, size), stroke.width / 2, paint);
        continue;
      }
      final path = Path()
        ..moveTo(
          stroke.points.first.dx * size.width,
          stroke.points.first.dy * size.height,
        );
      for (final point in stroke.points.skip(1)) {
        path.lineTo(point.dx * size.width, point.dy * size.height);
      }
      canvas.drawPath(path, paint);
    }
  }

  Offset _denormalize(Offset point, Size size) =>
      Offset(point.dx * size.width, point.dy * size.height);

  @override
  bool shouldRepaint(covariant _LiveSharePainter oldDelegate) => true;
}

class _ColorButton extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onPressed;

  const _ColorButton({
    required this.color,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Draw color',
      child: InkResponse(
        onTap: onPressed,
        radius: 20,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).dividerColor,
              width: selected ? 3 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: const SizedBox(width: 22, height: 22),
            ),
          ),
        ),
      ),
    );
  }
}

class _NoLiveShareSelected extends StatelessWidget {
  final bool busy;
  final VoidCallback onNew;

  const _NoLiveShareSelected({
    required this.busy,
    required this.onNew,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FilledButton.icon(
        icon: const Icon(Icons.add),
        label: const Text('Start Live Share'),
        onPressed: busy ? null : onNew,
      ),
    );
  }
}

class _PasteImageIntent extends Intent {
  const _PasteImageIntent();
}

const _swatches = [
  Colors.red,
  Colors.amber,
  Colors.green,
  Colors.blue,
  Colors.black,
  Colors.white,
];

Size _fitImage(
  double imageWidth,
  double imageHeight,
  double maxWidth,
  double maxHeight,
) {
  if (imageWidth <= 0 || imageHeight <= 0) {
    return const Size(640, 420);
  }
  final safeMaxWidth = maxWidth.clamp(160, double.infinity).toDouble();
  final safeMaxHeight = maxHeight.clamp(160, double.infinity).toDouble();
  final widthScale = safeMaxWidth / imageWidth;
  final heightScale = safeMaxHeight / imageHeight;
  final scale = widthScale < heightScale ? widthScale : heightScale;
  return Size(imageWidth * scale, imageHeight * scale);
}
