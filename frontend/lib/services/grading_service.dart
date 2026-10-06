import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../core/api_client.dart';
import '../models/grading.dart';

class GradingService {
  GradingService(this._api);
  final ApiClient _api;

  /// POST /api/classification/predict  (multipart, field "image")
  /// [kind] is 'jpg' or 'png' (found from the file's first bytes, see detectImageKind).
  Future<Grading> upload(Uint8List bytes, String kind) async {
    final isPng = kind == 'png';
    final form = FormData.fromMap({
      'image': MultipartFile.fromBytes(
        bytes,
        filename: isPng ? 'copra.png' : 'copra.jpg',
        contentType: DioMediaType.parse(isPng ? 'image/png' : 'image/jpeg'),
      ),
    });
    try {
      final res = await _api.dio.post('/classification/predict', data: form);
      return Grading.fromJson((res.data as Map<String, dynamic>)['grading'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.from(e);
    }
  }

  /// GET /api/gradings/:id
  Future<Grading> getById(int id) async {
    try {
      final res = await _api.dio.get('/gradings/$id');
      return Grading.fromJson((res.data as Map<String, dynamic>)['grading'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.from(e);
    }
  }

  /// GET /api/history?grade=&from=&to=&limit=&offset=
  Future<HistoryPage> history({String? grade, DateTime? from, DateTime? to, int limit = 20, int offset = 0}) async {
    final day = DateFormat('yyyy-MM-dd');
    try {
      final res = await _api.dio.get('/history', queryParameters: {
        if (grade != null) 'grade': grade,
        if (from != null) 'from': day.format(from),
        if (to != null) 'to': day.format(to),
        'limit': limit,
        'offset': offset,
      });
      final data = res.data as Map<String, dynamic>;
      final items = (data['items'] as List)
          .map((e) => Grading.fromJson(e as Map<String, dynamic>))
          .toList();
      return HistoryPage(data['total'] as int, items);
    } on DioException catch (e) {
      throw ApiException.from(e);
    }
  }
}
