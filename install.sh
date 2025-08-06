#!/bin/bash

# === CONFIGURATION ===
APP_NAME="ezfeed-webapp"
APP_DIR="/opt/ezfeed-webapp"
APP_ENTRY="server.js"
NODE_VERSION="18"
PORT="80"
ENVIRONMENT="production"
RUN_USER="ezfeed-webapp"
SERVICE_FILE="/etc/systemd/system/$APP_NAME.service"

# === Check for root privileges ===
if [[ "$EUID" -ne 0 ]]; then
  echo "❌ This script must be run as root. Please use sudo:"
  echo "   sudo $0"
  exit 1
fi

# === Create system user ===
echo "Creating system user: $RUN_USER..."
if id "$RUN_USER" &>/dev/null; then
    echo "User $RUN_USER already exists. Skipping user creation."
else
    useradd --system --no-create-home --shell /usr/sbin/nologin "$RUN_USER"
    echo "User $RUN_USER created."
fi

# === Install Node.js ===
echo "Installing Node.js v$NODE_VERSION..."
curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash -
apt-get install -y nodejs

# === Copy app files ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "Copying app files from $SCRIPT_DIR to $APP_DIR..."
mkdir -p "$APP_DIR"
cp -r "$SCRIPT_DIR/"* "$APP_DIR"
chown -R "$RUN_USER:$RUN_USER" "$APP_DIR"

# === Install npm dependencies ===
echo "Installing dependencies..."
cd "$APP_DIR" || { echo "App directory not found: $APP_DIR"; exit 1; }
sudo -u "$RUN_USER" npm install

# === Create systemd service ===
echo "Creating systemd service: $SERVICE_FILE..."

cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Node.js App: $APP_NAME
After=network.target

[Service]
ExecStart=$(which node) $APP_DIR/$APP_ENTRY
WorkingDirectory=$APP_DIR
Restart=always
User=$RUN_USER
Group=$RUN_USER
Environment=PORT=$PORT
Environment=NODE_ENV=$ENVIRONMENT

[Install]
WantedBy=multi-user.target
EOF

# === Reload systemd and enable the service ===
echo "Reloading systemd, enabling and starting service..."
systemctl daemon-reload
systemctl enable "$APP_NAME"
systemctl restart "$APP_NAME"

# === Done ===
echo "✅ Installation complete."
echo "🔧 To check status: sudo systemctl status $APP_NAME"
echo "📜 To view logs:    journalctl -u $APP_NAME -f"
