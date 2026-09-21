## RexUI Eternal 1.4

**UnitFrames**
- Der PlayerFrame wiederholt seinen vorhandenen Layout-Refresh beim Cold Start einmalig, nachdem die Spielerdaten verfügbar sind.
- Der bestehende 3D-Portrait-Cold-Start-Fix bleibt unverändert erhalten.

---

## RexUI Eternal 1.3

**Taschen**
- Das gemeinsame Raster zeigt nur noch Rucksack und die vier ausgerüsteten Taschen.
- Oben steht die echte freie Taschenplatz-Anzeige (`Frei: X / Y`).
- Schlüsselbund- und Reagenzplätze zählen nicht mehr als Taschenplatz.
- Der Schlüsselbund-Mouseover in der Welt ist ausgeblendet.

---

## RexUI Eternal 1.2

**Profile**
- Profile bleiben nach `/reload` und Charakterwechsel erhalten.
- Nach einem kompletten Client-Neustart Profil bitte erneut importieren.
- Alle Config-Einstellungen des Profils werden exportiert, einschließlich der Erfahrungsleiste (an/aus).

**ActionBars**
- Gestaltwechsel im Kampf wechselt Bar 1 wieder mit (z. B. Normalform auf Bär).
- Zauber auf Bar 1–8 lassen sich wieder per Klick und Tastaturbelegung nutzen.
- Zauber lassen sich wieder von Bar 1–8 ziehen. Bei gesperrter Leiste: Shift+Ziehen.
- Erfahrungs- und Rufleiste liegen unter ActionBars bei **XPBar und Ruf**.
- Tastenbelegung sitzt unter Raster anzeigen.

**Namensplaketten**
- Kurz vor dem Tod (~0,1 % Leben) hängt das Bild nicht mehr.
- Level steht rechts neben der Leiste.
- Zielpfeile sitzen wieder nah an der Plakette.
- Rare- und Elite-Erkennung funktioniert wieder (auch wenn die Client-Daten geschützt sind).
- Secret-Aggro-Werte lösen keinen Lua-Fehler mehr am Plakettenrand aus.

---

## RexUI Eternal 1.1

**ActionBars**
- Gestaltwechsel im Kampf wechselt Bar 1 wieder mit (z. B. Normalform auf Bär).
- Zauber auf Bar 1–8 lassen sich wieder per Klick und Tastaturbelegung nutzen.
- Zauber lassen sich wieder von Bar 1–8 ziehen. Bei gesperrter Leiste: Shift+Ziehen.

**Namensplaketten**
- Kurz vor dem Tod (~0,1 % Leben) hängt das Bild nicht mehr. Threat-Updates legen die Plakette nicht mehr jedes Tick neu, Absorb hängt nicht mehr an der Health-Fill-Kante.

---

## RexUI Eternal 4.6.6

**Profile**
- Ein fremdes Profil aktivieren übernimmt das gespeicherte ActionBar-Layout dieses Profils, nicht den Spec-Rest des eingeloggten Charakters.

**ActionBars**
- Forever: Spells ohne Wut, Energie oder Mana werden wieder grau dargestellt.
- Forever: Spell-Flyouts öffnen über Blizzards SpellFlyout. LAB kompiliert keine `newtable()`-Snippets mehr (`RestrictedExecution.lua:79`).

---

## RexUI 4.6.5

**Namensplaketten**
- Execute-Glow und Execute-Linie gelten für alle Spezialisierungen und bleiben in Instanzen sichtbar.
- Innere `RexUI_Nameplates.zip` entfernt.
- Lebenspunkteformat auswählbar: Prozent, kompakt oder beide Reihenfolgen.
- Geschützte Kampfwerte werden sicher als Lebenspunkte und Prozent angezeigt.
- Blizzard-Aura-Container und Zielpfeile verwenden das geschützte Layoutverfahren.
- Roter Aggro-Rand unterstützt geschützte Bedrohungswerte.
- Auswahl zwischen einfachen und doppelten Zielpfeilen.
- Doppelte Medien entfernt; Nameplate-Grafiken werden zentral geladen.

**Einstellungen**
- Tabs „Darstellung“ sowie „Ziel & Bedrohung“ vollständig neu und ohne überlappende Bedienelemente ausgerichtet.

---

## RexUI 4.6

**Stabilität & Performance**
- Einheitlicher Modul-Lebenszyklus: Deaktivierte Module (Buff-Erinnerungen, Cooldown-Manager, Schadensmeter, Gildenschlüssel, M+ Timer, Blizzard-Skin) melden alle Events und Ticker ab. Der CDM-Skin wird beim Abschalten wieder entfernt.
- /rexperf liefert echte Messwerte aus ActionBars, Namensplaketten, Schadensmeter, Gruppenframes, Minimap und Buff-Erinnerungen.

**Namensplaketten**
- Core in zehn Dateien zerlegt, Standardwerte ausschließlich aus dem Datenbankschema.
- Delta-Verarbeitung für UNIT_AURA, einstellbare Aura-Maximalzahlen, Rahmen nach Bannbarkeit, Cast-Spark, Execute-Linie.
- Freundliche Spieler/NPCs getrennt (nur Name, Klassenfarben, Click-through, Y-Versatz), Fokus-Größe/-Rahmen, Mouseover-Hervorhebung.

**ActionBars**
- Freie Sichtbarkeits- und Paging-Bedingungen mit Syntaxprüfung, neue Presets, Paging pro Spezialisierung.
- Buttonbreite/-höhe, Wachstumsrichtung, Frame-Level, Click-through, leere Buttons, Text-Layer (Hotkey/Stapel/Makro), Benutzbarkeitsfarben, Global-Fade-Bedingungen und Verzögerung.
- Layout-Presets, Rückgängig, einfache/erweiterte Ansicht; Kopieren übernimmt Standardwerte.

**Neu**
- Teilprofile: Export/Import einzelner Abschnitte.
- Installationsassistent (Rolle, Layout, Spieleinstellungen) beim ersten Start und per /rexui install.
- Minimap-Datenleiste: drei frei wählbare Slots direkt unter der Minimap.

**Weiteres**
- Profile: aktives Profil zuerst, danach alphabetisch; einheitliche Zeilen und Spalten.
- Startbild: externe Addon- und Helper-Empfehlungen entfernt.
- Installationsassistent: Auswahl wird beim Abschluss sicher angewendet; Startbild vollständig und proportional dargestellt.
- ActionBars: Pet-Fähigkeiten auf Bar 1–8 bleiben beim Kampfbeginn korrekt hell und benutzbar; Ersatzzauber und direkte WoW-Statusmeldungen werden berücksichtigt.
- PetBar: Fähigkeiten wie Spott werden wieder dem richtigen Pet-Slot zugeordnet und pro Klick nur einmal ausgelöst. Aktivierter Autocast ist jetzt durch den animierten Rahmen deutlich erkennbar.
- ActionBars reagieren standardmäßig direkt beim Drücken; im Editor global umschaltbar.
- Fehler im Schadensmeter-Profilwechsel behoben, der einen Stack Overflow auslösen konnte.
- Fehler in den erweiterten ActionBar-Einstellungen behoben; die Auswahl ist wieder ohne Lua-Fehler möglich.
- Datenpanels auf die Leiste unter der Minimap mit drei einstellbaren Slots vereinfacht.
- Rund 130 fehlende englische Übersetzungen ergänzt.
- License files for all embedded libraries plus LICENSES.md included; UTF-8 BOMs removed.

---

## RexUI 4.5.5

**Buff-Erinnerungen**
- Flask- und Essen-Erkennung auf Midnight (12.x) aktualisiert. Die Anzeige bleibt nicht mehr dauerhaft stehen, obwohl Flask und Essen aktiv sind.
- Essen wird zusätzlich über den Aura-Namen („Gut gesättigt“ / „Herzhaft gesättigt“) erkannt, damit auch neue Gerichte ohne Datenupdate zählen.
- Klassenbuffs (Mal der Wildnis, Arkane Intelligenz, Machtwort: Seelenstärke, Schlachtruf, Himmelszorn) werden wieder gemeldet, sobald eine passende Klasse in der Gruppe ist.
- Neu: Waffenöl-Erinnerung. Meldet fehlende temporäre Waffenverzauberungen auf der Waffenhand und, bei zwei Waffen, auch auf der Schildhand.
- Neue Schalter für Flask, Essen, Klassenbuffs und Waffenöl unter Komfort → Kampf-Tools. Die Anzeige passt ihre Breite an die Textlänge an.
- Kampf-Fehlanzeige behoben: In Midnight sind Aura-Daten im Kampf, in Encountern, M+ und PvP geheim. Unbekannte Werte werden nicht mehr als „fehlt“ gemeldet; die Anzeige behält den letzten bekannten Zustand von vor dem Kampf.
- Mover: Beim Entsperren der UI lässt sich das Erinnerungsfenster frei verschieben (mit Beispieltext). Die Position wird im Profil gespeichert.

**Entfernt**
- Resource Bar: Die zentrale Ressourcenleiste ist über die Unitframes abgedeckt. Modul, Schalter und gespeicherte Einstellungen wurden entfernt.

---

## RexUI 4.5.5 (English)

**Buff Reminders**
- Flask and food detection updated for Midnight (12.x). The reminder no longer stays visible while flask and food are active.
- Food is also detected by aura name ("Well Fed" / "Hearty Well Fed"), so new dishes count without a data update.
- Class buffs (Mark of the Wild, Arcane Intellect, Power Word: Fortitude, Battle Shout, Skyfury) are reported again whenever a matching class is in the group.
- New: weapon oil reminder. Reports missing temporary weapon enchants on the main hand and, when dual wielding, on the off hand.
- New toggles for flask, food, class buffs, and weapon oil under Comfort → Combat Tools. The reminder resizes to fit its text.
- Fixed false "missing" display in combat: in Midnight, aura data is secret during combat, encounters, M+, and PvP. Unknown values are no longer reported as missing; the reminder keeps the last known pre-combat state.
- Mover: with the UI unlocked, the reminder window can be dragged freely (shows sample text). The position is saved in the profile.

**Removed**
- Resource Bar: covered by the unit frames. Module, toggle, and saved settings were removed.
