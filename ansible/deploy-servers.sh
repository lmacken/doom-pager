#!/bin/bash
# Deploy multiple Chocolate Doom servers
# Usage: ./deploy-servers.sh [server_count] [base_port]

SERVER_COUNT=${1:-4}
BASE_PORT=${2:-2342}
SERVER_HOST="root@64.227.99.100"
DOOM_DIR="/opt/doom"

echo "Deploying $SERVER_COUNT Doom servers (ports $BASE_PORT-$((BASE_PORT + SERVER_COUNT - 1)))..."

# Generate setup script locally
cat > /tmp/doom-setup.sh << SETUP
#!/bin/bash
set -e

SERVER_COUNT=$SERVER_COUNT
BASE_PORT=$BASE_PORT
DOOM_DIR=$DOOM_DIR

# Install dependencies
apt-get update -qq
apt-get install -y -qq chocolate-doom curl

# Create doom user if not exists
id doom &>/dev/null || useradd -r -s /usr/sbin/nologin -d \$DOOM_DIR doom

# Create directories
mkdir -p \$DOOM_DIR/logs
chown -R doom:doom \$DOOM_DIR

# Download WAD if not present
if [ ! -f \$DOOM_DIR/doom1.wad ]; then
    echo "Downloading doom1.wad..."
    curl -sL "https://distro.ibiblio.org/slitaz/sources/packages/d/doom1.wad" -o \$DOOM_DIR/doom1.wad
    chown doom:doom \$DOOM_DIR/doom1.wad
fi

# Stop old single server if exists
systemctl stop doom-server 2>/dev/null || true
systemctl disable doom-server 2>/dev/null || true

# Create server scripts and systemd services
for i in \$(seq 0 \$((SERVER_COUNT - 1))); do
    PORT=\$((BASE_PORT + i))
    NUM=\$((i + 1))
    
    # Create launch script
    cat > \$DOOM_DIR/start-server-\$i.sh << SCRIPT
#!/bin/bash
cd \$DOOM_DIR
exec /usr/games/chocolate-server \\
    -port \$PORT \\
    -servername "Pineapple DOOM \$NUM" \\
    -netlog \$DOOM_DIR/logs/server-\$i.log
SCRIPT
    chmod +x \$DOOM_DIR/start-server-\$i.sh
    chown doom:doom \$DOOM_DIR/start-server-\$i.sh
    
    # Create systemd service
    cat > /etc/systemd/system/doom-server-\$i.service << SERVICE
[Unit]
Description=Chocolate Doom Server \$i (port \$PORT)
After=network.target

[Service]
Type=simple
User=doom
WorkingDirectory=\$DOOM_DIR
ExecStart=\$DOOM_DIR/start-server-\$i.sh
Restart=always
RestartSec=5
StandardOutput=append:\$DOOM_DIR/logs/console-\$i.log
StandardError=append:\$DOOM_DIR/logs/console-\$i.log

[Install]
WantedBy=multi-user.target
SERVICE

    echo "Created doom-server-\$i (port \$PORT)"
done

# Reload systemd and enable services (but don't start)
systemctl daemon-reload
for i in \$(seq 0 \$((SERVER_COUNT - 1))); do
    systemctl enable doom-server-\$i
    systemctl stop doom-server-\$i 2>/dev/null || true
done

# Open firewall ports
for i in \$(seq 0 \$((SERVER_COUNT - 1))); do
    ufw allow \$((BASE_PORT + i))/udp 2>/dev/null || true
done

# Create management script
cat > \$DOOM_DIR/manage.sh << 'MGMT'
#!/bin/bash
# Usage: ./manage.sh [start|stop|status|restart|logs] [N|all]
ACTION=\${1:-status}
TARGET=\${2:-all}

case \$ACTION in
    logs)
        if [ "\$TARGET" = "all" ]; then
            tail -f /opt/doom/logs/console-*.log
        else
            tail -f /opt/doom/logs/console-\$TARGET.log
        fi
        ;;
    *)
        if [ "\$TARGET" = "all" ]; then
            for svc in /etc/systemd/system/doom-server-*.service; do
                name=\$(basename \$svc .service)
                echo "=== \$name ==="
                systemctl \$ACTION \$name
            done
        else
            systemctl \$ACTION doom-server-\$TARGET
        fi
        ;;
esac
MGMT
chmod +x \$DOOM_DIR/manage.sh

echo ""
echo "========================================"
echo "  \$SERVER_COUNT Doom servers deployed!"
echo "========================================"
echo "Ports: \$BASE_PORT - \$((BASE_PORT + SERVER_COUNT - 1))"
echo ""
echo "Start manually:"
echo "  systemctl start doom-server-0"
echo "  systemctl start doom-server-1"
echo "  ..."
echo ""
echo "Or: \$DOOM_DIR/manage.sh start all"
echo "Logs: \$DOOM_DIR/manage.sh logs all"
SETUP

# Copy and run
scp /tmp/doom-setup.sh $SERVER_HOST:/tmp/
ssh $SERVER_HOST "chmod +x /tmp/doom-setup.sh && /tmp/doom-setup.sh"

echo ""
echo "Done! Servers are deployed but NOT started."
echo "SSH to $SERVER_HOST and start them manually."
