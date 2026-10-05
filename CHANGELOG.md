# Changelog

Alle wichtigen Änderungen an PHINANZ, die neuesten zuerst.

## 2.2.0 – 5. Oktober 2026

**Apple Intelligence statt Cloud**

- Sprachnotizen, Belege und PDF-Kontoauszüge liest jetzt Apple Intelligence direkt auf dem iPhone (Foundation-Models-Framework): ohne API-Schlüssel, ohne Kosten, ohne dass Daten das Gerät verlassen
- Spracherkennung auf dem Gerät (Speech), Texterkennung für Belege und gescannte Seiten (Vision), Text aus PDFs (PDFKit); lange Kontoauszüge werden in Teilen gelesen
- Der Monatsrückblick wird auf Deutsch und Englisch von Apple Intelligence formuliert – ebenfalls auf dem iPhone
- Google Gemini bleibt als optionaler Ersatz: für iPhones ohne Apple Intelligence, für Persisch und wenn Apple Intelligence eine Datei nicht lesen kann
- Neue Einstellung „KI-Engine“: Automatisch, Apple Intelligence oder Google Gemini, mit Status der Apple Intelligence auf diesem iPhone
- Die Ladeanimation zeigt, ob gerade das iPhone oder Gemini liest; die Übersicht „Sicherheit & Datenschutz“ zeigt, dass nichts gesendet wird
- 107 automatische Tests

## 2.1.0 – 5. Oktober 2026

**Dein persönlicher Buchhalter**

- **Monatsrückblick:** Beim ersten Öffnen in einem neuen Monat erscheint einmal eine Karte, die den Vormonat in drei bis fünf einfachen Sätzen zusammenfasst: was ausgegeben und eingenommen wurde, der Vergleich zum Vormonat, wohin das meiste Geld ging, was übrig blieb, Budgets und Steuer-Hinweise. Abschaltbar in den Einstellungen
- Der Rückblick wird auf dem iPhone geschrieben. Auf Wunsch formuliert ihn Gemini – mit eigenem Schalter und nur aus den Monatssummen, ohne Händler und einzelne Buchungen. Ohne Internet oder bei Fehlern greift automatisch der Text vom iPhone
- Der Rückblick steht auch oben im Monatsbericht und im PDF
- **Steuer-Hinweise:** Spenden, Fortbildung und Fachbücher, Werbungskosten, Handwerker und Haushaltshilfe, Kinderbetreuung, Versicherungen und Krankheitskosten werden an Stichworten erkannt
- Neuer Schalter „Für meine Steuererklärung“ im Eintrag, um die Erkennung zu überstimmen
- Liste „Für deine Steuererklärung“ im Monatsbericht und im PDF, mit Summe für den Monat und seit 1. Januar
- Neue Spalte „Steuer-Hinweis“ im CSV-Export; Backups behalten die Auswahl
- Überall der klare Hinweis: Hinweise, keine Steuerberatung
- Konto-Auswahl im Eintrag ohne SwiftUI-Warnung
- 99 automatische Tests

## 2.0.0 – 5. Oktober 2026

**Sicherheit**

- Face-ID-Sperre in einem eigenen Fenster über allen Ansichten; Links und Siri-Aktionen warten, bis die App entsperrt ist
- Siri-Aktionen nur bei entsperrtem iPhone; Face ID nötig, um die Sperre auszuschalten oder alle Daten zu löschen
- Datenbank und Exporte mit der Datenschutzklasse von iOS geschützt; temporäre Exporte werden beim Verlassen der App gelöscht
- Backups mit Passwort (PBKDF2-SHA256 und AES-256-GCM)
- Widgets können Beträge ausblenden; Mitteilungen enthalten keine Beträge
- Flüchtige Netzwerksitzung für die KI, Privacy Manifest, neue Seite „Sicherheit & Datenschutz“ und ein Sicherheitskonzept (`docs/SECURITY.md`)

**Neue Funktionen**

- Mehrere Konten (Girokonto, Bargeld, Kreditkarte, Sparkonto) mit Umbuchungen
- Sparziele mit Fortschrittsring und monatlichem Sparvorschlag
- Monatsbericht mit Vergleich zum Vormonat, Erkenntnissen und PDF-Export
- Optionaler Abgleich über iCloud
- Suche: Ein Tipp auf ein Ergebnis blättert das Journal zu diesem Tag und hebt den Eintrag kurz hervor; Bearbeiten per Wischen oder langem Drücken
- Eigene PH-Ladeanimation mit rotierenden Ringen, während Gemini eine Datei liest (bei „Bewegung reduzieren“ steht sie still)

**Verbesserungen**

- Umbenennung des Projekts von „Phbank“ zu „PHINANZ“ (Ordner, Targets, Bundle-IDs, App Group)
- PDF-Bericht passt auf eine A4-Seite, zuverlässigere Ansichten im Tab „Planen“
- Ziffernblock lässt sich durch Wischen schließen
- Robustere Layout-Werte, die SwiftUI-Warnungen vermeiden
- Neue Texte auf Deutsch und Persisch
- 89 automatische Tests

## 1.3.0 – 5. Oktober 2026

- Siri und Kurzbefehle: Ausgabe hinzufügen, heutige und monatliche Ausgaben abfragen, neuer Eintrag (auf Deutsch, Englisch und Persisch)
- Steuerelement für Kontrollzentrum und Aktionstaste, Schnellerfassung aus dem Widget
- Backup und Wiederherstellung
- Tägliche Erinnerung und Hinweis am Vorabend eines Dauerauftrags
- Kategorie-Vorschläge aus dem eigenen Verlauf und bekannten deutschen Händlern
- Tipps mit TipKit, Seitenleiste auf dem iPad, Tab-Leiste verkleinert sich beim Scrollen
- Bank-CSV-Import direkt auf dem iPhone: Sparkasse, ING, DKB, N26, Commerzbank, comdirect, Volksbank, Postbank und andere; Prüfansicht mit Kategorien und Duplikat-Erkennung

## 1.2.0 – 4. Oktober 2026

- Neues Design im Stil von Apple: Tab-Leiste mit Liquid Glass, Wochenleiste wie in der Kalender-App, Systemschriften und -farben
- Helles und dunkles Design
- Neues App-Icon in den Varianten hell, dunkel und getönt

## 1.1.0 – 4. Oktober 2026

- Einnahmen und Kontostand
- Monatsbudgets pro Kategorie
- Daueraufträge, die jeden Monat automatisch gebucht werden
- Onboarding mit Hinweis zum Datenschutz und Startguthaben
- Widget für den Home-Bildschirm
- Deutsche und persische Übersetzung (von rechts nach links)

## 1.0.0 – 4. Oktober 2026

- Neuaufbau der App mit SwiftUI und SwiftData
- Journal mit einer Seite pro Tag und Tagessumme
- KI-Import mit Google Gemini: Sprachnotiz, Beleg und Kontoauszug als PDF, mit Prüfansicht vor dem Speichern
- Face-ID-Sperre
- CSV-Export
- Erste Unit- und UI-Tests

## 0.1.0 – 10. April 2026

- Xcode-Projekt angelegt (damals noch unter dem Namen „Phbank“)
