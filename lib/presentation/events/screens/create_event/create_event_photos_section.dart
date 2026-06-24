import '../../../widgets/common/app_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class CreateEventPhotosSection extends StatelessWidget {
  const CreateEventPhotosSection({
    super.key,
    required this.decoration,
    required this.uploadedPhotoUrls,
    required this.pendingPhotoUploads,
    required this.isPhotoUploading,
    required this.maxEventPhotos,
    required this.onPickImages,
    required this.onRemoveUploadedPhoto,
  });

  final BoxDecoration decoration;
  final List<String> uploadedPhotoUrls;
  final int pendingPhotoUploads;
  final bool isPhotoUploading;
  final int maxEventPhotos;
  final VoidCallback onPickImages;
  final ValueChanged<int> onRemoveUploadedPhoto;

  bool get _canAddMore =>
      uploadedPhotoUrls.length + pendingPhotoUploads < maxEventPhotos;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: decoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _SectionHeader(
            uploadedCount: uploadedPhotoUrls.length,
            maxEventPhotos: maxEventPhotos,
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onPickImages,
            child: Container(
              height: 176,
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.84),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.14),
                ),
              ),
              child: isPhotoUploading
                  ? const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : uploadedPhotoUrls.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: AppNetworkImage(
                            imageUrl: uploadedPhotoUrls.first,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                            errorWidget: (context, url, error) => Icon(
                              Icons.broken_image_rounded,
                              size: 30,
                              color: AppColors.dark.withValues(alpha: 0.44),
                            ),
                          ),
                        )
                      : _EmptyCover(onPickImages: onPickImages),
            ),
          ),
          if (uploadedPhotoUrls.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            SizedBox(
              height: 86,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: uploadedPhotoUrls.length + (_canAddMore ? 1 : 0),
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  if (index == uploadedPhotoUrls.length && _canAddMore) {
                    return _AddTile(onPickImages: onPickImages);
                  }

                  final url = uploadedPhotoUrls[index];
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: AppNetworkImage(
                          imageUrl: url,
                          width: 86,
                          height: 86,
                          fit: BoxFit.cover,
                          placeholder: (context, _) => Container(
                            width: 86,
                            height: 86,
                            color: AppColors.surface.withValues(alpha: 0.84),
                            child: const Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          ),
                          errorWidget: (context, _, __) => Container(
                            width: 86,
                            height: 86,
                            color: AppColors.surface.withValues(alpha: 0.84),
                            child: Icon(
                              Icons.broken_image_rounded,
                              color: AppColors.dark.withValues(alpha: 0.42),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 5,
                        right: 5,
                        child: GestureDetector(
                          onTap: () => onRemoveUploadedPhoto(index),
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: AppColors.dark.withValues(alpha: 0.62),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.22),
                              ),
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.uploadedCount,
    required this.maxEventPhotos,
  });

  final int uploadedCount;
  final int maxEventPhotos;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.photo_camera_back_rounded,
            size: 18,
            color: AppColors.primary.withValues(alpha: 0.92),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Обложка',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.dark.withValues(alpha: 0.86),
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'До $maxEventPhotos фото • первое будет главным',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.dark.withValues(alpha: 0.58),
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
        Text(
          '$uploadedCount/$maxEventPhotos',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: AppColors.dark.withValues(alpha: 0.56),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _EmptyCover extends StatelessWidget {
  const _EmptyCover({required this.onPickImages});

  final VoidCallback onPickImages;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.add_photo_alternate_outlined,
            size: 28,
            color: AppColors.primary.withValues(alpha: 0.92),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Добавить фото',
          style: TextStyle(
            color: AppColors.dark.withValues(alpha: 0.78),
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Нажмите для загрузки',
          style: TextStyle(
            color: AppColors.dark.withValues(alpha: 0.56),
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onPickImages});

  final VoidCallback onPickImages;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPickImages,
      child: Container(
        width: 86,
        height: 86,
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.84),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.14),
          ),
        ),
        child: Icon(
          Icons.add_photo_alternate_outlined,
          color: AppColors.primary.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}

