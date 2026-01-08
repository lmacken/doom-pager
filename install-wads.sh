#!/bin/bash
# Install custom WADs to the WiFi Pineapple Pager
# Creates a separate payload for each WAD configuration

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WADS_DIR="$SCRIPT_DIR/wads"
PAYLOADS_DIR="$SCRIPT_DIR/payloads/user/games"
PAGER="root@172.16.52.1"
PAGER_DEST="/root/payloads/user/games"

# WAD configurations: name|iwad|pwad|description
# PWADs require an IWAD as base
declare -a WAD_CONFIGS=(
    "doom-registered|DOOM.WAD||DOOM (Episodes 1-3)"
    "doom2|DOOM2.WAD||DOOM II: Hell on Earth"
    "doom2-nerve|DOOM2.WAD|NERVE.WAD|DOOM II: No Rest for the Living"
    "doom-sigil|DOOM.WAD|SIGIL_V1_23.wad|DOOM: SIGIL (Episode 5 by Romero)"
    "doom-sigil-compat|doom1.wad|SIGIL_COMPAT_V1_23.wad|DOOM: SIGIL (Shareware Compatible)"
    "doom-sigil2|DOOM.WAD|SIGIL_II_V1_0.WAD|DOOM: SIGIL II (Episode 6 by Romero)"
)

usage() {
    echo "Usage: $0 [list|install|deploy|clean]"
    echo ""
    echo "Commands:"
    echo "  list    - Show available WAD configurations"
    echo "  install - Create payload directories for available WADs"
    echo "  deploy  - Deploy to Pager (requires SSH access)"
    echo "  clean   - Remove generated WAD payloads"
    echo ""
    echo "WADs should be placed in: $WADS_DIR"
}

# Check if a WAD file exists (case-insensitive)
find_wad() {
    local wad="$1"
    # Try exact match first
    if [ -f "$WADS_DIR/$wad" ]; then
        echo "$WADS_DIR/$wad"
        return 0
    fi
    # Try case-insensitive
    local found=$(find "$WADS_DIR" -maxdepth 1 -iname "$wad" -print -quit 2>/dev/null)
    if [ -n "$found" ]; then
        echo "$found"
        return 0
    fi
    return 1
}

list_configs() {
    echo "=== Available WAD Configurations ==="
    echo ""
    for config in "${WAD_CONFIGS[@]}"; do
        IFS='|' read -r name iwad pwad desc <<< "$config"
        
        # Check if required WADs exist
        iwad_path=$(find_wad "$iwad")
        pwad_path=""
        [ -n "$pwad" ] && pwad_path=$(find_wad "$pwad")
        
        if [ -n "$iwad_path" ]; then
            if [ -z "$pwad" ] || [ -n "$pwad_path" ]; then
                echo "✅ $name"
                echo "   $desc"
                echo "   IWAD: $iwad"
                [ -n "$pwad" ] && echo "   PWAD: $pwad"
            else
                echo "❌ $name (missing PWAD: $pwad)"
            fi
        else
            echo "❌ $name (missing IWAD: $iwad)"
        fi
        echo ""
    done
}

create_payload() {
    local name="$1"
    local iwad="$2"
    local pwad="$3"
    local desc="$4"
    
    local payload_dir="$PAYLOADS_DIR/$name"
    mkdir -p "$payload_dir"
    
    # Find actual WAD paths
    local iwad_path=$(find_wad "$iwad")
    local pwad_path=""
    [ -n "$pwad" ] && pwad_path=$(find_wad "$pwad")
    
    # Copy/link doomgeneric from base doom payload
    if [ -f "$PAYLOADS_DIR/doom/doomgeneric" ]; then
        ln -sf ../doom/doomgeneric "$payload_dir/doomgeneric"
    else
        echo "ERROR: Base doom payload not found. Run build.sh first."
        return 1
    fi
    
    # Copy WAD files
    local iwad_basename=$(basename "$iwad_path")
    cp "$iwad_path" "$payload_dir/$iwad_basename"
    
    local pwad_basename=""
    if [ -n "$pwad_path" ]; then
        pwad_basename=$(basename "$pwad_path")
        cp "$pwad_path" "$payload_dir/$pwad_basename"
    fi
    
    # Generate payload.sh
    cat > "$payload_dir/payload.sh" << PAYLOAD
#!/bin/bash
# Title: $desc
# Description: $desc
# Author: @lmacken
# Version: 1.0
# Category: Games

PAYLOAD_DIR="/root/payloads/user/games/$name"

cd "\$PAYLOAD_DIR" || {
    LOG red "ERROR: \$PAYLOAD_DIR not found"
    exit 1
}

# Verify required files exist
[ ! -f "./doomgeneric" ] && {
    LOG red "ERROR: doomgeneric not found"
    exit 1
}
chmod +x ./doomgeneric

LOG "Starting $desc..."
LOG ""
LOG "Controls:"
LOG "D-pad=Move  Red=Fire"
LOG "Green=Select/Use"
LOG "Red+Green=Quit"
LOG ""
LOG "Press any button..."
WAIT_FOR_INPUT >/dev/null 2>&1

# Stop the Pager UI
/etc/init.d/pineapplepager stop 2>/dev/null
/etc/init.d/pineapd stop 2>/dev/null

sleep 1

# Build command line
DOOM_ARGS="-iwad \"\$PAYLOAD_DIR/$iwad_basename\""
PAYLOAD
    
    # Add PWAD if present
    if [ -n "$pwad_basename" ]; then
        cat >> "$payload_dir/payload.sh" << PAYLOAD
DOOM_ARGS="\$DOOM_ARGS -file \"\$PAYLOAD_DIR/$pwad_basename\""
PAYLOAD
    fi
    
    # Add the rest of the payload
    cat >> "$payload_dir/payload.sh" << 'PAYLOAD'

# Run DOOM!
eval "$PAYLOAD_DIR/doomgeneric $DOOM_ARGS" >/tmp/doom.log 2>&1

# Restore Pager UI
/etc/init.d/pineapplepager start 2>/dev/null &
/etc/init.d/pineapd start 2>/dev/null &

LOG ""
LOG "DOOM exited. Press any button..."
WAIT_FOR_INPUT >/dev/null 2>&1
PAYLOAD
    
    chmod +x "$payload_dir/payload.sh"
    
    # Create checksums
    (cd "$payload_dir" && sha256sum *.wad *.WAD payload.sh 2>/dev/null > SHA256SUMS)
    
    echo "Created: $payload_dir"
}

install_wads() {
    echo "=== Installing WAD Payloads ==="
    echo ""
    
    local installed=0
    for config in "${WAD_CONFIGS[@]}"; do
        IFS='|' read -r name iwad pwad desc <<< "$config"
        
        # Check if required WADs exist
        iwad_path=$(find_wad "$iwad")
        pwad_path=""
        [ -n "$pwad" ] && pwad_path=$(find_wad "$pwad")
        
        if [ -n "$iwad_path" ]; then
            if [ -z "$pwad" ] || [ -n "$pwad_path" ]; then
                create_payload "$name" "$iwad" "$pwad" "$desc"
                ((installed++))
            fi
        fi
    done
    
    echo ""
    echo "Installed $installed WAD payload(s)"
    echo ""
    echo "To deploy to Pager: $0 deploy"
}

deploy_wads() {
    echo "=== Deploying WAD Payloads to Pager ==="
    
    # Test connection
    ssh -o ConnectTimeout=5 "$PAGER" "echo connected" >/dev/null 2>&1 || {
        echo "ERROR: Cannot connect to $PAGER"
        exit 1
    }
    
    for config in "${WAD_CONFIGS[@]}"; do
        IFS='|' read -r name iwad pwad desc <<< "$config"
        local payload_dir="$PAYLOADS_DIR/$name"
        
        if [ -d "$payload_dir" ]; then
            echo "Deploying $name..."
            ssh "$PAGER" "mkdir -p $PAGER_DEST/$name"
            
            # Copy WADs and payload
            scp "$payload_dir"/*.wad "$payload_dir"/*.WAD "$PAGER:$PAGER_DEST/$name/" 2>/dev/null
            scp "$payload_dir/payload.sh" "$payload_dir/SHA256SUMS" "$PAGER:$PAGER_DEST/$name/"
            
            # Symlink doomgeneric from main doom payload (saves ~1.4MB per WAD)
            ssh "$PAGER" "cd $PAGER_DEST/$name && rm -f doomgeneric && ln -s ../doom/doomgeneric . && chmod +x payload.sh"
        fi
    done
    
    echo ""
    echo "Done! New games should appear in Payloads > User > Games"
}

clean_wads() {
    echo "=== Cleaning WAD Payloads ==="
    for config in "${WAD_CONFIGS[@]}"; do
        IFS='|' read -r name iwad pwad desc <<< "$config"
        local payload_dir="$PAYLOADS_DIR/$name"
        if [ -d "$payload_dir" ]; then
            echo "Removing $payload_dir"
            rm -rf "$payload_dir"
        fi
    done
    echo "Done"
}

# Main
case "${1:-list}" in
    list)
        list_configs
        ;;
    install)
        install_wads
        ;;
    deploy)
        deploy_wads
        ;;
    clean)
        clean_wads
        ;;
    *)
        usage
        ;;
esac

