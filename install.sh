#!/bin/zsh
# Build mousekeys, install it to ~/.local/bin and (re)start it as a login agent.
# Each rebuild changes the binary's signature: remove and re-add mousekeys under
# System Settings > Privacy & Security > Accessibility afterwards.
set -e
cd "$(dirname "$0")"
LABEL=local.mousekeys
BIN="$HOME/.local/bin/mousekeys"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

swiftc -O main.swift -o mousekeys
codesign -s - -f -i $LABEL mousekeys

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
mkdir -p "$(dirname "$BIN")"
rm -f "$BIN"
cp mousekeys "$BIN"

cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key><array><string>$BIN</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>ProcessType</key><string>Interactive</string>
  <key>StandardOutPath</key><string>/tmp/mousekeys.log</string>
  <key>StandardErrorPath</key><string>/tmp/mousekeys.log</string>
</dict>
</plist>
EOF

launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "mousekeys running (log: /tmp/mousekeys.log)"
