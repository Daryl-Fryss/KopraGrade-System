import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../models/grading.dart';
import '../services/grading_service.dart';

class HistoryState {
  final List<Grading> items;
  final int total;
  final bool loading;
  final bool loadingMore;
  final String? error;
  final String? grade;
  final DateTimeRange? range;

  const HistoryState({
    this.items = const [],
    this.total = 0,
    this.loading = true,
    this.loadingMore = false,
    this.error,
    this.grade,
    this.range,
  });

  bool get hasMore => items.length < total;
  bool get hasFilters => grade != null || range != null;

  HistoryState copyWith({
    List<Grading>? items,
    int? total,
    bool? loading,
    bool? loadingMore,
    String? error,
    bool clearError = false,
    String? grade,
    bool clearGrade = false,
    DateTimeRange? range,
    bool clearRange = false,
  }) {
    return HistoryState(
      items: items ?? this.items,
      total: total ?? this.total,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      error: clearError ? null : (error ?? this.error),
      grade: clearGrade ? null : (grade ?? this.grade),
      range: clearRange ? null : (range ?? this.range),
    );
  }
}

class HistoryController extends StateNotifier<HistoryState> {
  HistoryController(this._service) : super(const HistoryState()) {
    refresh();
  }

  final GradingService _service;
  static const _pageSize = 20;

  Future<void> refresh() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final page = await _service.history(
        grade: state.grade,
        from: state.range?.start,
        to: state.range?.end,
        limit: _pageSize,
      );
      if (!mounted) return;
      state = state.copyWith(items: page.items, total: page.total, loading: false);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(loading: false, error: ApiException.from(e).message);
    }
  }

  Future<void> loadMore() async {
    if (state.loading || state.loadingMore || !state.hasMore) return;
    state = state.copyWith(loadingMore: true);
    try {
      final page = await _service.history(
        grade: state.grade,
        from: state.range?.start,
        to: state.range?.end,
        limit: _pageSize,
        offset: state.items.length,
      );
      if (!mounted) return;
      state = state.copyWith(items: [...state.items, ...page.items], total: page.total, loadingMore: false);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(loadingMore: false, error: ApiException.from(e).message);
    }
  }

  void setGrade(String? grade) {
    state = grade == null ? state.copyWith(clearGrade: true) : state.copyWith(grade: grade);
    refresh();
  }

  void setRange(DateTimeRange? range) {
    state = range == null ? state.copyWith(clearRange: true) : state.copyWith(range: range);
    refresh();
  }

  void clearFilters() {
    state = state.copyWith(clearGrade: true, clearRange: true);
    refresh();
  }
}
