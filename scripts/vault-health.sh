#!/bin/bash
HOST="https://obsidian-mcp.merchanalyticspro.com"
AGENT="com.merchanalyticspro.vault-mcp"
UID_=$(id -u)
fail=0

check() {
  if eval "$2" >/dev/null 2>&1; then
    printf "  OK      %s\n" "$1"
  else
    printf "  FEHLER  %s\n          -> %s\n" "$1" "$3"
    fail=1
  fi
}

echo "Vault-Health  $(date '+%F %T')"
echo

check "Obsidian laeuft" \
  "pgrep -x Obsidian" \
  "open -a Obsidian"

check "REST-API auf 27123" \
  "curl -sf -m 5 -o /dev/null http://127.0.0.1:27123/" \
  "Plugin 'Local REST API' in Obsidian aktivieren"

check "LaunchAgent geladen" \
  "launchctl print gui/$UID_/$AGENT" \
  "launchctl bootstrap gui/$UID_ ~/Library/LaunchAgents/$AGENT.plist"

check "MCP-Server auf 8420" \
  "lsof -nP -iTCP:8420 -sTCP:LISTEN" \
  "launchctl kickstart -k gui/$UID_/$AGENT"

check "cloudflared laeuft" \
  "pgrep -f cloudflared" \
  "Tunnel starten (siehe Runbook)"

check "OAuth-Metadaten oeffentlich" \
  "curl -s -m 10 $HOST/.well-known/oauth-protected-resource | grep -q authorization_servers" \
  "Patch in oauth.py pruefen"

check "WWW-Authenticate Header" \
  "curl -s -m 10 -D - -o /dev/null $HOST/mcp | grep -qi '^www-authenticate'" \
  "Patch in auth.py pruefen"

echo
if [ $fail -eq 0 ]; then echo "Kette vollstaendig."; else echo "Mindestens ein Glied defekt."; fi
exit $fail
