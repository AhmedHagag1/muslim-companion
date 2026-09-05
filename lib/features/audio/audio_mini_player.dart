import 'package:flutter/material.dart';

import '../../data/models/surah.dart';
import 'quran_audio_controller.dart';

class AudioMiniPlayer extends StatelessWidget {
  const AudioMiniPlayer({super.key, required this.controller, this.onOpen});
  final QuranAudioController controller;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (!controller.hasActiveItem) return const SizedBox.shrink();
        final surah = QuranMetadata.surah(controller.currentSurahNumber!);
        final loading =
            controller.status == QuranAudioStatus.loading ||
            controller.status == QuranAudioStatus.buffering;
        return Material(
          key: const ValueKey('audio-mini-player'),
          elevation: 8,
          color: Theme.of(context).colorScheme.surface,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (controller.duration != null)
                  LinearProgressIndicator(value: controller.positionFraction),
                ListTile(
                  key: const ValueKey('audio-mini-player-open'),
                  onTap: onOpen,
                  title: Text(
                    'سورة ${surah.name} • الآية ${controller.currentAyahNumber}',
                  ),
                  subtitle: Text(
                    controller.selectedReciter?.displayNameArabic ?? '',
                  ),
                  leading: IconButton(
                    tooltip: 'الآية السابقة',
                    onPressed: controller.canPreviousAyah
                        ? controller.previousAyah
                        : null,
                    icon: const Icon(Icons.skip_previous_rounded),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: controller.isPlaying ? 'إيقاف مؤقت' : 'تشغيل',
                        onPressed: loading
                            ? null
                            : controller.isPlaying
                            ? controller.pause
                            : controller.resume,
                        icon: loading
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                controller.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                              ),
                      ),
                      IconButton(
                        tooltip: 'الآية التالية',
                        onPressed: controller.canNextAyah
                            ? controller.nextAyah
                            : null,
                        icon: const Icon(Icons.skip_next_rounded),
                      ),
                      IconButton(
                        key: const ValueKey('audio-mini-player-close'),
                        tooltip: 'إيقاف وإغلاق',
                        onPressed: controller.stop,
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
