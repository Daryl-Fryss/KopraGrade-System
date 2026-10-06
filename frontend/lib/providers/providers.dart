import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../models/grading.dart';
import '../services/auth_service.dart';
import '../services/grading_service.dart';
import 'auth_controller.dart';
import 'history_controller.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final authServiceProvider = Provider<AuthService>((ref) => AuthService(ref.watch(apiClientProvider)));

final gradingServiceProvider =
    Provider<GradingService>((ref) => GradingService(ref.watch(apiClientProvider)));

final authProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) => AuthController(ref.watch(apiClientProvider), ref.watch(authServiceProvider)),
);

/// One grading by id (used by the result screen).
final gradingProvider = FutureProvider.autoDispose.family<Grading, int>(
  (ref, id) => ref.watch(gradingServiceProvider).getById(id),
);

/// History list + filters. autoDispose: it reloads each time the History tab is opened.
final historyProvider = StateNotifierProvider.autoDispose<HistoryController, HistoryState>(
  (ref) => HistoryController(ref.watch(gradingServiceProvider)),
);
