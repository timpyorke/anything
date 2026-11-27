import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/language.dart';
import '../../app/providers.dart';
import '../../domain/photo.dart';

/// ไฟล์ของรูปที่เก็บแล้ว ดาวน์โหลดครั้งเดียวต่อการเปิดแอป
final photoBytesProvider = FutureProvider.autoDispose.family((ref, String path) async {
  ref.watch(currentUserIdProvider); // เปลี่ยนบัญชีแล้วห้ามใช้ของที่ค้างอยู่
  final bytes = await ref.watch(diaryRepositoryProvider).photoBytes(path);
  ref.keepAlive();
  return bytes;
}, retry: (_, _) => null);

/// รูป 1 รูป ทั้งที่ยังไม่บันทึกและที่ต้องดาวน์โหลด (โหลดไม่ได้ → แตะเพื่อลองใหม่)
class PhotoImage extends ConsumerWidget {
  const PhotoImage(this.photo, {super.key, this.fit = BoxFit.cover, this.cacheWidth});
  final Photo photo;
  final BoxFit fit;

  /// ความกว้างที่ถอดรหัส (พิกเซลจริง) — รูปย่อไม่ต้องเปลืองหน่วยความจำเท่ารูปเต็ม
  final int? cacheWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    final broken = Center(child: Icon(Icons.broken_image_outlined, color: color));
    Widget image(bytes) => Image.memory(
          bytes,
          fit: fit,
          cacheWidth: cacheWidth,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => broken,
        );
    if (photo.bytes != null) return image(photo.bytes);
    final path = photo.path!;
    return ref.watch(photoBytesProvider(path)).when(
          data: image,
          loading: () => const Center(child: SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))),
          error: (_, _) => IconButton(
            tooltip: t.photoLoadFailed,
            icon: Icon(Icons.refresh, color: color),
            onPressed: () => ref.invalidate(photoBytesProvider(path)),
          ),
        );
  }
}

/// แถวรูปย่อ แตะเพื่อดูเต็มจอ
class PhotoStrip extends ConsumerWidget {
  const PhotoStrip(this.photos, {super.key, this.size = 64, this.max, this.onRemove});
  final List<Photo> photos;
  final double size;

  /// แสดงไม่เกินกี่รูป ที่เหลือนับเป็น "+n" บนรูปสุดท้าย (null = ทั้งหมด)
  final int? max;

  /// มีปุ่มเอาออกบนรูปเมื่อกำหนด
  final ValueChanged<int>? onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final shown = max == null || photos.length <= max! ? photos.length : max!;
    final hidden = photos.length - shown;
    final scheme = Theme.of(context).colorScheme;
    final pixels = (size * MediaQuery.devicePixelRatioOf(context) * 1.5).round();
    return Wrap(spacing: 6, runSpacing: 6, children: [
      for (var i = 0; i < shown; i++)
        SizedBox.square(
          dimension: size,
          child: Stack(fit: StackFit.expand, children: [
            Semantics(
              label: t.photoPosition(i + 1, photos.length),
              button: true,
              child: GestureDetector(
                onTap: () => openPhotoViewer(context, photos, i),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: ColoredBox(
                    color: scheme.surfaceContainerHighest,
                    child: PhotoImage(photos[i], cacheWidth: pixels),
                  ),
                ),
              ),
            ),
            if (hidden > 0 && i == shown - 1)
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
                  child: Center(
                    child: Text('+$hidden', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            if (onRemove != null)
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  tooltip: t.removePhoto,
                  onPressed: () => onRemove!(i),
                  // พื้นที่แตะกว้างกว่าวงกลมที่เห็น กดเอาออกได้โดยไม่เปิดรูป
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints.tightFor(width: 36, height: 36),
                  alignment: Alignment.topRight,
                  style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  icon: const CircleAvatar(
                    radius: 11,
                    backgroundColor: Colors.black54,
                    child: Icon(Icons.close, size: 14, color: Colors.white),
                  ),
                ),
              ),
          ]),
        ),
    ]);
  }
}

Future<void> openPhotoViewer(BuildContext context, List<Photo> photos, int index) => Navigator.push(
      context,
      MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => PhotoViewerPage(photos: photos, initial: index)),
    );

/// ดูรูปเต็มจอ ปัดเปลี่ยนรูป จีบนิ้วเพื่อซูม
class PhotoViewerPage extends StatefulWidget {
  const PhotoViewerPage({super.key, required this.photos, this.initial = 0});
  final List<Photo> photos;
  final int initial;

  @override
  State<PhotoViewerPage> createState() => _PhotoViewerPageState();
}

class _PhotoViewerPageState extends State<PhotoViewerPage> {
  late final _pages = PageController(initialPage: widget.initial);
  final _zoom = TransformationController();
  late int _index = widget.initial;
  bool _zoomed = false;

  @override
  void dispose() {
    _pages.dispose();
    _zoom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          // สีตัวอักษรของธีมเป็นสีเข้มในโหมดสว่าง ต้องกำหนดทับให้อ่านได้บนพื้นดำ
          titleTextStyle: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
          systemOverlayStyle: SystemUiOverlayStyle.light,
          centerTitle: true,
          title: Text('${_index + 1}/${widget.photos.length}'),
        ),
        body: PageView.builder(
          controller: _pages,
          // ตอนซูมอยู่ การลากคือเลื่อนดูในรูป ไม่ใช่เปลี่ยนรูป
          physics: _zoomed ? const NeverScrollableScrollPhysics() : null,
          itemCount: widget.photos.length,
          onPageChanged: (i) {
            _zoom.value = Matrix4.identity();
            setState(() => _index = i);
          },
          itemBuilder: (_, i) => InteractiveViewer(
            transformationController: i == _index ? _zoom : null,
            maxScale: 5,
            onInteractionEnd: (_) => setState(() => _zoomed = _zoom.value.getMaxScaleOnAxis() > 1.01),
            child: SizedBox.expand(child: PhotoImage(widget.photos[i], fit: BoxFit.contain)),
          ),
        ),
      );
}
