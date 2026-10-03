import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'app_controller.dart';
import 'data/scorecard_store.dart';
import 'features/photo/photo_service.dart';
import 'ui/scorecard_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final directory = await getApplicationSupportDirectory();
    final controller = AppController(ScorecardStore(directory));
    await controller.load();
    final photos = PhotoService(directory);
    SavedPhoto? recovered;
    String? recoveryError;
    try {
      recovered = await photos.recover();
    } catch (_) {
      recoveryError = 'Een onderbroken foto-opname kon niet worden hersteld.';
    }
    runApp(
      ScorecardApp(
        controller: controller,
        photos: photos,
        recovered: recovered,
        recoveryError: recoveryError,
      ),
    );
  } catch (error) {
    // Do not silently replace unreadable scorecards with an empty collection.
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: SelectableText(
                'De opgeslagen kaarten konden niet worden geopend. Je bestanden zijn behouden.\nHerstart de app of herstel een JSON-back-up.\n\n${error is FormatException ? error.message : 'Controleer de lokale opslag.'}',
              ),
            ),
          ),
        ),
      ),
    );
  }
}
