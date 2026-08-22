# Methodik der Partikel-Wetter-Auswertung

## Im Skript umgesetzt

- CPC und SMPS werden vor der Korrelation auf ein gemeinsames Stundenraster gemittelt. Dadurch wird vermieden, dass die 1-Hz-CPC-Reihe allein wegen ihrer viel höheren Abtastrate das Ergebnis dominiert.
- Ausgegeben werden Spearman-Rangkorrelation, p-Wert, FDR-korrigierter q-Wert und Zahl gemeinsamer Beobachtungen. Spearman ist robuster gegen Ausreißer und nichtlineare monotone Beziehungen als Pearson.
- Windrichtung wird nicht als lineare Zahl korreliert: 359 und 1 Grad sind fast identisch, numerisch aber weit auseinander. Deshalb verwendet die Analyse Sinus- und Kosinuskomponenten (`WindFromEast`, `WindFromNorth`).
- Die GUI erlaubt alternativ Pearson, verschiedene Zeitraster und Wetter-Lags. Sie zeigt jeden Zusammenhang einzeln und ein gemeinsames standardisiertes lineares Modell.
- **Pearson** misst, wie gut zwei Größen durch eine Gerade zusammenhängen. Der Koeffizient reicht von -1 bis +1 und reagiert vergleichsweise stark auf Ausreißer.
- **Spearman** berechnet Pearson auf den Rangplätzen der Werte. Er erkennt daher auch nichtlineare, aber durchgehend steigende oder fallende Zusammenhänge und ist robuster gegen Ausreißer.
- Einzelne SMPS-Messkanäle sind bewusst nicht als GUI-Ziel auswählbar. Verglichen werden die integrierte Gesamtzahl und physikalisch interpretierbare Kennwerte der gesamten Größenverteilung.
- Ereignisse bei Wind unter 0,5 m/s werden nicht räumlich interpretiert. Die Karte fasst Ereignisse in 22,5-Grad-Sektoren zusammen.

## Orientierung an Publikationen

1. Harrison et al. (2019), *Atmospheric Chemistry and Physics*, verwenden bivariate Polarplots: Windrichtung bildet den Winkel, Windgeschwindigkeit den Radius und die mittlere Konzentration die Farbe. Ein vom Zentrum entfernter Hotspot kann auf eine gerichtete Quelle hinweisen. <https://doi.org/10.5194/acp-19-4863-2019>
2. Cui et al. (2018) kombinieren Conditional Probability Function (CPF) und bivariate Polarplots. Sie verwenden Konzentrationen oberhalb des 90. Perzentils, 15-Grad-Windsektoren und schließen Wind unter 1 m/s aus. <https://doi.org/10.5194/acp-18-11793-2018>
3. Birmili et al. (2024) gruppieren Partikelanzahlkonzentrationen in 36 Windrichtungssektoren plus Windstille und vergleichen lokale Windmessungen mit Wind am Emissionsort. Das zeigt, dass eine entfernte Station die lokale Strömung nur näherungsweise beschreibt. <https://doi.org/10.5194/acp-24-137-2024>
4. Kozawa et al. untersuchen größenaufgelöste UFP-Konzentrationen nahe Autobahnen. Windrichtung und Temperatur waren wichtige Prädiktoren; das multivariate Modell erreichte R² = 0,46. <https://pubmed.ncbi.nlm.nih.gov/24415904/>
5. Bei weitergehender Quellenanalyse werden häufig PMF-Faktoren, CPF/BPP und Rückwärtstrajektorien wie HYSPLIT kombiniert. Ein Windsektor allein ist daher ein Quellenhinweis, kein Nachweis. Beispiel: <https://doi.org/10.5194/acp-21-14471-2021>

## Grenzen der aktuellen Ergebnisse

- Stündliche Werte sind zeitlich autokorreliert. Die tabellierten klassischen p-Werte können deshalb zu optimistisch sein und sind explorativ zu lesen.
- Viele Partikelgrößen werden gleichzeitig getestet. Der zusätzliche FDR-q-Wert reduziert das Problem multipler Tests, beseitigt aber keine zeitliche Konfundierung.
- Temperatur, Strahlung, Tageszeit und Verkehr folgen ähnlichen Tagesgängen. Eine Korrelation kann dadurch entstehen, ohne dass das Wetter die Partikel direkt verursacht.
- Roma/Ciampino liegt rund 5,9 km vom Partikelmesspunkt entfernt. Lokale Bebauung kann Windrichtung und Windgeschwindigkeit am Messpunkt verändern.
- Für eine belastbarere Quellenzuordnung sollten lokale Windmessungen, Straßen-/Industriequellen, Grenzschichthöhe, NOx/CO/Black Carbon sowie HYSPLIT-Rückwärtstrajektorien ergänzt werden.
- Die ARPA-Reihen stammen nicht exakt vom CPC/SMPS-Punkt. Ciampino ist 7,61 km, Cinecittà 7,95 km entfernt. NO, NO₂, NOx, Benzol und PM₁₀ werden aus Ciampino verwendet; O₃ und PM₂.₅ aus Cinecittà. Gaswerte sind stündlich, PM-Werte Tagesmittel. Diese räumlich und zeitlich unterschiedliche Repräsentativität ist bei Korrelationen zu berücksichtigen.
- Historische CNR-Tor-Vergata-Profildaten sind nicht frei automatisiert herunterladbar. Das DPC-Live-Radar hält nur einen kurzen rückliegenden Zeitraum vor; deshalb werden beide Quellen für die Kampagne derzeit nicht als scheinbar vollständige Datenreihen ausgegeben.

## Datenquellen

- Wetterstation Roma/Ciampino, Meteostat-ID/WMO 16239, METAR/SYNOP-Stundenwerte: <https://meteostat.net/en/station/16239>
- Meteostat-Stundendaten ohne API-Schlüssel: <https://dev.meteostat.net/data/timeseries>
- Solarstrahlung und UV am Messpunkt: Open-Meteo Historical Forecast API, <https://open-meteo.com/en/docs/historical-forecast-api>
- Luftqualität: offizielle ARPA-Lazio-Messnetzdateien für 2026, <https://www.arpalazio.net/main/aria/sci/annoincorso/chimici.php>
- Stationslage und Stationstypen: ARPA Lazio, <https://www.arpalazio.it/ambiente/aria/sistema-di-monitoraggio>
