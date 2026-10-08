# De Schutter

Eén Flutter-app voor **iPhone, Android, macOS en Windows**, ontwikkeld met IntelliJ IDEA. Scorekaarten werken offline op ieder platform. Foto-opname werkt op mobiel. Foto’s selecteren, lokaal analyseren en controleren kan ook op desktop.

Dit is een eerste projectbasis (0.1.0), geen gepubliceerde winkelapp. Handmatige scorekaarten, lokale opslag, import/export via JSON en wijzigingshistorie zijn geïmplementeerd. Mobiel kan foto's per serie vastleggen. Alle platforms kunnen bestaande foto's openen en terugkijken. **Lokale ring- en pijlherkenning voor één volledig WA 10-ringenblazoen is nu beschikbaar als experimentele beeldverwerking.** De app zoekt gekleurde ringen en langwerpige schachten, corrigeert perspectief en toont scorevoorstellen. Oude gaten, schaduwen en overlappende pijlen kunnen fouten geven; er worden geen zekerheidspercentages getoond.

## Platforms

| Functie | iPhone | Android | macOS | Windows |
| --- | --- | --- | --- | --- |
| Scorekaart invullen en bekijken | Ja | Ja | Ja | Ja |
| Scores corrigeren met historie | Ja | Ja | Ja | Ja |
| Offline bewaren | Ja | Ja | Ja | Ja |
| JSON-kaarten uitwisselen | Ja | Ja | Ja | Ja |
| Foto maken / galerij | Ja | Ja | — | — |
| Bestaande foto openen / terugkijken | Ja | Ja | Ja | Ja |
| Automatisch scorevoorstel | Gepland | Gepland | — | — |
| Accounts en server-synchronisatie | Gepland | Gepland | Gepland | Gepland |

## Openen in IntelliJ IDEA

1. Installeer [Flutter stable](https://docs.flutter.dev/install/manual). De projectbasis gebruikt **Flutter 3.47.6**; Dart zit in de SDK.
2. Installeer de **Flutter**-plugin in IntelliJ IDEA (de Dart-plugin wordt ook benodigd).
3. Open de map waarin `pubspec.yaml` staat. Stel het Flutter SDK-pad in bij **Settings → Languages & Frameworks → Flutter**.
4. Voer in de projectterminal `flutter pub get` uit.
5. Open `lib/main.dart`, kies een apparaat bij de Flutter-runconfiguratie en druk op Run.

Native projectbestanden staan al in `android/`, `ios/`, `macos/` en `windows/`. De Android Gradle-wrapper en de pluginregistratie worden door Flutter bij de eerste build gegenereerd. Op iOS en macOS voegt Flutter de Swift Package Manager-koppeling automatisch toe; alle huidige plug-ins ondersteunen die koppeling. Wijzig lokale SDK-paden of gegenereerde bestanden niet in Git. `pubspec.lock` bevat de exacte afhankelijkheden die GitHub Actions heeft opgehaald.

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

Op desktop kun je met het map-icoon een bestaande blazoenfoto kiezen. De foto wordt bij die serie bewaard en kan daarna via het galerij-icoon worden teruggekeken. Camera en analyse ontbreken op desktop. Foto’s van je telefoon worden nog niet automatisch gesynchroniseerd: breng ze zelf over en open ze op desktop.

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

## GitHub

De publieke repository staat op [github.com/basd82/de-schutter](https://github.com/basd82/de-schutter). Clone deze repository en open de projectmap in IntelliJ IDEA:

```sh
git clone https://github.com/basd82/de-schutter.git
cd de-schutter
flutter pub get
```

`tool/publish_github.sh` is alleen bedoeld voor een nieuwe repository. Het stopt als `basd82/de-schutter` of een origin-remote al bestaat.

GitHub Actions controleert de opmaak, Flutter-analyse, **8 tests** en **14 zelfstandige offline controles**. Daarnaast bouwt de workflow alle vier platforms. Bekijk de actuele resultaten en download de debugbuilds via het tabblad **Actions**. Test camera, fototoegang en opslag ook op echte apparaten voordat je een release verspreidt.

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

## Blazoenfoto analyseren

1. Kies een foto bij de juiste serie. Foto’s blijven lokaal; analyse draait buiten de UI-thread.
2. Controleer of de groene ringen samenvallen met het blazoen. Met **Blazoen afstellen** sleep je B/R/O/L naar de vier buitenste 1-ringpunten. Dit werkt ook wanneer automatische detectie mislukt.
3. Verplaats de genummerde pijlen naar de werkelijke inslagpunten, verwijder fout gevonden pijlen en tik om ontbrekende pijlen toe te voegen. Een missende pijl krijgt nooit automatisch M.
4. Kies de fysieke blazoendiameter en pijldiameter voor de lijnregel. Bij 0 mm is de pijldiameter onbekend: controleer lijngevallen handmatig. Controleer de kleine compound-10 en het gebruik van X; defaults zijn slechts suggesties op basis van boog en afstand.
5. Iedere score kan via de scoreknoppen worden overschreven. Vink de blazoencontrole en elke pijlcontrole aan. Alleen bij precies het verwachte aantal pijlen kun je bevestigen.
6. Bevestigde scores worden in één opslagactie overgenomen; bestaande ingevoerde of handmatig gewiste scores blijven beschermd. Ze kunnen op de scorekaart nog steeds handmatig worden gewijzigd.

Geometrie, gecorrigeerde punten, instellingen en voorstellen blijven bij de foto bewaard. De scorekaart bewaart voorstellen, definitieve scores en wijzigingshistorie. Een heropende foto vereist opnieuw controle. Herkenning is geen gevalideerde automatische jurering: vooral kruisende schachten en veren vragen correctie. Meervoudige/Field-blazoenen worden nog niet ondersteund. JPEG/PNG werken; niet decodeerbare bestanden houden hun oorspronkelijke foto en krijgen handmatige score-invoer.

Voor lokale evaluatie met eigen foto’s: `dart run tool/evaluate_photos.dart /pad/naar/fotos /tmp/evaluatie`. Dit hulpmiddel schrijft alleen lokale overlays, zonder foto’s te uploaden.
