import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class MarkedUpImage {
  final Uint8List bytes;
  final String name;

  const MarkedUpImage({required this.bytes, required this.name});
}

class ImageMarkupScreen extends StatefulWidget {
  final Uint8List imageBytes;
  final String fileName;

  const ImageMarkupScreen({
    super.key,
    required this.imageBytes,
    required this.fileName,
  });

  @override
  State<ImageMarkupScreen> createState() => _ImageMarkupScreenState();
}

class _ImageMarkupScreenState extends State<ImageMarkupScreen> {
  final _captureKey = GlobalKey();
  final List<_MarkupStroke> _strokes = [];
  ui.Image? _image;
  Color _color = Colors.red;
  double _strokeWidth = 5;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _decodeImage();
  }

  Future<void> _decodeImage() async {
    final image = await decodeImageFromList(widget.imageBytes);
    if (!mounted) return;
    setState(() => _image = image);
  }

  void _startStroke(Offset point) {
    setState(() {
      _strokes.add(
        _MarkupStroke(color: _color, width: _strokeWidth, points: [point]),
      );
    });
  }

  void _appendPoint(Offset point) {
    if (_strokes.isEmpty) return;
    setState(() {
      _strokes.last.points.add(point);
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary =
          _captureKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) {
        throw StateError('Could not capture the marked-up image.');
      }
      final image = await boundary.toImage(pixelRatio: 2);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData?.buffer.asUint8List();
      if (bytes == null) {
        throw StateError('Could not export the marked-up image.');
      }
      if (!mounted) return;
      Navigator.of(context).pop(
        MarkedUpImage(bytes: bytes, name: _markedFileName(widget.fileName)),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Markup failed: $error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mark up image'),
        actions: [
          IconButton(
            tooltip: 'Undo',
            onPressed: _strokes.isEmpty || _saving
                ? null
                : () => setState(() => _strokes.removeLast()),
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            tooltip: 'Clear',
            onPressed: _strokes.isEmpty || _saving
                ? null
                : () => setState(_strokes.clear),
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
          IconButton(
            tooltip: 'Save markup',
            onPressed: image == null || _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
          ),
        ],
      ),
      body: image == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final size = _fitImage(
                        image.width.toDouble(),
                        image.height.toDouble(),
                        constraints.maxWidth - 24,
                        constraints.maxHeight - 24,
                      );
                      return Center(
                        child: RepaintBoundary(
                          key: _captureKey,
                          child: SizedBox(
                            width: size.width,
                            height: size.height,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.memory(
                                  widget.imageBytes,
                                  fit: BoxFit.fill,
                                ),
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onPanStart: (details) =>
                                      _startStroke(details.localPosition),
                                  onPanUpdate: (details) =>
                                      _appendPoint(details.localPosition),
                                  child: CustomPaint(
                                    painter: _MarkupPainter(_strokes),
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
                SafeArea(
                  top: false,
                  minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.brush_outlined),
                          const SizedBox(width: 12),
                          for (final color in _palette)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _ColorButton(
                                color: color,
                                selected: color == _color,
                                onPressed: () => setState(() => _color = color),
                              ),
                            ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Slider(
                              min: 2,
                              max: 14,
                              divisions: 6,
                              value: _strokeWidth,
                              label: _strokeWidth.round().toString(),
                              onChanged: (value) =>
                                  setState(() => _strokeWidth = value),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _MarkupStroke {
  final Color color;
  final double width;
  final List<Offset> points;

  _MarkupStroke({
    required this.color,
    required this.width,
    required this.points,
  });
}

class _MarkupPainter extends CustomPainter {
  final List<_MarkupStroke> strokes;

  const _MarkupPainter(this.strokes);

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
        canvas.drawCircle(stroke.points.first, stroke.width / 2, paint);
        continue;
      }
      final path = Path()
        ..moveTo(stroke.points.first.dx, stroke.points.first.dy);
      for (final point in stroke.points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MarkupPainter oldDelegate) => true;
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
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: const SizedBox(width: 22, height: 22),
            ),
          ),
        ),
      ),
    );
  }
}

const _palette = [
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
  final safeMaxWidth = maxWidth.clamp(120, double.infinity).toDouble();
  final safeMaxHeight = maxHeight.clamp(120, double.infinity).toDouble();
  final widthScale = safeMaxWidth / imageWidth;
  final heightScale = safeMaxHeight / imageHeight;
  final scale = widthScale < heightScale ? widthScale : heightScale;
  return Size(imageWidth * scale, imageHeight * scale);
}

String _markedFileName(String fileName) {
  final dot = fileName.lastIndexOf('.');
  final base = dot <= 0 ? fileName : fileName.substring(0, dot);
  final cleanBase = base.trim().isEmpty ? 'image' : base.trim();
  return '$cleanBase-marked.png';
}
