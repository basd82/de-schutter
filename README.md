# De Schutter

Eén Flutter-app voor **iPhone, Android, macOS en Windows**, ontwikkeld met IntelliJ IDEA. Scorekaarten werken offline op ieder platform. Foto-opname en toekomstige blazoenherkenning zijn uitsluitend voor de mobiele apps.

Dit is een eerste projectbasis (0.1.0), geen gepubliceerde winkelapp. Handmatige scorekaarten, lokale opslag, import/export via JSON en wijzigingshistorie zijn geïmplementeerd. Mobiel kan foto's per serie vastleggen en terugkijken. **Automatische ring- en pijlherkenning is nog niet geïmplementeerd.** De app meldt dit en verzint geen scores of zekerheidspercentages.

## Platforms

| Functie | iPhone | Android | macOS | Windows |
| --- | --- | --- | --- | --- |
| Scorekaart invullen en bekijken | Ja | Ja | Ja | Ja |
| Scores corrigeren met historie | Ja | Ja | Ja | Ja |
| Offline bewaren | Ja | Ja | Ja | Ja |
| JSON-kaarten uitwisselen | Ja | Ja | Ja | Ja |
| Foto vastleggen / galerij / terugkijken | Ja | Ja | — | — |
| Automatisch scorevoorstel | Gepland | Gepland | — | — |
| Accounts en server-synchronisatie | Gepland | Gepland | Gepland | Gepland |

## Openen in IntelliJ IDEA

1. Installeer [Flutter stable](https://docs.flutter.dev/install/manual). De projectbasis gebruikt **Flutter 3.47.6**; Dart zit in de SDK.
2. Installeer de **Flutter**-plugin in IntelliJ IDEA (de Dart-plugin wordt ook benodigd).
3. Open de map waarin `pubspec.yaml` staat. Stel het Flutter SDK-pad in bij **Settings → Languages & Frameworks → Flutter**.
4. Voer in de projectterminal `flutter pub get` uit.
5. Open `lib/main.dart`, kies een apparaat bij de Flutter-runconfiguratie en druk op Run.

Native projectbestanden staan al in `android/`, `ios/`, `macos/` en `windows/`. De Android Gradle-wrapper en de pluginregistratie worden door Flutter bij de eerste build gegenereerd. Wijzig lokale SDK-paden of gegenereerde bestanden niet in Git. Commit `pubspec.lock` nadat de eerste succesvolle `flutter pub get` de exacte afhankelijkheden heeft vastgelegd.

```sh
flutter doctor
flutter pub get
flutter run -d macos
flutter run -d windows
flutter devices
```

`macos` bouw je op een Mac met Xcode. iOS bouwen vereist ook macOS/Xcode; stel voor een fysieke iPhone in Xcode jouw Apple development team in. Windows bouwen vereist Windows en Visual Studio met **Desktop development with C++**. Android vereist de Android SDK; gebruik Android Studio voor SDK/emulatorbeheer als je programmeert in IntelliJ. Zie [Flutter platform setup](https://docs.flutter.dev/install/custom).

## Eerste gebruik

Maak een scorekaart met naam, vereniging, boogklasse, afstand, blazoen en 3 of 6 pijlen per serie. Tik op een pijl en kies `X`, `10` tot `1` of `M`. Een lege cel is een nog niet ingevulde pijl; een `M` is een ingevulde misser. X telt als 10 en wordt afzonderlijk geteld. De kolom **10 incl. X** bevat beide.

Elke bevestigde wijziging wordt eerst op schijf bewaard. Pas na een geslaagde opslag verandert de kaart op het scherm. De app bewaart de vorige opgeslagen verzameling als back-up en meldt het als die hersteld moest worden. Als beide bestanden onleesbaar zijn, stopt de app met een melding in plaats van je gegevens te overschrijven.

Op mobiel: kies het foto-icoon van een serie om een foto te maken of uit de galerij te kiezen. De originele foto en de koppeling naar kaart/serie worden lokaal bewaard. Zoom om de inslagen te beoordelen en vul daarna de scores zelf in. Met het galerij-icoon kun je opgeslagen foto's opnieuw bekijken. Bij een door Android onderbroken camera-activiteit probeert de app de opname na herstart te herstellen.

Met **Exporteren** kopieer je de JSON-scorekaart; sla de tekst op als `.json` of plak die op een ander apparaat in **Importeren**. Historie en oorspronkelijke herkenningsvoorstellen zijn onderdeel van dit formaat; foto's worden niet meegestuurd. Importeren weigert een al aanwezige kaart-id. Er is nog geen automatische synchronisatie of het samenvoegen van wijzigingen op meerdere apparaten.

## Ontwikkelen en controleren

De gedeelde IntelliJ-runconfiguratie staat in `.run/De-Schutter.run.xml`.

```sh
dart format lib test tool
flutter analyze --fatal-infos
flutter test --coverage
dart tool/offline_check.dart
```

De zelfstandige laatste controle gebruikt alleen Dart en controleert scores, handmatige correcties, serialisatie, opslag en back-upherstel. GitHub Actions is ingericht voor analyse/tests en native debugbuilds voor alle vier platforms. De iOS-build is voor de simulator. Dit levert nog geen getekende App Store, Play Store of desktoprelease op.

## Repository aanmaken

Als de repository nog niet via GitHub is aangemaakt, kun je op je eigen computer met [GitHub CLI](https://cli.github.com/) en account `basd82` uitvoeren:

```sh
gh auth login
bash tool/publish_github.sh
```

Dit maakt **publiek** `basd82/de-schutter` aan en pusht het project. Het script stopt als die repository of een origin-remote al bestaat, zodat niets wordt overschreven. Bij gebruik van de Windows-terminal kan dit in Git Bash. Dit script is niet uitgevoerd in de omgeving waarin deze projectbasis gemaakt is.

Bij het maken van deze projectbasis zijn **14 zelfstandige controles geslaagd** en zijn de Dart-bestanden geformatteerd. Flutter zelf kon in de bouwomgeving niet starten door een veiligheidsblokkade op een cloud-metadata-aanroep. De native bestanden zijn daarom vanuit de officiële sjablonen van Flutter 3.47.6 opgebouwd. **Volledige Flutter-analyse, widgettests en native builds moeten nog slagen op CI of op jouw ontwikkelmachine.**

## Structuur

```text
lib/domain/                scores, kaarten en wijzigingshistorie
lib/data/                  lokale opslag en herstel
lib/features/photo/        mobiel vastleggen, fotoarchief en analysemodule-interface
lib/ui/                    gezamenlijke scorekaart-interface
lib/app_controller.dart    wijzigingen opslaan vóór het scherm wordt bijgewerkt
test/                      score-, opslag- en widgettests
tool/offline_check.dart    zelfstandige Dart-controles
docs/ARCHITECTURE.md        ontwerp en fotoherkenningsplan
docs/ROADMAP.md             vervolgstappen
```

De originele voorbeeldfoto's worden niet als publieke repository-assets of als runtime-dataset opgenomen. Verwerk ze later lokaal als afzonderlijke testset. Native sjablonen en standaardiconen komen van Flutter; de bijbehorende licenties staan in `docs/`.
