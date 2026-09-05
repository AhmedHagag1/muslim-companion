import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'app/app.dart';
import 'data/repositories/quran_audio_repository.dart';
import 'features/audio/quran_audio_controller.dart';
import 'features/audio/quran_audio_engine.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  tz.initializeTimeZones();

  QuranAudioController? audioController;
  try {
    audioController = QuranAudioController(
      repository: EveryAyahAudioRepository(),
      engine: await JustAudioQuranEngine.create(),
    );
    await audioController.initialize();
  } catch (_) {
    audioController = null;
  }
  runApp(QuranApp(audioController: audioController));
}
