#!/bin/bash

# === CONFIGURATION ===
APP_NAME="ezfeed-webapp"
APP_DIR="/opt/ezfeed-webapp"
APP_ENTRY="server.js"
NODE_VERSION="18"
PORT="3000"
ENVIRONMENT="production"
RUN_USER="ezfeed-webapp"
USER_HOME="$APP_DIR/home"
SERVICE_FILE="/etc/systemd/system/$APP_NAME.service"

# === Check for root privileges ===
if [[ "$EUID" -ne 0 ]]; then
  echo "❌ This script must be run as root. Please use sudo:"
  echo "   sudo $0"
  exit 1
fi

# === Create system user with a usable home directory ===
echo "Creating system user: $RUN_USER..."
if id "$RUN_USER" &>/dev/null; then
    echo "User $RUN_USER already exists. Skipping user creation."
else
    useradd --system --shell /usr/sbin/nologin --home "$USER_HOME" "$RUN_USER"
    mkdir -p "$USER_HOME"
    chown -R "$RUN_USER:$RUN_USER" "$USER_HOME"
    echo "User $RUN_USER created with home: $USER_HOME"
fi

# === Install Node.js ===
echo "Installing Node.js v$NODE_VERSION..."
curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash -
apt-get install -y nodejs

# === Copy app files from script location ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "Copying app files from $SCRIPT_DIR to $APP_DIR..."
mkdir -p "$APP_DIR"

# Optionally exclude node_modules from copy if exists
rsync -a --exclude=node_modules "$SCRIPT_DIR/" "$APP_DIR/"
chown -R "$RUN_USER:$RUN_USER" "$APP_DIR"

# Copy .env.example to .env and inject PORT
if [ -f "$APP_DIR/.env.example" ]; then
  echo "Creating .env from .env.example and setting PORT=$PORT..."
  cp "$APP_DIR/.env.example" "$APP_DIR/.env"
  # Use sed to replace the PORT line with the value from script variable
  sed -i "s/^PORT=.*/PORT=$PORT/" "$APP_DIR/.env"
else
  echo "Warning: .env.example not found in $APP_DIR, skipping .env creation."
fi

# === Install npm dependencies with custom HOME ===
echo "Installing dependencies as $RUN_USER with custom HOME..."
sudo -u "$RUN_USER" HOME="$USER_HOME" npm --prefix "$APP_DIR" install "$APP_DIR"

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
Environment=HOME=$USER_HOME

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