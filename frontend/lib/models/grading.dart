import '../core/config.dart';

class Grading {
  final int id;
  final String sampleCode;
  final String imageUrl; // full address, ready for Image.network
  final String grade;
  final String? gradeDescription;
  final double confidence; // 0 - 100
  final bool needsReview;
  final DateTime classifiedAt;
  final String? recommendation;
  final String farmerName;

  const Grading({
    required this.id,
    required this.sampleCode,
    required this.imageUrl,
    required this.grade,
    required this.gradeDescription,
    required this.confidence,
    required this.needsReview,
    required this.classifiedAt,
    required this.recommendation,
    required this.farmerName,
  });

  factory Grading.fromJson(Map<String, dynamic> j) => Grading(
        id: j['id'] as int,
        sampleCode: j['sample_code'] as String,
        imageUrl: '${AppConfig.baseUrl}${j['image_url']}',
        grade: j['grade'] as String,
        gradeDescription: j['grade_description'] as String?,
        confidence: (j['confidence_score'] as num).toDouble(),
        needsReview: j['needs_review'] as bool,
        classifiedAt: DateTime.parse(j['classified_at'] as String).toLocal(),
        recommendation: j['recommendation'] as String?,
        farmerName: (j['farmer'] as Map<String, dynamic>)['name'] as String,
      );
}

class HistoryPage {
  final int total;
  final List<Grading> items;
  const HistoryPage(this.total, this.items);
}
