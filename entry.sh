#!/bin/bash
set -e

echo "[entry] Running as root. Setup starting..."

# 1. Force scripts to be executable
chmod +x /pre.sh
chmod +x /home/steam/entry.sh

# 2. UPDATE CS2
echo "[entry] Checking for CS2 updates..."
su steam -c "/home/steam/steamcmd/steamcmd.sh \
    +force_install_dir /home/steam/cs2-dedicated \
    +login anonymous \
    +app_update 730 \
    +quit"

# 3. RUN SEED SCRIPT
if [ -f "/pre.sh" ]; then
    echo "[entry] Running pre-script..."
    /pre.sh
fi

# 4. FIX PERMISSIONS & STEAMCLIENT
echo "[entry] Fixing permissions and SteamClient..."
chown -R steam:steam /home/steam/cs2-dedicated
chown -R steam:steam /home/steam/steamcmd
mkdir -p /home/steam/.steam/sdk64
STEAMCLIENT_PATH=$(find /home/steam -name steamclient.so | grep linux64 | head -n 1)
if [ -n "$STEAMCLIENT_PATH" ]; then
    cp "$STEAMCLIENT_PATH" /home/steam/.steam/sdk64/steamclient.so
fi
chown -R steam:steam /home/steam/.steam

# 5. PATCH GAMEINFO (Metamod Core)
GAMEINFO="/home/steam/cs2-dedicated/game/csgo/gameinfo.gi"
if [ -f "$GAMEINFO" ]; then
    if grep -q "csgo/addons/metamod" "$GAMEINFO"; then
        echo "[entry] Metamod already registered in gameinfo.gi."
    else
        echo "[entry] Patching gameinfo.gi for Metamod..."
        sed -i '/SearchPaths/a \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ Game\tcsgo/addons/metamod' "$GAMEINFO"
    fi
fi

# 5b. FORCE LOAD PLUGINS (Fixes 'Loaded 0 plugins')
# Wir erstellen/überschreiben die metaplugins.ini, um CSS explizit zu laden.
METAMOD_DIR="/home/steam/cs2-dedicated/game/csgo/addons/metamod"
echo "[entry] Configuring metaplugins.ini..."
mkdir -p "$METAMOD_DIR"
# Hinweis: Pfad ist relativ zum game Verzeichnis oder absolut. Wir nutzen den Pfad relativ zu addons.
# Metamod erwartet: addons/counterstrikesharp/bin/linuxsteamrt64/counterstrikesharp
echo "addons/counterstrikesharp/bin/linuxsteamrt64/counterstrikesharp" > "$METAMOD_DIR/metaplugins.ini"
chown steam:steam "$METAMOD_DIR/metaplugins.ini"
echo "[entry] metaplugins.ini created. CSS forced."

# 6. START SERVER
echo "[entry] Starting CS2 server..."
cd "/home/steam/cs2-dedicated/game/bin/linuxsteamrt64"

# LD_LIBRARY_PATH ensures libraries are found
su steam -c "export LD_LIBRARY_PATH=.:/home/steam/.steam/sdk64 && ./cs2 -dedicated \
    -usercon \
    -console \
    -port 27015 \
    +game_type 0 \
    +game_mode 1 \
    +map de_mirage \
    +sv_setsteamaccount $SRCDS_TOKEN \
    +exec server.cfg \
    $*"
