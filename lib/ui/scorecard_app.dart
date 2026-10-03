import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../app_controller.dart';
import '../domain/scorecard.dart';
import '../features/photo/photo_analyzer.dart';
import '../features/photo/photo_service.dart';

class ScorecardApp extends StatelessWidget {
  const ScorecardApp({
    super.key,
    required this.controller,
    required this.photos,
    this.recovered,
    this.recoveryError,
  });
  final AppController controller;
  final PhotoService photos;
  final SavedPhoto? recovered;
  final String? recoveryError;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'De Schutter',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff145a47)),
      scaffoldBackgroundColor: const Color(0xfff5f7f5),
    ),
    home: ScorecardHome(
      controller: controller,
      photos: photos,
      recovered: recovered,
      recoveryError: recoveryError,
    ),
  );
}

class ScorecardHome extends StatefulWidget {
  const ScorecardHome({
    super.key,
    required this.controller,
    required this.photos,
    this.recovered,
    this.recoveryError,
  });
  final AppController controller;
  final PhotoService photos;
  final SavedPhoto? recovered;
  final String? recoveryError;
  @override
  State<ScorecardHome> createState() => _ScorecardHomeState();
}

class _ScorecardHomeState extends State<ScorecardHome> {
  String? selectedId;
  bool capturing = false;
  AppController get controller => widget.controller;
  bool get busy => capturing || controller.busy;
  Scorecard? get selected {
    for (final card in controller.cards) {
      if (card.id == selectedId) return card;
    }
    return controller.cards.isEmpty ? null : controller.cards.first;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (controller.store.recoveredBackup)
        message(
          'De vorige opgeslagen versie is hersteld. Controleer je laatste serie.',
        );
      if (widget.recoveryError != null) message(widget.recoveryError!);
      final photo = widget.recovered;
      if (photo != null &&
          controller.cards.any((c) => c.id == photo.capture.cardId)) {
        setState(() => selectedId = photo.capture.cardId);
        showPhoto(photo);
      }
    });
  }

  void message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  Future<bool> perform(Future<void> Function() action) async {
    try {
      await action();
      return true;
    } catch (_) {
      if (mounted)
        message(
          'Opslaan is niet gelukt. Je vorige scores zijn behouden. Probeer opnieuw.',
        );
      return false;
    }
  }

  Future<void> newCard() async {
    final card = await showDialog<Scorecard>(
      context: context,
      builder: (_) => const NewCardDialog(),
    );
    if (card != null && await perform(() => controller.add(card)) && mounted)
      setState(() => selectedId = card.id);
  }

  Future<void> importCard() async {
    final input = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Scorekaart importeren'),
        content: SizedBox(
          width: 560,
          child: TextField(
            controller: input,
            maxLines: 12,
            decoration: const InputDecoration(
              labelText: 'Plak de JSON van een scorekaart',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuleren'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, input.text),
            child: const Text('Importeren'),
          ),
        ],
      ),
    );
    input.dispose();
    if (text == null || !mounted) return;
    try {
      if (text.length > 2000000)
        throw const FormatException('Bestand te groot.');
      final card = Scorecard.fromJson(jsonDecode(text) as Map<String, dynamic>);
      if (controller.cards.any((c) => c.id == card.id)) {
        message('Deze kaart bestaat al. Er wordt niets overschreven.');
        return;
      }
      if (await perform(() => controller.add(card)) && mounted)
        setState(() => selectedId = card.id);
    } catch (_) {
      if (mounted) message('Dit is geen geldige scorekaart van De Schutter.');
    }
  }

  Future<void> exportCard(Scorecard card) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Scorekaart exporteren'),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: SelectableText(card.exportJson()),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Sluiten'),
          ),
          FilledButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: card.exportJson()));
              if (context.mounted) {
                Navigator.pop(context);
                message(
                  'Scorekaart gekopieerd. Bewaar de JSON als back-up of importeer op een ander apparaat.',
                );
              }
            },
            child: const Text('Kopiëren'),
          ),
        ],
      ),
    );
  }

  Future<void> editScore(Scorecard card, int end, int arrow) async {
    final current = card.ends[end][arrow];
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Serie ${end + 1} · pijl ${arrow + 1}'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (current.proposed != null)
                Text(
                  'Voorstel: ${current.proposed!.label}. Jij bepaalt de score.',
                ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final label in Score.labels)
                    SizedBox(
                      width: 72,
                      height: 52,
                      child: FilledButton.tonal(
                        onPressed: () => Navigator.pop(context, label),
                        child: Text(
                          label,
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'X telt als 10. M is een misser. Leeg betekent nog niet ingevuld.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuleren'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'clear'),
            child: const Text('Leegmaken'),
          ),
        ],
      ),
    );
    if (choice != null)
      await perform(
        () => controller.setScore(
          card.id,
          end,
          arrow,
          choice == 'clear' ? null : Score.parse(choice),
        ),
      );
  }

  Future<void> history(Scorecard card) => showDialog<void>(
    context: context,
    builder: (context) {
      final lines = <Widget>[];
      for (var end = 0; end < card.ends.length; end++) {
        for (var arrow = 0; arrow < card.arrowsPerEnd; arrow++) {
          for (final change in card.ends[end][arrow].history.reversed) {
            lines.add(
              ListTile(
                title: Text(
                  'Serie ${end + 1}, pijl ${arrow + 1}: ${change.before ?? 'leeg'} → ${change.after ?? 'leeg'}',
                ),
                subtitle: Text(
                  '${change.at.toLocal()} · ${change.source == ScoreSource.manual ? 'handmatig' : 'foto bevestigd'}',
                ),
              ),
            );
          }
        }
      }
      return AlertDialog(
        title: const Text('Wijzigingshistorie'),
        content: SizedBox(
          width: 560,
          height: 380,
          child: lines.isEmpty
              ? const Text('Er zijn nog geen scores ingevuld.')
              : ListView(children: lines),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Sluiten'),
          ),
        ],
      );
    },
  );
  Future<void> capture(Scorecard card, int end) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Foto maken'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Foto uit galerij'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    setState(() => capturing = true);
    SavedPhoto? photo;
    try {
      photo = await widget.photos.capture(card, end, source);
    } catch (_) {
      if (mounted)
        message(
          'Foto niet opgeslagen. Controleer de cameratoestemming en vrije opslagruimte.',
        );
    } finally {
      if (mounted) setState(() => capturing = false);
    }
    if (photo != null && mounted) await showPhoto(photo);
  }

  Future<void> showPhoto(SavedPhoto photo) async {
    final card = controller.cards.firstWhere(
      (c) => c.id == photo.capture.cardId,
    );
    final analysis = await PendingPhotoAnalyzer().analyze(
      photo.file,
      target: card.target,
      expectedArrows: card.arrowsPerEnd,
    );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Foto · serie ${photo.capture.endIndex + 1}'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 300,
                  child: InteractiveViewer(
                    child: Image.file(
                      photo.file,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) =>
                          const Text('Deze foto kan niet worden weergegeven.'),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(analysis.message),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Scores handmatig invullen'),
          ),
        ],
      ),
    );
  }

  Future<void> viewPhotos(Scorecard card, int end) async {
    try {
      final photos = await widget.photos.list(card.id, end);
      if (!mounted) return;
      if (photos.isEmpty) {
        message('Deze serie heeft nog geen foto.');
        return;
      }
      final choice = await showModalBottomSheet<SavedPhoto>(
        context: context,
        builder: (context) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final photo in photos)
                ListTile(
                  leading: const Icon(Icons.image),
                  title: Text('Foto ${photo.capture.createdAt.toLocal()}'),
                  onTap: () => Navigator.pop(context, photo),
                ),
            ],
          ),
        ),
      );
      if (choice != null && mounted) await showPhoto(choice);
    } catch (_) {
      if (mounted) message('De foto kon niet worden geopend.');
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final card = selected;
      return Scaffold(
        appBar: AppBar(
          title: const Text('De Schutter'),
          actions: [
            IconButton(
              tooltip: 'Scorekaart importeren',
              onPressed: busy ? null : importCard,
              icon: const Icon(Icons.file_download_outlined),
            ),
            if (card != null)
              IconButton(
                tooltip: 'Scorekaart exporteren',
                onPressed: busy ? null : () => exportCard(card),
                icon: const Icon(Icons.file_upload_outlined),
              ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: busy ? null : newCard,
          icon: const Icon(Icons.add),
          label: const Text('Nieuwe kaart'),
        ),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: card == null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.track_changes, size: 80),
                            const SizedBox(height: 16),
                            const Text(
                              'Je eerste scorekaart',
                              style: TextStyle(fontSize: 26),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Vul scores in op de baan of thuis. Alles wordt op dit apparaat bewaard.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            FilledButton(
                              onPressed: busy ? null : newCard,
                              child: const Text('Scorekaart maken'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: card.id,
                          key: ValueKey(
                            '${card.id}-${controller.cards.length}',
                          ),
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Scorekaart',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            for (final c in controller.cards)
                              DropdownMenuItem(
                                value: c.id,
                                child: Text(
                                  '${c.shooter} · ${c.distance} m · ${c.date.toLocal().toIso8601String().substring(0, 10)}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: busy
                              ? null
                              : (id) => setState(() => selectedId = id),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          card.shooter,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        Text(
                          '${card.club.isEmpty ? '' : '${card.club} · '}${card.bow} · ${card.distance} m · ${card.target}',
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            stat('Totaal', '${card.total}'),
                            stat(
                              'Ingevuld',
                              '${card.entered}/${card.arrows.length}',
                            ),
                            stat('Treffers', '${card.hits}'),
                            stat('10 incl. X', '${card.tens}'),
                            stat('X', '${card.xs}'),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Lokaal opgeslagen · geen internet nodig · tik op een pijl om de score te wijzigen',
                        ),
                        if (busy) const LinearProgressIndicator(),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columnSpacing: 14,
                            horizontalMargin: 10,
                            columns: [
                              const DataColumn(label: Text('Serie')),
                              for (var a = 0; a < card.arrowsPerEnd; a++)
                                DataColumn(label: Text('Pijl ${a + 1}')),
                              const DataColumn(label: Text('Som')),
                              const DataColumn(label: Text('Totaal')),
                              if (PhotoService.supported)
                                const DataColumn(label: Text('Foto')),
                            ],
                            rows: [
                              for (var e = 0; e < card.ends.length; e++)
                                DataRow(
                                  cells: [
                                    DataCell(Text('${e + 1}')),
                                    for (var a = 0; a < card.arrowsPerEnd; a++)
                                      DataCell(
                                        SizedBox(
                                          width: 48,
                                          child: TextButton(
                                            onPressed: busy
                                                ? null
                                                : () => editScore(card, e, a),
                                            child: Text(
                                              card
                                                      .ends[e][a]
                                                      .finalScore
                                                      ?.label ??
                                                  '—',
                                              style: const TextStyle(
                                                fontSize: 18,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    DataCell(Text('${card.endTotal(e)}')),
                                    DataCell(Text('${card.cumulative(e)}')),
                                    if (PhotoService.supported)
                                      DataCell(
                                        Row(
                                          children: [
                                            IconButton(
                                              tooltip:
                                                  'Foto voor serie ${e + 1}',
                                              onPressed: busy
                                                  ? null
                                                  : () => capture(card, e),
                                              icon: const Icon(
                                                Icons.add_a_photo_outlined,
                                              ),
                                            ),
                                            IconButton(
                                              tooltip: 'Opgeslagen foto’s',
                                              onPressed: busy
                                                  ? null
                                                  : () => viewPhotos(card, e),
                                              icon: const Icon(
                                                Icons.photo_outlined,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => history(card),
                            icon: const Icon(Icons.history),
                            label: const Text('Wijzigingshistorie bekijken'),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      );
    },
  );
  Widget stat(String label, String value) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    ),
  );
}

class NewCardDialog extends StatefulWidget {
  const NewCardDialog({super.key});
  @override
  State<NewCardDialog> createState() => _NewCardDialogState();
}

class _NewCardDialogState extends State<NewCardDialog> {
  final form = GlobalKey<FormState>();
  final shooter = TextEditingController(),
      club = TextEditingController(),
      distance = TextEditingController(text: '18');
  int arrows = 3, ends = 12;
  String bow = 'Recurve', target = 'WA 10-ringen';
  @override
  void dispose() {
    shooter.dispose();
    club.dispose();
    distance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Nieuwe scorekaart'),
    content: SizedBox(
      width: 460,
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: shooter,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Naam schutter'),
                validator: (s) =>
                    s == null || s.trim().isEmpty ? 'Vul een naam in.' : null,
              ),
              TextFormField(
                controller: club,
                decoration: const InputDecoration(
                  labelText: 'Vereniging (optioneel)',
                ),
              ),
              TextFormField(
                controller: distance,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Afstand in meters',
                ),
                validator: (s) =>
                    int.tryParse(s ?? '') == null ||
                        int.parse(s!) <= 0 ||
                        int.parse(s) > 1000
                    ? 'Vul een afstand van 1–1000 m in.'
                    : null,
              ),
              DropdownButtonFormField(
                initialValue: bow,
                decoration: const InputDecoration(labelText: 'Boogklasse'),
                items: [
                  for (final b in [
                    'Recurve',
                    'Compound',
                    'Barebow',
                    'Longbow',
                    'Overig',
                  ])
                    DropdownMenuItem(value: b, child: Text(b)),
                ],
                onChanged: (b) => bow = b!,
              ),
              DropdownButtonFormField(
                initialValue: target,
                decoration: const InputDecoration(
                  labelText: 'Blazoen / scoreprofiel',
                ),
                items: [
                  for (final t in [
                    'WA 10-ringen',
                    'WA indoor compound (binnenste 10)',
                    'Overig (handmatig)',
                  ])
                    DropdownMenuItem(value: t, child: Text(t)),
                ],
                isExpanded: true,
                onChanged: (t) => target = t!,
              ),
              DropdownButtonFormField(
                initialValue: arrows,
                decoration: const InputDecoration(
                  labelText: 'Pijlen per serie',
                ),
                items: [
                  for (final n in [3, 6])
                    DropdownMenuItem(value: n, child: Text('$n')),
                ],
                onChanged: (n) => arrows = n!,
              ),
              DropdownButtonFormField(
                initialValue: ends,
                decoration: const InputDecoration(labelText: 'Aantal series'),
                items: [
                  for (final n in [6, 10, 12, 20, 24])
                    DropdownMenuItem(value: n, child: Text('$n')),
                ],
                onChanged: (n) => ends = n!,
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annuleren'),
      ),
      FilledButton(
        onPressed: () {
          if (form.currentState!.validate())
            Navigator.pop(
              context,
              Scorecard.create(
                shooter: shooter.text,
                club: club.text,
                distance: int.parse(distance.text),
                bow: bow,
                target: target,
                arrowsPerEnd: arrows,
                endCount: ends,
              ),
            );
        },
        child: const Text('Aanmaken'),
      ),
    ],
  );
}
