local L = BigWigsAPI:NewLocale("BigWigs: Plugins", "deDE")
if not L then return end

L.abilityName = "Fähigkeitsname"
L.abilityNameDesc = "Zeigt oder versteckt den Fähigkeitsnamen über dem Fenster."
L.Alarm = "Alarm"
L.Alert = "Warnung"
L.align = "Ausrichtung"
L.alignText = "Textausrichtung"
L.alignTime = "Zeitausrichtung"
L.altPowerTitle = "Alternative Energien"
L.Attention = "Achtung"
L.background = "Hintergrund"
L.backgroundDesc = "Zeigt oder versteckt den Hintergrund der Anzeige."
L.bars = "Leisten"
L.bestTimeBar = "Bestzeit"
L.Beware = "Hütet Euch (Algalon)"
L.bigWigsBarStyleName_Default = "Standard"
L.blockEmotes = "Hinweise in der Bildschirmmitte blockieren"
L.blockEmotesDesc = [=[Einige Bosse zeigen sehr lange und ungenaue Hinweise für spezielle Fähigkeiten an. BigWigs versucht kürzere und passendere Mitteilungen zu erstellen, die den Spielfluss weniger beeinflussen.

Hinweis: Bossmitteilungen werden weiterhin im Chat sichtbar sein und können dort gelesen werden.]=]
L.blockGarrison = "Popups der Garnison blockieren"
L.blockGarrisonDesc = [=[Popups der Garnison zeigen hauptsächlich abgeschlossene Missionen von Anhängern an.

Da diese Popups während des Bosskampfes ablenken und das Interface überdecken können, sollten sie blockiert werden.]=]
L.blockGuildChallenge = "Popups von Gildenherausforderungen blockieren"
L.blockGuildChallengeDesc = [=[Popups von Gildenherausforderungen zeigen hauptsächlich den Abschluss eines heroischen Dungeons oder des Herausforderungsmodus an.

Da diese Popups während des Bosskampfes ablenken und das Interface überdecken können, sollten sie blockiert werden.]=]
L.blockMovies = "Wiederholte Filmsequenzen blockieren"
L.blockMoviesDesc = "Filmsequenzen aus Bossbegegnungen werden einmalig wiedergegeben (sodass jede angeschaut werden kann) und danach blockiert."
L.blockSpellErrors = "Hinweise zu fehlgeschlagenen Zaubern blockieren"
L.blockSpellErrorsDesc = "Nachrichten wie \"Fähigkeit noch nicht bereit\", welche normalerweise oben auf dem Bildschirm auftauchen, werden blockiert."
L.bossBlock = "Boss Block"
L.bossBlockDesc = "Legt fest, was während einer Bossbegegnung blockiert wird."
L.bossDefeatDurationPrint = "'%s' wurde nach %s besiegt."
L.bossStatistics = "Boss-Statistiken"
L.bossStatsDescription = "Zeichnet verschiedene Statistiken der Bossbegegnungen wie die Anzahl der Siege und Niederlagen, sowie die Kampfdauer oder die Rekordzeiten auf. Diese Statistiken können, falls vorhanden, in der Konfiguration der einzelnen Bosse eingesehen werden. Andernfalls werden diese ausgeblendet."
L.bossWipeDurationPrint = "An '%s' nach %s gescheitert."
L.breakBar = "Pause"
L.breakFinished = "Die Pause ist vorbei!"
L.breakMinutes = "Pause endet in %d |4Minute:Minuten;!"
L.breakSeconds = "Pause endet in %d |4Sekunde:Sekunden;!"
L.breakStarted = "Pause wurde von %s-Nutzer %s gestartet."
L.breakStopped = "Pause wurde von %s abgebrochen."
L.bwEmphasized = "BigWigs Hervorgehoben"
L.center = "Mittig"
L.chatMessages = "Chatnachrichten"
L.classColors = "Klassenfarben"
L.classColorsDesc = "Färbt Spielernamen nach deren Klasse ein."
L.clickableBars = "Interaktive Leisten"
L.clickableBarsDesc = [=[BigWigs-Leisten sind standardmäßig nicht anklickbar. Dies ermöglicht es, das Ziel zu wechseln, AoE-Zauber zu setzen und die Kameraperspektive zu ändern, während sich die Maus über den Leisten befindet. |cffff4411Die Aktivierung der Interaktiven Leisten verhindert dieses Verhalten.|r Die Leisten werden jeden Mausklick abfangen, oben beschriebene Aktionen können dann nur noch außerhalb der Leistenanzeige ausgeführt werden.
]=]
L.close = "Schließen"
L.closeButton = "Schließen-Button"
L.closeButtonDesc = "Zeigt oder versteckt den Schließen-Button."
L.closeProximityDesc = [=[Schließt die Anzeige naher Spieler.

Falls du die Anzeige für alle Bosse deaktivieren willst, musst du die Option 'Nähe' seperat in den jeweiligen Bossmodulen ausschalten.]=]
L.colors = "Farben"
L.combatLog = "Automatische Kampfaufzeichnung"
L.combatLogDesc = "Startet automatisch die Aufzeichnung des Kampfes, wenn ein Pull-Timer gestartet wurde und beendet die Aufzeichnung, wenn der Bosskampf endet."
L.countDefeats = "Siege zählen"
L.countdownAt = "Countdown ab... (Sekunden)"
L.countdownColor = "Countdown-Farbe"
L.countdownTest = "Countdown testen"
L.countdownType = "Countdowntyp"
L.countdownVoice = "Countdown-Stimme"
L.countWipes = "Niederlagen zählen"
L.createTimeBar = "Bestzeittimer anzeigen"
L.customBarStarted = "Custombar '%s' wurde von gestartet von %s Nutzer %s."
L.customRange = "Eigene Reichweitenanzeige"
L.customSoundDesc = "Den speziell gewählten Sound anstatt des vom Modul bereitgestellten abspielen"
L.defeated = "%s wurde besiegt!"
L.Destruction = "Zerstörung (Kil'jaeden)"
L.disable = "Deaktivieren"
L.disabled = "Deaktivieren"
L.disabledDisplayDesc = "Deaktiviert die Anzeige für alle Module, die sie benutzen."
L.disableDesc = "Deaktiviert die Option, die diese Leiste erzeugt hat, zukünftig permanent."
L.displayTime = "Anzeigedauer"
L.displayTimeDesc = "Bestimmt, wie lange (in Sekunden) Nachrichten angezeigt werden."
L.emphasize = "Hervorheben"
L.emphasizeAt = "Hervorheben bei... (Sekunden)"
L.emphasized = "Hervorgehoben"
L.emphasizedBars = "Hervorgehobene Leisten"
L.emphasizedCountdown = "Hervorgehobener Countdown"
L.emphasizedCountdownSinkDescription = "Sendet Ausgaben dieses Addons durch BigWigs’ Anzeige für hervorgehobene Countdown-Nachrichten. Diese Anzeige unterstützt Text und Farbe und kann nur eine Nachricht gleichzeitig anzeigen."
L.emphasizedMessages = "Hervorgehobene Nachrichten"
L.emphasizedSinkDescription = "Sendet Ausgaben dieses Addons durch BigWigs’ Anzeige für hervorgehobene Nachrichten. Diese Anzeige unterstützt Text und Farbe und kann nur eine Nachricht gleichzeitig anzeigen."
L.enable = "Aktiviert"
L.enableStats = "Statistiken aktivieren"
L.encounterRestricted = "Diese Funktion kann während des Bosskampfes nicht genutzt werden."
L.fadeTime = "Ausblendedauer"
L.fadeTimeDesc = "Bestimmt, wie lange (in Sekunden) das Ausblenden der Nachrichten dauert."
L.fill = "Füllen"
L.fillDesc = "Füllt die Leisten anstatt sie zu entleeren."
L.FlagTaken = "Flagge aufgenommen (PvP)"
L.flash = "Aufleuchten"
L.font = "Schriftart"
L.fontColor = "Schriftfarbe"
L.fontSize = "Schriftgröße"
L.general = "Allgemein"
L.growingUpwards = "Nach oben erweitern"
L.growingUpwardsDesc = "Legt fest, ob die Leisten aufwärts oder abwärts vom Ankerpunkt angezeigt werden."
L.icon = "Symbol"
L.iconDesc = "Zeigt oder versteckt die Symbole auf den Leisten."
L.icons = "Symbole"
L.Important = "Wichtig"
L.Info = "Info"
L.interceptMouseDesc = "Aktiviert die Interaktiven Leisten."
L.left = "Links"
L.localTimer = "Lokal"
L.lock = "Fixieren"
L.lockDesc = "Fixiert die Anzeige und verhindert weiteres Verschieben und Anpassen der Größe."
L.Long = "Lang"
L.messages = "Nachrichten"
L.modifier = "Modifikator"
L.modifierDesc = "Wenn die Modifikatortaste gedrückt gehalten wird, können Klickaktionen auf die Leisten ausgeführt werden."
L.modifierKey = "Nur mit Modifikatortaste"
L.modifierKeyDesc = "Erlaubt nicht-interaktive Leisten solange bis die Modifikatortaste gedrückt gehalten wird und dann die unten aufgeführten Mausaktionen verfügbar werden."
L.monochrome = "Monochrom"
L.monochromeDesc = "Schaltet den Monochrom-Filter an/aus, der die Schriftenkantenglättung entfernt."
L.move = "Bewegen"
L.moveDesc = "Bewegt hervorgehobene Leisten zum hervorgehobenen Anker. Ist diese Option nicht aktiv, werden hervorgehobene Leisten lediglich in Größe und Farbe geändert."
L.movieBlocked = "Da Du diese Zwischensequenz bereits gesehen hast, wird sie übersprungen."
L.Neutral = "Neutral"
L.newBestTime = "Neue Bestzeit!"
L.none = "Nichts"
L.normal = "Normal"
L.normalMessages = "Normale Nachrichten"
L.outline = "Kontur"
L.output = "Ausgabe"
L.Personal = "Persönlich"
L.positionDesc = "Zur exakten Positionierung vom Ankerpunkt einen Wert in der Box eingeben oder den Schieberegler bewegen."
L.positionExact = "Exakte Positionierung"
L.positionX = "X-Position"
L.positionY = "Y-Position"
L.Positive = "Positiv"
L.primary = "Erstes Symbol"
L.primaryDesc = "Das erste Schlachtzugssymbol, das verwendet wird."
L.printBestTimeOption = "Benachrichtigung über Bestzeit"
L.printDefeatOption = "Siegesdauer"
L.printWipeOption = "Niederlagendauer"
L.proximity = "Näheanzeige"
L.proximity_desc = "Zeigt das Fenster für nahe Spieler an. Es listet alle Spieler auf, die dir zu nahe stehen."
L.proximity_name = "Nähe"
L.proximityTitle = "%d m / %d Spieler"
L.pull = "Pull"
L.pullIn = "Pull in %d Sek."
L.pulling = "Pull!"
L.pullStarted = "Pull-Timer wurde von %s-Nutzer %s gestartet."
L.pullStopped = "Pull-Timer von %s abgebrochen."
L.raidIconsDesc = [=[Einige Bossmodule benutzen Schlachtzugssymbole, um Spieler zu markieren, die von speziellem Interesse für deine Gruppe sind. Beispiele wären Bombeneffekte und Gedankenkontrolle. Wenn du diese Option ausschaltest, markierst du niemanden mehr.

|cffff4411Trifft nur zu, sofern du Schlachtzugsleiter oder Assistent bist.|r]=]
L.raidIconsDescription = [=[Einige Begegnungen schließen Elemente wie 'Bombenfähigkeiten' ein, die einen bestimmten Spieler zum Ziel haben, ihn verfolgen oder er ist in sonst einer Art und Weise interessant. Hier kannst du bestimmen, welche Schlachtzugs-Symbole benutzt werden sollen, um die Spieler zu markieren.

Falls nur ein Symbol benötigt wird, wird nur das erste benutzt. Ein Symbol wird niemals für zwei verschiedene Fähigkeiten innerhalb einer Begegnung benutzt.

|cffff4411Beachte, dass ein manuell markierter Spieler von BigWigs nicht ummarkiert wird.|r]=]
L.recordBestTime = "Bestzeiten speichern"
L.regularBars = "Normale Leisten"
L.remove = "Entfernen"
L.removeDesc = "Entfernt zeitweilig die Leiste und alle zugehörigen Nachrichten aus der Anzeige."
L.removeOther = "Andere entfernen"
L.removeOtherDesc = "Entfernt zeitweilig alle anderen Leisten (außer der Angeklickten) und zugehörigen Nachrichten aus der Anzeige."
L.report = "Berichten"
L.reportDesc = "Gibt den aktuellen Leistenstatus im Instanz-, Schlachtzugs-, Gruppen- oder Sagen-Chat aus."
L.requiresLeadOrAssist = "Diese Funktion benötigt Schlachtzugsleiter oder -assistent."
L.reset = "Zurücksetzen"
L.resetAll = "Alle zurücksetzen"
L.resetAllCustomSound = "Wenn Du die Sounds für Bossbegegnungen geändert hast, werden diese ALLE über diese Schaltfläche zurückgesetzt, sodass stattdessen die hier gewählten genutzt werden."
L.resetAllDesc = "Falls du veränderte Farbeinstellungen für Bosse benutzt, wird dieser Button ALLE zurücksetzen, so dass erneut die hier festgelegten Farben verwendet werden."
L.resetDesc = "Setzt die obenstehenden Farben auf ihre Ausgangswerte zurück."
L.respawn = "Erneutes Erscheinen"
L.restart = "Neu starten"
L.restartDesc = "Startet die hervorgehobenen Leisten neu, so dass sie bis 10 hochzählen anstatt von 10 herunter."
L.right = "Rechts"
L.RunAway = "Lauf kleines Mädchen, lauf (Der große böse Wolf)"
L.scale = "Skalierung"
L.secondary = "Zweites Symbol"
L.secondaryDesc = "Das zweite Schlachtzugssymbol, das verwendet wird."
L.sendBreak = "Sende Pausentimer an BigWigs- und DBM-Nutzer."
L.sendCustomBar = "Sende Custombar '%s' an BigWigs- und DBM-Nutzer."
L.sendPull = "Sende Pull-Timer an BigWigs- und DBM-Nutzer."
L.showHide = "Zeigen/Verstecken"
L.showRespawnBar = "Erneutes-Erscheinen-Leiste anzeigen"
L.showRespawnBarDesc = "Zeigt eine Leiste, nachdem ihr an einem Boss gestorben seid, die die Zeit bis zum erneuten Erscheinen des Bosses anzeigt."
L.sinkDescription = "Sendet die BigWigs-Ausgabe durch die normale BigWigs-Nachrichtenanzeige. Diese Anzeige unterstützt Symbole, Farben und kann 4 Nachrichten gleichzeitig anzeigen. Neuere Nachrichten werden größer und schrumpfen dann wieder schnell, um die Aufmerksamkeit dementsprechend zu lenken."
L.sound = "Sound"
L.soundButton = "Sound-Button"
L.soundButtonDesc = "Zeigt oder versteckt den Sound-Button."
L.soundDelay = "Soundverzögerung"
L.soundDelayDesc = "Gibt an, wie lange BigWigs zwischen den Soundwiederholungen wartet, wenn jemand zu nahe steht."
L.soundDesc = "Nachrichten können zusammen mit Sounds erscheinen. Manche Leute finden es einfacher, darauf zu hören, welcher Sound mit welcher Nachricht einher geht, anstatt die Nachricht zu lesen."
L.Sounds = "Sounds"
L.style = "Stil"
L.superEmphasize = "Stark hervorheben"
L.superEmphasizeDesc = [=[Verstärkt zugehörige Nachrichten oder Leisten einer bestimmten Begegnung.

Hier kannst du genau bestimmen, was passieren soll, wenn du in den erweiterten Optionen einer Bossfähigkeit 'Stark hervorheben' aktivierst.

|cffff4411Beachte, dass 'Stark hervorheben' standardmäßig für alle Fähigkeiten deaktiviert ist.|r
]=]
L.superEmphasizeDisableDesc = "Deaktiviert starkes Hervorheben für alle Module, die es benutzen."
L.tempEmphasize = "Hebt zeitweilig Leisten und zugehörige Nachrichten stark hervor."
L.text = "Text"
L.textCountdown = "Countdown-Text"
L.textCountdownDesc = "Zeige einen sichtbaren Zähler während eines Countdowns."
L.textShadow = "Textschatten"
L.texture = "Textur"
L.thick = "Dick"
L.thin = "Dünn"
L.time = "Zeit"
L.timeDesc = "Bestimmt, ob die verbleibende Zeit auf den Leisten angezeigt wird."
L.timerFinished = "%s: Timer [%s] beendet."
L.title = "Titel"
L.titleDesc = "Zeigt oder versteckt den Titel der Anzeige."
L.toggleDisplayPrint = "Die Anzeige wird das nächste Mal wieder erscheinen. Um sie für diesen Bosskampf komplett zu deaktivieren, musst Du sie in den Bosskampf-Optionen ausschalten."
L.toggleSound = "Sound an/aus"
L.toggleSoundDesc = "Schaltet den Sound ein oder aus, der gespielt wird, wenn du zu nahe an einem anderen Spieler stehst."
L.tooltip = "Tooltip"
L.tooltipDesc = "Zeigt oder versteckt den Zaubertooltip, wenn die Näheanzeige direkt an eine Bossfähigkeit gebunden ist."
L.uppercase = "GROSSBUCHSTABEN"
L.uppercaseDesc = "Schreibt alle Nachrichten in Großbuchstaben, die die zugehörige Option 'Stark hervorheben' aktiviert haben."
L.Urgent = "Dringend"
L.useColors = "Farben verwenden"
L.useColorsDesc = "Wählt, ob Nachrichten farbig oder weiß angezeigt werden."
L.useIcons = "Symbole verwenden"
L.useIconsDesc = "Zeigt Symbole neben Nachrichten an."
L.Victory = "Sieg"
L.victoryHeader = "Konfiguriert die Aktionen, die nach einem erfolgreichen Bosskampf stattfinden."
L.victoryMessageBigWigs = "Die Mitteilung von BigWigs anzeigen"
L.victoryMessageBigWigsDesc = "Die Mitteilung von BigWigs ist eine einfache Boss-wurde-besiegt-Mitteilung."
L.victoryMessageBlizzard = "Die Blizzard-Mitteilung anzeigen"
L.victoryMessageBlizzardDesc = "Die Blizzard-Mitteilung ist eine sehr große Boss-wurde-besiegt-Animation in der Mitte deines Bildschirms."
L.victoryMessages = "Boss-besiegt-Nachrichten zeigen"
L.victorySound = "Spiele einen Sieg-Sound"
L.Warning = "Warnung"
L.wrongBreakFormat = "Muss zwischen 1 und 60 Minuten liegen. Beispiel: /break 5"
L.wrongCustomBarFormat = "Ungültiges Format. Beispiel: /raidbar 20 text"
L.wrongPullFormat = "Muss zwischen 1 und 60 Sekunden liegen. Beispiel: /pull 5"
L.wrongTime = "Ungültige Zeitangabe. <time> kann eine Zahl in Sekunden, ein M:S paarung, oder Mm sein. Beispiel: 5, 1:20 or 2m."

-----------------------------------------------------------------------
-- InfoBox.lua
--

--L.infoBox = "InfoBox"
