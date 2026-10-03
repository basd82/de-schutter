# Vervolg

1. Houd `pubspec.lock` en de CI voor analyse, tests en alle vier native builds bij. Test lokale opslag, cameratoestemming, fotoherstel en het wijzigen van scores op echte apparaten.
2. Voeg wedstrijd/plaats/baan, bewerkbare metadata, meerdere schutters, wedstrijdspecifieke scoreprofielen en een leesmodus toe. Maak een print/PDF-scorekaart op basis van het voorbeeldformulier, met eigen vormgeving.
3. Bouw een kalibratiescherm met handmatige centrum/ringen/inslagen. Bevestig scoreberekening met expliciete blazoenprofielen en geometrische grensgevallen vóór automatische detectie.
4. Annoteer de voorbeeldfoto's zonder duplicaten: gekozen doel, ringen, huidige pijlen en zichtbare inslagen. Laat een schutter de echte scores ter plekke beoordelen; raad geen lijnscores vanaf foto's.
5. Prototype lokale targetdetectie en perspectiefcorrectie. Meet fouten en tijden. Volg daarna schachten/inslagen en onderzoek waar een klein model nodig is.
6. Bouw de review-interface voor voorstellen en ontbrekende/extra pijlen. Test dat elke handmatige correctie ook na heranalyse behouden blijft.
7. Voeg optionele accounts, server-synchronisatie en expliciete fotoback-up toe met conflictafhandeling.
8. Test toegankelijkheid, touchscreen/schermformaten en toetsenbord; maak getekende installatiepakketten en winkelreleases.
