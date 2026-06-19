import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';

class LiveShareBoard {
  final String id;
  final String title;
  final String imageName;
  final String imageDataBase64;
  final String imageMimeType;
  final int imageWidth;
  final int imageHeight;
  final String createdByName;
  final String updatedByName;
  final DateTime? savedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const LiveShareBoard({
    required this.id,
    required this.title,
    required this.imageName,
    required this.imageDataBase64,
    required this.imageMimeType,
    required this.imageWidth,
    required this.imageHeight,
    required this.createdByName,
    required this.updatedByName,
    required this.savedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get hasImage => imageDataBase64.isNotEmpty;

  Uint8List? get imageBytes {
    if (imageDataBase64.isEmpty) return null;
    return base64Decode(imageDataBase64);
  }

  factory LiveShareBoard.empty(String id) => LiveShareBoard(
    id: id,
    title: 'Untitled live share',
    imageName: '',
    imageDataBase64: '',
    imageMimeType: 'image/jpeg',
    imageWidth: 0,
    imageHeight: 0,
    createdByName: 'Team member',
    updatedByName: 'Team member',
    savedAt: null,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  factory LiveShareBoard.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? const {};
    return LiveShareBoard(
      id: doc.id,
      title: data['title'] as String? ?? 'Untitled live share',
      imageName: data['imageName'] as String? ?? '',
      imageDataBase64: data['imageDataBase64'] as String? ?? '',
      imageMimeType: data['imageMimeType'] as String? ?? 'image/jpeg',
      imageWidth: data['imageWidth'] as int? ?? 0,
      imageHeight: data['imageHeight'] as int? ?? 0,
      createdByName: data['createdByName'] as String? ?? 'Team member',
      updatedByName: data['updatedByName'] as String? ?? 'Team member',
      savedAt: (data['savedAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class LiveShareStroke {
  final String id;
  final int colorValue;
  final double width;
  final List<Offset> points;
  final String createdByUid;
  final String createdByName;
  final DateTime createdAt;
  final DateTime updatedAt;

  const LiveShareStroke({
    required this.id,
    required this.colorValue,
    required this.width,
    required this.points,
    required this.createdByUid,
    required this.createdByName,
    required this.createdAt,
    required this.updatedAt,
  });

  Color get color => Color(colorValue);

  factory LiveShareStroke.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? const {};
    return LiveShareStroke(
      id: doc.id,
      colorValue: data['colorValue'] as int? ?? 0xFFFF0000,
      width: (data['width'] as num?)?.toDouble() ?? 5,
      points: ((data['points'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (point) => Offset(
              (point['x'] as num?)?.toDouble() ?? 0,
              (point['y'] as num?)?.toDouble() ?? 0,
            ),
          )
          .toList(),
      createdByUid: data['createdByUid'] as String? ?? '',
      createdByName: data['createdByName'] as String? ?? 'Team member',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'colorValue': colorValue,
    'width': width,
    'points': [
      for (final point in points) {'x': point.dx, 'y': point.dy},
    ],
    'createdByUid': createdByUid,
    'createdByName': createdByName,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };
}
