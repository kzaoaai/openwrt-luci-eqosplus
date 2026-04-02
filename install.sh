#!/bin/sh

#Command to install
# wget -qO- https://raw.githubusercontent.com/kzaoaai/openwrt-luci-eqosplus/main/install.sh | sh

# GitHub repository details
USER="kzaoaai"
REPO="openwrt-luci-eqosplus"
BRANCH="main"
RAW_URL="https://raw.githubusercontent.com/$USER/$REPO/$BRANCH"
API_URL="https://api.github.com/repos/$USER/$REPO/contents"

echo "🚀 Starting eqosplus native fw4 installation..."

# 1. Detect Package Manager (apk for 25.12+, opkg for older fw4 systems)
if command -v apk >/dev/null 2>&1; then
    PKG_MGR="apk"
    EXT=".apk"
    echo "🔍 Detected OpenWrt 25.12+ (using apk)"
elif command -v opkg >/dev/null 2>&1; then
    PKG_MGR="opkg"
    EXT=".ipk"
    echo "🔍 Detected older OpenWrt (using opkg)"
else
    echo "❌ Error: Neither apk nor opkg found. Aborting."
    exit 1
fi

# 2. Dynamically fetch the latest file name from the GitHub repository
echo "🔎 Searching for the latest $EXT file in the repository..."
# This queries the GitHub API, finds all files matching the extension, sorts them descending, and grabs the top one
FILE_NAME=$(wget -qO- "$API_URL" | grep -o "\"name\": \"[^\"]*${EXT}\"" | awk -F'"' '{print $4}' | sort -r | head -n 1)

if [ -z "$FILE_NAME" ]; then
    echo "❌ Error: Could not find any $EXT file in the $REPO repository."
    exit 1
fi

echo "📄 Found target package: $FILE_NAME"

# 3. Download the files to /tmp
echo "📥 Downloading files to /tmp..."
cd /tmp
wget -q "$RAW_URL/$FILE_NAME" -O "$FILE_NAME"
wget -q "$RAW_URL/eqosplus-engine.sh" -O "eqosplus-engine.sh"

# Check if downloads were successful (files exist and are not empty)
if [ ! -s "$FILE_NAME" ] || [ ! -s "eqosplus-engine.sh" ]; then
    echo "❌ Error: Download failed. Check your internet connection or GitHub repo."
    exit 1
fi

# 4. Install the Package dynamically
echo "📦 Installing LuCI app..."
if [ "$PKG_MGR" = "apk" ]; then
    apk add --allow-untrusted "./$FILE_NAME"
else
    opkg install "./$FILE_NAME"
fi

# 5. Replace the backend engine
echo "🧠 Performing engine transplant..."
[ -f /usr/bin/eqosplus ] && mv /usr/bin/eqosplus /usr/bin/eqosplus.broken
cp /tmp/eqosplus-engine.sh /usr/bin/eqosplus
chmod +x /usr/bin/eqosplus

# 6. Clean up caches and restart services
echo "🧹 Cleaning up and refreshing LuCI..."
rm -rf /tmp/luci-indexcache
rm -f "/tmp/$FILE_NAME"
rm -f /tmp/eqosplus-engine.sh

/etc/init.d/rpcd restart
/etc/init.d/eqosplus enable

# Trigger firewall to ensure our custom hook is loaded immediately
/etc/init.d/firewall restart

echo "✅ Installation Complete!"
echo "Go to Network -> eqosplus in your web browser, add your rules, and click Save & Apply."