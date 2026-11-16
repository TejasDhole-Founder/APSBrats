import 'package:apsbrat_frontend/core/media/photos.dart';
import 'package:apsbrat_frontend/core/theme/app_theme.dart';
import 'package:apsbrat_frontend/features/feed/presentation/widgets/feed_shared.dart';
import 'package:apsbrat_frontend/features/profile/data/profile_repository.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Pick a photo, upload it as my profile photo, and refresh everywhere that
/// shows me. Used by registration, the Profile tab and Edit profile.
/// Returns false if the user cancelled or the upload failed (they're told why).
Future<bool> changeProfilePhoto(BuildContext context, WidgetRef ref) async {
  final photo = await pickPhoto(context);
  if (photo == null || !context.mounted) return false;
  try {
    await ref.read(profileRepositoryProvider).uploadAvatar(photo);
    ref.invalidate(meProvider);
    final me = await ref.read(meProvider.future);
    if (me != null) ref.invalidate(profileProvider(me.id));
    return true;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_uploadError(e))));
    }
    return false;
  }
}

String _uploadError(Object e) {
  if (e is DioException) {
    final payload = e.response?.data;
    final message = payload is Map<String, dynamic> ? payload['error'] : null;
    if (message is String && message.isNotEmpty) return message;
  }
  return "Couldn't update your photo. Try again.";
}

/// My photo in a circle with a camera badge; tap to change it. Shows my
/// initials (or a person icon) until a photo is added.
class ProfilePhotoButton extends ConsumerStatefulWidget {
  const ProfilePhotoButton({
    super.key,
    this.size = 76,
    this.initials,
    this.onDarkBackground = true,
  });

  final double size;

  /// Shown when there's no photo yet.
  final String? initials;

  /// Gold ring on the red header; a crimson ring on white screens.
  final bool onDarkBackground;

  @override
  ConsumerState<ProfilePhotoButton> createState() => _ProfilePhotoButtonState();
}

class _ProfilePhotoButtonState extends ConsumerState<ProfilePhotoButton> {
  bool _uploading = false;

  Future<void> _change() async {
    setState(() => _uploading = true);
    await changeProfilePhoto(context, ref);
    if (mounted) setState(() => _uploading = false);
  }

  @override
  Widget build(BuildContext context) {
    final photoUrl = ref.watch(meProvider).valueOrNull?.profilePicUrl;
    final hasPhoto = (photoUrl ?? '').isNotEmpty;
    final ring = widget.onDarkBackground ? AppColors.gold : AppColors.crimson;
    final size = widget.size;

    return Semantics(
      button: true,
      label: hasPhoto ? 'Change profile photo' : 'Add a profile photo',
      child: GestureDetector(
        onTap: _uploading ? null : _change,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: kGoldLight,
                border: Border.all(color: ring, width: 3),
                shape: BoxShape.circle,
              ),
              clipBehavior: Clip.antiAlias,
              alignment: Alignment.center,
              child: _uploading
                  ? const CircularProgressIndicator(
                      color: kGoldDark,
                      strokeWidth: 2.5,
                    )
                  : hasPhoto
                  ? CachedNetworkImage(
                      imageUrl: mediaUrl(photoUrl!),
                      width: size,
                      height: size,
                      fit: BoxFit.cover,
                    )
                  : (widget.initials ?? '').isEmpty
                  ? HugeIcon(
                      icon: HugeIcons.strokeRoundedUser,
                      size: size * 0.45,
                      color: kGoldDark,
                    )
                  : Text(
                      widget.initials!,
                      style: TextStyle(
                        fontSize: size * 0.34,
                        fontWeight: FontWeight.w800,
                        color: kGoldDark,
                      ),
                    ),
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                padding: EdgeInsets.all(size * 0.07),
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.crimson, width: 2),
                ),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedCamera01,
                  size: size * 0.17,
                  color: AppColors.crimsonDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
