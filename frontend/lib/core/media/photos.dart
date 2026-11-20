import 'package:apsbrat_frontend/core/constants/api_endpoints.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:apsbrat_frontend/core/constants/env.dart';
import 'package:apsbrat_frontend/core/network/api_response.dart';
import 'package:apsbrat_frontend/core/network/dio_client.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// The server stores photos as "/media/…"; the app needs the full address.
String mediaUrl(String path) {
  if (path.startsWith('http://') || path.startsWith('https://')) return path;
  return '${Uri.parse(Env.baseUrl).origin}$path';
}

/// Lets the user choose a photo: camera or gallery on a phone, a file on
/// the web. Phones shrink and convert it to JPEG before upload, so a 12 MP
/// camera shot doesn't eat mobile data. Returns null if they cancel.
Future<XFile?> pickPhoto(BuildContext context) async {
  ImageSource source = ImageSource.gallery;
  final platform = Theme.of(context).platform;
  final isPhone =
      platform == TargetPlatform.android || platform == TargetPlatform.iOS;
  if (isPhone) {
    final choice = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const HugeIcon(
                icon: HugeIcons.strokeRoundedCamera01,
                size: 22,
              ),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const HugeIcon(
                icon: HugeIcons.strokeRoundedImage02,
                size: 22,
              ),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return null;
    source = choice;
  }
  return ImagePicker().pickImage(
    source: source,
    maxWidth: 2000,
    maxHeight: 2000,
    imageQuality: 85,
  );
}

/// Several photos at once (for a post's slider): pick from the gallery,
/// or take one with the camera on a phone. Returns [] if they cancel.
Future<List<XFile>> pickPhotos(BuildContext context, {required int max}) async {
  final platform = Theme.of(context).platform;
  final isPhone =
      platform == TargetPlatform.android || platform == TargetPlatform.iOS;
  if (isPhone) {
    final choice = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const HugeIcon(
                icon: HugeIcons.strokeRoundedCamera01,
                size: 22,
              ),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const HugeIcon(
                icon: HugeIcons.strokeRoundedImage02,
                size: 22,
              ),
              title: Text(
                max == 1
                    ? 'Choose from gallery'
                    : 'Choose up to $max from gallery',
              ),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return const [];
    if (choice == ImageSource.camera) {
      final shot = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 85,
      );
      return shot == null ? const [] : [shot];
    }
  }
  final picked = await ImagePicker().pickMultiImage(
    limit: max < 2 ? null : max,
    maxWidth: 2000,
    maxHeight: 2000,
    imageQuality: 85,
  );
  return picked.take(max).toList();
}

/// Sends a picked photo as bytes, which works the same on web and phones
/// (a file path does not exist on the web).
Future<MultipartFile> photoPart(XFile file) async {
  final bytes = await file.readAsBytes();
  final name = file.name.isEmpty ? 'photo.jpg' : file.name;
  final type =
      file.mimeType ??
      (name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg');
  return MultipartFile.fromBytes(
    bytes,
    filename: name,
    contentType: DioMediaType.parse(type),
  );
}

/// Which folder a photo is grouped under in storage. Profile photos go through
/// [ProfileRepository.uploadAvatar] instead — an avatar replaces the one photo
/// rather than attaching a new one, so it isn't one of these.
enum UploadKind { post, chat, event }

class MediaRepository {
  MediaRepository(this._dio);
  final Dio _dio;

  /// Uploads a photo for a post, chat message or event. Returns its address to attach.
  Future<String> uploadPhoto(XFile file, {required UploadKind kind}) async {
    final res = await _dio.post<dynamic>(
      ApiEndpoints.mediaImages,
      queryParameters: {'kind': kind.name},
      data: FormData.fromMap({'file': await photoPart(file)}),
    );
    return dataMap(res)['url'] as String;
  }
}

final mediaRepositoryProvider = Provider<MediaRepository>(
  (ref) => MediaRepository(ref.watch(dioProvider)),
);

/// A photo from the server, with a soft placeholder while it loads and a
/// quiet icon if it can't. Tap opens it full screen.
class NetworkPhoto extends StatelessWidget {
  const NetworkPhoto({
    super.key,
    required this.url,
    this.maxHeight = 360,
    this.borderRadius = 12,
    this.openOnTap = true,
  });

  final String url;
  final double maxHeight;
  final double borderRadius;
  final bool openOnTap;

  @override
  Widget build(BuildContext context) {
    final full = mediaUrl(url);
    return GestureDetector(
      onTap: openOnTap ? () => showPhotoViewer(context, full) : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: CachedNetworkImage(
            imageUrl: full,
            fit: BoxFit.cover,
            width: double.infinity,
            placeholder: (_, _) =>
                Container(height: 200, color: const Color(0xFFF3F0EC)),
            errorWidget: (_, _, _) => Container(
              height: 120,
              color: const Color(0xFFF3F0EC),
              alignment: Alignment.center,
              child: const HugeIcon(
                icon: HugeIcons.strokeRoundedImageNotFound01,
                color: Color(0xFF9A7070),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Instagram-style: swipe between a post's photos, with dots below and an
/// "n/N" badge. Every photo fills the same 4:5 frame so posts line up.
/// Tap opens the photos full screen.
class PhotoSlider extends StatefulWidget {
  const PhotoSlider({super.key, required this.urls, this.borderRadius = 12});

  final List<String> urls;
  final double borderRadius;

  @override
  State<PhotoSlider> createState() => _PhotoSliderState();
}

class _PhotoSliderState extends State<PhotoSlider> {
  final _pages = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.urls;
    final many = urls.length > 1;
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: AspectRatio(
            aspectRatio: 4 / 5,
            child: Stack(
              children: [
                PageView.builder(
                  // Swipe with a mouse or trackpad too (web), not just touch.
                  scrollBehavior: const _SwipeEverywhere(),
                  controller: _pages,
                  itemCount: urls.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) => GestureDetector(
                    onTap: () => showPhotoGallery(context, urls, initial: i),
                    child: CachedNetworkImage(
                      imageUrl: mediaUrl(urls[i]),
                      fit: BoxFit.cover,
                      placeholder: (_, _) =>
                          Container(color: const Color(0xFFF3F0EC)),
                      errorWidget: (_, _, _) => Container(
                        color: const Color(0xFFF3F0EC),
                        alignment: Alignment.center,
                        child: const HugeIcon(
                          icon: HugeIcons.strokeRoundedImageNotFound01,
                          color: Color(0xFF9A7070),
                        ),
                      ),
                    ),
                  ),
                ),
                if (many)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        '${_index + 1}/${urls.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (many) ...[
          const SizedBox(height: 8),
          Semantics(
            label: 'Photo ${_index + 1} of ${urls.length}',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < urls.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 2.5),
                    width: i == _index ? 7 : 6,
                    height: i == _index ? 7 : 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _index
                          ? const Color(0xFF8B1118)
                          : const Color(0xFFD9CFCF),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Lets a mouse or trackpad drag the slider, like a finger does.
class _SwipeEverywhere extends MaterialScrollBehavior {
  const _SwipeEverywhere();

  @override
  Set<PointerDeviceKind> get dragDevices => PointerDeviceKind.values.toSet();
}

/// Full-screen photos: swipe between them, pinch to zoom, X to close.
Future<void> showPhotoGallery(
  BuildContext context,
  List<String> urls, {
  int initial = 0,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black,
    builder: (_) => _Gallery(urls: urls, initial: initial),
  );
}

class _Gallery extends StatefulWidget {
  const _Gallery({required this.urls, required this.initial});

  final List<String> urls;
  final int initial;

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  late final _pages = PageController(initialPage: widget.initial);
  late int _index = widget.initial;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: PageView.builder(
            // Swipe with a mouse or trackpad too (web), not just touch.
            scrollBehavior: const _SwipeEverywhere(),
            controller: _pages,
            itemCount: widget.urls.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) => InteractiveViewer(
              maxScale: 4,
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: mediaUrl(widget.urls[i]),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: SafeArea(
            child: IconButton(
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).pop(),
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedCancel01,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ),
        if (widget.urls.length > 1)
          Positioned(
            top: 24,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Center(
                child: Text(
                  '${_index + 1} / ${widget.urls.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Full-screen photo with pinch-to-zoom. Tap or swipe the X to close.
Future<void> showPhotoViewer(BuildContext context, String fullUrl) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black,
    builder: (dialogContext) => Stack(
      children: [
        Positioned.fill(
          child: InteractiveViewer(
            maxScale: 4,
            child: Center(
              child: CachedNetworkImage(imageUrl: fullUrl, fit: BoxFit.contain),
            ),
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: SafeArea(
            child: IconButton(
              tooltip: 'Close',
              onPressed: () => Navigator.of(dialogContext).pop(),
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedCancel01,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
