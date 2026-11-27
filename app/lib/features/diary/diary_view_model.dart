import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/language.dart';
import '../../app/providers.dart';
import '../../core/utils/markdown.dart' as md;
import '../../domain/category.dart';
import '../../domain/entry.dart';
import '../../domain/metric.dart';
import '../../domain/photo.dart';
import '../../domain/repositories/diary_repository.dart';
import 'diary_state.dart';

final diaryViewModelProvider = NotifierProvider<DiaryViewModel, DiaryState>(DiaryViewModel.new);

/// โหลดจาก Supabase ครั้งเดียว แล้วแก้ทั้งในเครื่องและฐานข้อมูลพร้อมกัน
class DiaryViewModel extends Notifier<DiaryState> {
  DiaryRepository get _repo => ref.read(diaryRepositoryProvider);

  @override
  DiaryState build() {
    // เปลี่ยนผู้ใช้ → provider นี้ถูกสร้างใหม่ ข้อมูลคนก่อนไม่ค้าง
    final user = ref.watch(currentUserIdProvider);
    if (user == null) return const DiaryState();
    Future.microtask(load);
    return const DiaryState(loading: true);
  }

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      await _repo.ensureDefaults();
      final results = await Future.wait([_repo.categories(), _repo.metricDefs(), _repo.entries()]);
      state = state.copyWith(
        categories: results[0] as List<EntryCategory>,
        metricDefs: results[1] as List<MetricDef>,
        entries: results[2] as List<Entry>,
      );
    } catch (e) {
      state = state.copyWith(error: '$e');
    } finally {
      state = state.copyWith(loading: false);
    }
  }

  /// [removedPhotos] = รูปเดิมที่ผู้ใช้เอาออก (รูปใหม่อยู่ใน e.photos)
  Future<Entry> save(Entry e, {List<Photo> removedPhotos = const []}) async {
    final errors = state.validate(e, ref.read(stringsProvider));
    if (errors.isNotEmpty) throw ArgumentError(errors.join('\n'));
    final saved = e.id == null ? await _repo.insert(e) : await _repo.update(e, removedPhotos: removedPhotos);
    state = state.copyWith(
      entries: [for (final x in state.entries) if (x.id != saved.id) x, saved]..sort((a, b) => b.date.compareTo(a.date)),
    );
    return saved;
  }

  Future<void> delete(Entry e) async {
    await _repo.softDelete(e.id!);
    state = state.copyWith(entries: state.entries.where((x) => x.id != e.id).toList());
  }

  Future<void> undoDelete(Entry e) async {
    await _repo.restore(e.id!);
    await load();
  }

  Future<void> toggleCheck(Entry e, int index, bool done, {List<Photo> newPhotos = const []}) =>
      save(e.copyWith(body: md.toggleCheck(e.body, index, done), photos: [...e.photos, ...newPhotos]));

  Future<void> addCategory(EntryCategory c) async {
    await _repo.addCategory(c);
    state = state.copyWith(categories: [...state.categories, c]..sort((a, b) => a.sort.compareTo(b.sort)));
  }

  Future<void> addMetricDef(MetricDef m) async {
    await _repo.addMetricDef(m);
    state = state.copyWith(metricDefs: [...state.metricDefs, m]..sort((a, b) => a.key.compareTo(b.key)));
  }

  Future<int> importExport(Map<String, dynamic> data) async {
    final n = await _repo.importExport(data);
    await load();
    return n;
  }

  Future<void> logAi({
    required String provider,
    required String model,
    required String input,
    Object? output,
    required String status,
    String? error,
  }) =>
      _repo.logAi(provider: provider, model: model, input: input, output: output, status: status, error: error);
}
