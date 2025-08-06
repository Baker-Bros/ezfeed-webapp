#!/bin/bash

# === CONFIGURATION ===
APP_NAME="ezfeed-webapp"
APP_DIR="/opt/ezfeed-webapp"
APP_ENTRY="server.js"
NODE_VERSION="18"
PORT="3000"
ENVIRONMENT="production"
RUN_USER="ezfeed-webapp"
SERVICE_FILE="/etc/systemd/system/$APP_NAME.service"

# === Create system user ===
echo "Creating system user: $RUN_USER..."
if id "$RUN_USER" &>/dev/null; then
    echo "User $RUN_USER already exists. Skipping user creation."
else
    sudo useradd --system --no-create-home --shell /usr/sbin/nologin "$RUN_USER"
    echo "User $RUN_USER created."
fi

# === Install Node.js ===
echo "Installing Node.js v$NODE_VERSION..."
curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | sudo -E bash -
sudo apt-get install -y nodejs

# === Set permissions on app directory ===
echo "Setting permissions on $APP_DIR..."
sudo mkdir -p "$APP_DIR"
sudo chown -R "$RUN_USER":"$RUN_USER" "$APP_DIR"

# === Install npm dependencies ===
echo "Installing dependencies..."
cd "$APP_DIR" || { echo "App directory not found: $APP_DIR"; exit 1; }
sudo -u "$RUN_USER" npm install

# === Create systemd service ===
echo "Creating systemd service: $SERVICE_FILE..."

sudo tee "$SERVICE_FILE" > /dev/null <<EOF
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
sudo systemctl daemon-reload
sudo systemctl enable "$APP_NAME"
sudo systemctl restart "$APP_NAME"

# === Done ===
echo "✅ Installation complete."
echo "🔧 To check status: sudo systemctl status $APP_NAME"
echo "📜 To view logs:    journalctl -u $APP_NAME -f"
