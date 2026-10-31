local _, T = ...
if GetLocale() ~= "deDE" then return end
local L = T.L

L["Wherefrom"] = "Wherefrom"

-- Sources
L["An enemy"] = "Ein Gegner"
L["A world object"] = "Ein Objekt in der Welt"
L["Out of %s"] = "Aus %s"
L["Out of a container"] = "Aus einem Behälter"
L["Quest: %s"] = "Quest: %s"
L["A quest reward"] = "Questbelohnung"
L["Bought from %s"] = "Gekauft bei %s"
L["Bought from a vendor"] = "Bei einem Händler gekauft"
L["Mail from %s"] = "Post von %s"
L["Mail"] = "Post"
L["Auction house"] = "Auktionshaus"
L["Crafted: %s"] = "Hergestellt: %s"
L["Crafted"] = "Hergestellt"
L["Traded by %s"] = "Von %s gehandelt"
L["Traded by another player"] = "Von einem Spieler gehandelt"
L["Guild bank of %s"] = "Gildenbank von %s"
L["Guild bank"] = "Gildenbank"
L["Picked up"] = "Aufgesammelt"

-- Tooltip
L["Obtained"] = "Erhalten"
L["Also from"] = "Auch von"
L["Drops from"] = "Droppt von"
L["Source"] = "Quelle"

-- Chat
L["%d items recorded."] = "%d Gegenstände erfasst."
L["No drop index for this build yet - /wf index builds it."] =
    "Für diesen Spielstand gibt es noch keinen Beuteindex – /wf index legt ihn an."
L["Drop index: %d items (build %s)."] = "Beuteindex: %d Gegenstände (Spielstand %s)."
L["Shift-click an item into the command: /wf forget [item]"] =
    "Shift-klick einen Gegenstand in den Befehl: /wf forget [Gegenstand]"
L["Forgot %s."] = "%s vergessen."
L["Nothing recorded for %s."] = "Zu %s ist nichts erfasst."
L["Commands:"] = "Befehle:"
L["This forgets every recorded item. Type /wf reset confirm to go ahead."] =
    "Das vergisst jeden erfassten Gegenstand. Tippe /wf reset confirm, um fortzufahren."
L["Forgot every recorded item."] = "Alle erfassten Gegenstände vergessen."
L["/wf - open the options"] = "/wf – Optionen öffnen"
L["/wf status - what is recorded and indexed"] = "/wf status – was erfasst und indiziert ist"
L["/wf index - rebuild the drop index from the Adventure Guide"] =
    "/wf index – Beuteindex aus dem Abenteuerführer neu aufbauen"
L["/wf forget [item] - drop what is recorded for one item"] =
    "/wf forget [Gegenstand] – Erfassung zu einem Gegenstand löschen"
L["/wf reset confirm - forget every recorded item"] = "/wf reset confirm – alle erfassten Gegenstände vergessen"
L["Indexed %d items from %d encounters."] = "%d Gegenstände aus %d Begegnungen indiziert."
L["Close the Adventure Guide first - the scan uses it."] = "Schließe zuerst den Abenteuerführer – der Scan benutzt ihn."
L["The Adventure Guide is not available in this client."] =
    "Der Abenteuerführer steht in diesem Client nicht zur Verfügung."
L["Indexing %d encounters..."] = "%d Begegnungen werden indiziert …"
L["This client is too old for the tooltip API this addon needs."] =
    "Dieser Client ist zu alt für die Tooltip-Schnittstelle, die das Addon braucht."

-- About
L["Author: %s"] = "Autor: %s"
L["More: %s"] = "Mehr: %s"
L["Contact: %s"] = "Kontakt: %s"
L["Version: %s"] = "Version: %s"
L["Made with"] = "Gemacht mit"
L["in Europe"] = "in Europa"

-- Options
L["Show where you got it"] = "Anzeigen, woher du ihn hast"
L["The source this addon recorded when the item entered your bags."] =
    "Die Quelle, die das Addon erfasst hat, als der Gegenstand in deine Taschen kam."
L["Show which boss drops it"] = "Anzeigen, welcher Boss ihn fallen lässt"
L["Read from the Adventure Guide. Needs the index; rebuild it with /wf index."] =
    "Aus dem Abenteuerführer gelesen. Braucht den Index; /wf index baut ihn neu auf."
L["Show the game's own source text"] = "Den Herkunftstext des Spiels anzeigen"
L["What the client knows for mounts, pets, heirlooms and appearances."] =
    "Was der Client über Reittiere, Haustiere, Erbstücke und Aussehen weiß."
L["Show the date"] = "Datum anzeigen"
L["Show which character got it"] = "Charakter anzeigen, der ihn bekommen hat"
L["Only while holding Shift"] = "Nur bei gedrückter Umschalttaste"
L["Record quest rewards"] = "Questbelohnungen erfassen"
L["Announce every recorded item in chat"] = "Jeden erfassten Gegenstand im Chat melden"
L["Useful for checking what the addon makes of a source. Noisy otherwise."] =
    "Nützlich, um zu prüfen, was das Addon aus einer Quelle macht. Sonst sehr gesprächig."
L["Index every expansion, not just the current one"] = "Alle Erweiterungen indizieren, nicht nur die aktuelle"
L["Much slower and much larger. Takes effect on the next /wf index."] =
    "Deutlich langsamer und deutlich größer. Wirkt beim nächsten /wf index."
