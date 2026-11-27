import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../app/language.dart';
import '../../app/providers.dart';
import '../../data/photo_picker.dart';
import '../../domain/photo.dart';
import '../photos/pick_photos.dart';

part 'photo_draft_view_model.freezed.dart';

@freezed
abstract class PhotoDraftState with _$PhotoDraftState {
  const factory PhotoDraftState({
    @Default(<Uint8List>[]) List<Uint8List> photos,
    @Default(false) bool picking, // กำลังเลือก/ถ่ายรูป
    String? notice, // ข้อความแจ้งครั้งเดียว (View ฟังผ่าน ref.listen)
  }) = _PhotoDraftState;
}

/// ไม่ใช่ autoDispose: รูปที่เลือกไว้ต้องอยู่แม้กล่องพิมพ์ถูกสร้างใหม่ระหว่างเปิดกล้อง
final photoDraftViewModelProvider =
    NotifierProvider<PhotoDraftViewModel, PhotoDraftState>(PhotoDraftViewModel.new);

/// รูปที่แนบรอส่งในกล่องพิมพ์หน้าแรก
class PhotoDraftViewModel extends Notifier<PhotoDraftState> {
  @override
  PhotoDraftState build() {
    // เปลี่ยนบัญชี → รูปที่ค้างของคนก่อนต้องหายไป
    ref.watch(currentUserIdProvider);
    return const PhotoDraftState();
  }

  Future<void> add(PhotoSource source) async {
    if (state.picking) return;
    final user = ref.read(currentUserIdProvider);
    state = state.copyWith(picking: true, notice: null);
    final picked = await pickPhotos(ref.read(photoPickerProvider), source,
        room: maxPhotosPerMessage - state.photos.length, strings: ref.read(stringsProvider));
    if (user != ref.read(currentUserIdProvider)) return;
    _append(picked);
  }

  /// เก็บรูปที่ถ่ายไว้ก่อน Android ปิดแอประหว่างเปิดกล้อง
  Future<void> restoreLost() async {
    final user = ref.read(currentUserIdProvider);
    final List<Uint8List> lost;
    try {
      lost = await ref.read(photoPickerProvider).recoverLost();
    } catch (_) {
      return; // กู้ไม่ได้ก็ให้ผู้ใช้ถ่ายใหม่
    }
    if (lost.isEmpty || user != ref.read(currentUserIdProvider)) return;
    _append(preparePhotos(lost, room: maxPhotosPerMessage - state.photos.length, strings: ref.read(stringsProvider)));
  }

  void _append(PickedPhotos picked) =>
      state = PhotoDraftState(photos: [...state.photos, ...picked.photos], notice: picked.notice);

  void remove(int index) => state = state.copyWith(photos: [...state.photos]..removeAt(index), notice: null);

  /// เอารูปทั้งหมดไปส่ง
  List<Uint8List> take() {
    final photos = state.photos;
    state = state.copyWith(photos: const [], notice: null);
    return photos;
  }
}
