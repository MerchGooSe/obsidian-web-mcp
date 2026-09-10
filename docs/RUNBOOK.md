# Vault-MCP Runbook

Erste Massnahme bei jedem Ausfall:

    ~/bin/vault-health.sh

Das Skript prueft sieben Glieder und nennt zu jedem Fehler den Reparaturbefehl.

## Die Kette

1. Obsidian (GUI-App, Login-Item)  -> liefert die Daten
2. Local REST API Plugin, Port 27123
3. LaunchAgent com.merchanalyticspro.vault-mcp
4. MCP-Server (uv run vault-mcp), Port 8420
5. cloudflared (LaunchDaemon, /Library/LaunchDaemons/com.cloudflare.cloudflared.plist)
6. OAuth-Metadaten unter /.well-known/oauth-protected-resource
7. WWW-Authenticate-Header auf /mcp

Glied 1 und 2 laufen nur in einer angemeldeten Benutzersitzung.
Glied 5 laeuft als System-Daemon, unabhaengig vom Login.

## Nach einem Neustart

FileVault ist aktiv: die Platte bleibt verschlyesselt, bis sich jemand
am Bildschirm anmeldet. Vorher ist der Rechner im Netz nicht vorhanden.
Bei geplanten Neustarts: `sudo fdesetup authrestart` -- entsperrt genau
einen Bootvorgang, danach kommt die Kette ohne Anmeldung hoch.

## Haeufige Faelle

MCP-Server neu starten:

    launchctl kickstart -k gui/$(id -u)/com.merchanalyticspro.vault-mcp

Agent nicht geladen:

    launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.merchanalyticspro.vault-mcp.plist

Logs:

    tail -50 ~/Library/Logs/vault-mcp-error.log

## Bekannte Fallstricke

Der Prozess laeuft als `uv run vault-mcp` und heisst im Prozessbaum
`python3.1`. `ps aux | grep uvicorn` findet ihn NICHT. Stattdessen:

    lsof -nP -iTCP:8420 -sTCP:LISTEN

Der Upstream liefert keinen /.well-known/oauth-protected-resource-Endpoint
und keinen WWW-Authenticate-Header. Beides ist fuer den OAuth-Flow zwingend.
Fehlt es, koennen sich NEUE Clients nicht anmelden, waehrend bestehende
Sessions mit gueltigem Token weiterlaufen -- das verdeckt den Fehler lange.
Fix: Branch fix/oauth-protected-resource-exempt, Commit d8abefa.

In server.py faengt ein except-Zweig Fehler beim App-Bau ab und startet
den Server dann OHNE Authentifizierung, nur mit einer Warnung im Log.
Bei einem oeffentlichen Tunnel ist das gefaehrlich. Nach Aenderungen an
oauth.py oder auth.py immer Glied 6 und 7 pruefen.

## Nach dem Reparieren

Tool-Listen werden beim Sessionstart festgelegt. Eine laufende Chat-Session
bekommt die Vault-Tools nicht nachtraeglich -- neuen Chat oeffnen.
