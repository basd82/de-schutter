# Ontwerp

## Harde uitgangspunten

- Android/iPhone verwerken foto's op het toestel. De app heeft nu geen server of AI-API nodig.
- macOS/Windows bieden scorekaarten en het openen/terugkijken van bestaande foto’s. De interface en `PhotoService` blokkeren camera-opname op desktop; desktop roept ook de analyse-engine niet aan.
- Herkenning levert voorstellen. Alleen bevestigde scores tellen mee.
- Handmatig ingevulde, gecorrigeerde of leeggemaakte scores worden nooit overschreven door een nieuw herkenningsresultaat.
- De oorspronkelijke voorgestelde score, definitieve score en wijzigingshistorie blijven gescheiden.
- Een misser, een X en een nog niet ingevulde pijl zijn verschillende waarden.
- Geen internet nodig voor invullen, bewaren of mobiele foto-opname.

## Lokale opslag

`getApplicationSupportDirectory()` kiest de applicatieopslag op elk platform. `scorecards.json` bevat versie 1 van het gegevensformaat. Elke pijl heeft `proposed`, `final`, `confidence` en `history`. De historie bevat tijdstip, oude/nieuwe score en invoerbron. Dit is een praktische lokale historie, geen beveiligde of onveranderlijke wedstrijdregistratie.

Opslag schrijft naar `scorecards.tmp`, flusht en vervangt de primaire file via rename. De vorige geldige primaire file blijft als `scorecards.backup.json`. Een beschadigd primair bestand wordt bewaard als `scorecards.corrupt.json`. De controller staat één opslag tegelijk toe. Dit ontwerp gaat uit van één app-proces; gelijktijdige processen en OS/crash-atomiciteit moeten vóór productie per platform worden getest. De vorige versie is een herstelmiddel, geen externe back-up. Gebruik JSON-export om belangrijke kaarten ook elders te bewaren.

Foto's hebben een eigen `photos/<id>.<ext>` en `photos/<id>.json` met kaart-id, serie-index en opnametijd. JSON-kaartuitwisseling bevat geen foto's of absolute bestandspaden. Er wordt niets automatisch geüpload. Opslagquota, fotocompressie en verwijderbeleid volgen later.

## Fotoherkenning — volgende ontwikkelfase

`PhotoAnalyzer` heeft een verwisselbare engine. `PendingPhotoAnalyzer` meldt dat herkenning nog niet beschikbaar is. Er is geen dummy-model of willekeurige score.

1. Kies het juiste blazoen en het expliciete scoreprofiel, inclusief compound indoor en meervoudige blazoenen.
2. Beoordeel scherpte, zichtbaarheid, belichting en voldoende resolutie.
3. Bepaal het blazoenvlak en de perspectieftransformatie. Een enkele ellips is onvoldoende om willekeurige perspectiefvervorming ondubbelzinnig te herstellen; gebruik meerdere ringen, kalibratie of extra referentiepunten.
4. Volg zichtbare schachten tot de overgang met het papier. Oude gaten, schaduw, veren en kruisingen zijn geen bewezen inslagpunten. Verlengde schachtlijnen kunnen een verborgen inslag niet eenduidig bepalen uit één foto.
5. Bewaar inslagpositie, schachtdiameter in het doelvlak, geometrie, modelversie en eventuele onzekerheid.
6. Bereken een scorevoorstel volgens het gekozen ringprofiel. Behandel lijngevallen en slecht zichtbare pijlen als handmatig te beoordelen. Geef geen zekerheidpercentage zolang dit niet is gekalibreerd op onafhankelijke testfoto's.
7. Toon genummerde inslagmarkeringen en laat de schutter ontbrekende/extra pijlen toevoegen/verwijderen, posities verplaatsen en iedere score aanpassen.
8. Neem alleen na bevestiging scores over in de kaart; behoud reeds ingevoerde menselijke scores. Bij vervanging van een hele serie is expliciete bevestiging nodig.

Voer beeldverwerking buiten de UI-thread uit, met een kleinere werkafbeelding en hoge-resolutie uitsneden voor twijfelgevallen. Onderzoek eerst klassieke beeldverwerking; kies pas na meting een klein on-device model. Flutter kan native Swift/Kotlin/C++ koppelen via platform channels of FFI. OpenCV/ONNX/LiteRT zijn hier nog geen dependencies: eerst de representatieve dataset annoteren en prestaties meten op een echte iPhone en een middelklasse Android.

De eerder genoemde snelle analysetijden en beperkte serverbehoefte zijn ontwerpdoelen, geen gemeten prestaties op deze foto's. Mobiele fotoherkenning kan zonder netwerk blijven; centrale opslag en synchronisatie zijn een latere optionele toevoeging.

## Synchronisatie — later

Geen backend in versie 0.1.0. Ontwerp voordat accounts worden toegevoegd een API met kaart-id's, serverrevisies, wijzigings-id's, idempotente uploads en een lokale outbox. Bij gelijktijdige wijzigingen aan dezelfde pijl mag de server geen menselijke score stilzwijgend vervangen. Bewaar beide wijzigingen en laat de gebruiker het conflict oplossen. Exporteer foto's alleen met een aparte expliciete instelling. Voeg authenticatie, autorisatie per kaart en migraties toe voordat deze laag in gebruik komt.

## Platformlevering

Een gedeelde Flutter/Dart-UI en domeinlaag, aparte native launchers. Android gebruikt Kotlin; iOS/macOS Swift; Windows de Flutter C++ runner. Camera en analyse zijn mobiele services; het fotoarchief en de viewer werken op alle platforms. iOS en macOS builden op macOS, Windows op Windows en Android op een machine met Android SDK.

CI gebruikt debugbuilds en een iOS simulatorbuild. Distributie vereist later signing, bundle identifiers en winkel-/desktopinstallatiepakketten. Controleer eerst de CI: deze projectbasis heeft nog geen volledig uitgevoerde native build gehad.
