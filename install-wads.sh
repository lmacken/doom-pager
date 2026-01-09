#!/bin/bash
# Install custom WADs to the WiFi Pineapple Pager
# Creates a separate payload for each WAD configuration
#
# Usage:
#   ./install-wads.sh [list|install|deploy|clean|identify]
#
# Place WAD files in the wads/ directory, then run:
#   ./install-wads.sh install
#   ./install-wads.sh deploy

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WADS_DIR="$SCRIPT_DIR/wads"
PAYLOADS_DIR="$SCRIPT_DIR/payloads/user/games"
PAGER="root@172.16.52.1"
PAGER_DEST="/root/payloads/user/games"

# ============================================================================
# Known WAD SHA256 checksums for identification
# Format: checksum -> "filename|type|game|edition|version|description"
# ============================================================================
declare -A WAD_DATABASE=(
    # DOOM 1 Shareware (multiple versions)
    ["1d7d43be501e67d927e415e0b8f3e29c3bf33075e859721816f652a526cac771"]="doom1.wad|IWAD|doom|shareware|1.9|DOOM Shareware v1.9"
    ["81e4c66a61893e9f1eecf6b7a51c9a04b78b27b36f6e8f3a51d0c8a0b27d5b7e"]="doom1.wad|IWAD|doom|shareware|1.8|DOOM Shareware v1.8"
    
    # The Ultimate DOOM (v1.9ud)
    ["9b07b02ab3c275a6a7570c3f73cc20d63a0e3833c409c6f8b4edae4f5af78bf0"]="doom.wad|IWAD|doom|ultimate|1.9ud|The Ultimate DOOM v1.9ud"
    
    # DOOM Registered v1.9
    ["af5aa9b40a3fbde9d8df1a6e5dbcca96e98c5b095e726f4ba3e2c4cd7c8f3c9c"]="doom.wad|IWAD|doom|registered|1.9|DOOM Registered v1.9"
    
    # DOOM BFG/Unity Edition
    ["03103e82064a960b548a98eb9656f1f30545458eb437d99475a962053b1f8fcd"]="doom.wad|IWAD|doom|bfg|BFG|DOOM (BFG/Unity Edition)"
    
    # DOOM II v1.9
    ["c3bea40570c23e511a7ed3ebcd9865f0eb91f6dbc8d7b0df57c25bdeea35c694"]="doom2.wad|IWAD|doom2|commercial|1.9|DOOM II: Hell on Earth v1.9"
    
    # DOOM II BFG/Unity Edition
    ["31740ef23994b3959800134b41aaf86b04a2847336d328af8c4ae890450630ab"]="doom2.wad|IWAD|doom2|bfg|BFG|DOOM II (BFG/Unity Edition)"
    
    # Final DOOM: TNT Evilution (Unity/modern)
    ["83c9457676380b2366e7a9f25c728a63c0688389fc3d98e8182ddfa695bb20d8"]="tnt.wad|IWAD|tnt|commercial|Unity|Final DOOM: TNT Evilution"
    ["2e9e92a07e8e50290b2dc2be5bdd45963c94d8cc3c62d0eb2a2e8e4da5e7f2dd"]="tnt.wad|IWAD|tnt|commercial|1.9|Final DOOM: TNT Evilution v1.9"
    
    # Final DOOM: Plutonia Experiment (Unity/modern)
    ["ff2bf34e2f2ec2a85e151bce0575ecb4146082b23ee6f872943aecd517a39c5a"]="plutonia.wad|IWAD|plutonia|commercial|Unity|Final DOOM: Plutonia Experiment"
    ["e37af9b41a0c87caa1e43c8ad23ad6a748ad4e4c7492f5cd30b15ebab83c26a4"]="plutonia.wad|IWAD|plutonia|commercial|1.9|Final DOOM: Plutonia Experiment v1.9"
    
    # NERVE.WAD (No Rest for the Living - BFG Edition bonus)
    ["e2eb4bd5b0e8252fa1198b2c34b5da7602015e2fe5d702a91209bc11d1fbb9f8"]="nerve.wad|PWAD|doom2|addon|1.0|No Rest for the Living"
    
    # Master Levels for DOOM II
    ["3e42d71e316a3e3e53d47860509998d63a0758eafd846171c77f218b0043eaef"]="masterlevels.wad|PWAD|doom2|addon|1.0|Master Levels for DOOM II"
    
    # SIGIL v1.21 (multiple releases)
    ["ddc7fc24ee98b4ea1c1c24e73bd4a8a752c17bf3c19c3bfd8a18e0a5f1d0c3aa"]="sigil.wad|PWAD|doom|addon|1.21|SIGIL v1.21 by John Romero"
    ["5c58e6e024d6dd408a4b6e886340a2759283f218984b7527749a6b52788d77e8"]="sigil.wad|PWAD|doom|addon|1.23|SIGIL v1.23 by John Romero"
    
    # SIGIL Compat (Shareware compatible)
    ["c64c059a79e2ec68ab9ca0d5ae5ef7ef0eaba0e5c6adbef8b2ce91f05ee09f33"]="sigil_compat.wad|PWAD|doom|addon|1.21|SIGIL Compat v1.21 (Shareware)"
    
    # SIGIL II v1.0 - NOT COMPATIBLE with doomgeneric (Episode 6 music lumps crash)
    # ["ab75c9352d1ae8fedb581014ec47eb09c28933a6a66e367424dff8ee2810e825"]="sigil2.wad|PWAD|doom|addon|1.0|SIGIL II v1.0 by John Romero"
)

# ============================================================================
# WAD payload configurations
# Format: payload_name|iwad_pattern|pwad_pattern|title|description
# ============================================================================
declare -a WAD_CONFIGS=(
    # Base games (IWADs only)
    # Note: doom-shareware skipped - base "doom" payload already has doom1.wad
    "doom-registered|doom.wad||Ultimate DOOM|The Ultimate DOOM (Episodes 1-4)"
    "doom2|doom2.wad||DOOM II|DOOM II: Hell on Earth"
    "doom-tnt|tnt.wad||TNT: Evilution|Final DOOM: TNT Evilution"
    "doom-plutonia|plutonia.wad||Plutonia|Final DOOM: Plutonia Experiment"
    
    # Add-ons (IWAD + PWAD)
    "doom2-nerve|doom2.wad|nerve.wad|No Rest for the Living|No Rest for the Living (DOOM II expansion)"
    "doom2-master|doom2.wad|masterlevels.wad|Master Levels|Master Levels for DOOM II"
    "doom-sigil|doom.wad|sigil.wad|SIGIL|SIGIL by John Romero (select Episode 3)"
    # Note: SIGIL II is not compatible with doomgeneric (crashes on Episode 6 music lumps)
)

# ============================================================================
# Helper Functions
# ============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}ℹ${NC} $1"; }
log_ok() { echo -e "${GREEN}✓${NC} $1"; }
log_warn() { echo -e "${YELLOW}⚠${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; }

# Get SHA256 of a file
get_sha256() {
    sha256sum "$1" 2>/dev/null | cut -d' ' -f1
}

# Find WAD file (case-insensitive)
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

# Identify a WAD file by its checksum
identify_wad() {
    local wad_path="$1"
    local sha256=$(get_sha256 "$wad_path")
    
    if [ -n "${WAD_DATABASE[$sha256]:-}" ]; then
        echo "${WAD_DATABASE[$sha256]}"
        return 0
    fi
    
    # Unknown WAD - return basic info from filename
    local basename=$(basename "$wad_path")
    echo "$basename|UNKNOWN|unknown|unknown|unknown|Unknown WAD file"
    return 1
}

# Parse WAD info string
parse_wad_info() {
    local info="$1"
    local field="$2"
    
    case "$field" in
        filename) echo "$info" | cut -d'|' -f1 ;;
        type)     echo "$info" | cut -d'|' -f2 ;;
        game)     echo "$info" | cut -d'|' -f3 ;;
        edition)  echo "$info" | cut -d'|' -f4 ;;
        version)  echo "$info" | cut -d'|' -f5 ;;
        desc)     echo "$info" | cut -d'|' -f6 ;;
    esac
}

# Format file size
format_size() {
    local size=$1
    if command -v numfmt &>/dev/null; then
        numfmt --to=iec "$size"
    else
        echo "$size bytes"
    fi
}

# ============================================================================
# Commands
# ============================================================================

usage() {
    cat << EOF
DOOM WAD Installation Tool for WiFi Pineapple Pager

Usage: $0 <command>

Commands:
  list      Show available WAD configurations and their status
  identify  Scan and identify all WADs in the wads/ directory
  install   Create payload directories for available WAD combinations
  deploy    Deploy WAD payloads to the Pager (requires SSH)
  clean     Remove all generated WAD payload directories

WAD Directory: $WADS_DIR

Supported IWADs:
  doom1.wad     - DOOM Shareware (Episode 1 only)
  doom.wad      - The Ultimate DOOM / DOOM Registered (Episodes 1-4)
  doom2.wad     - DOOM II: Hell on Earth
  tnt.wad       - Final DOOM: TNT Evilution
  plutonia.wad  - Final DOOM: Plutonia Experiment

Supported PWADs:
  nerve.wad        - No Rest for the Living (requires doom2.wad)
  masterlevels.wad - Master Levels (requires doom2.wad)
  sigil.wad        - SIGIL (requires doom.wad) - uses SIGIL_COMPAT version

Notes:
  - SIGIL uses the "compat" version which replaces Episode 3
  - SIGIL II is NOT compatible (requires UMAPINFO support)
EOF
}

# Identify all WADs in the directory
cmd_identify() {
    echo "=== Scanning WAD Files ==="
    echo ""
    
    local count=0
    local wad
    
    for wad in "$WADS_DIR"/*.wad "$WADS_DIR"/*.WAD; do
        [ -f "$wad" ] || continue
        ((count++)) || true
        
        local basename=$(basename "$wad")
        local size=$(stat -c%s "$wad" 2>/dev/null || stat -f%z "$wad" 2>/dev/null || echo "0")
        local sha256=$(get_sha256 "$wad")
        local info
        info=$(identify_wad "$wad") || true
        
        local type=$(parse_wad_info "$info" type)
        local edition=$(parse_wad_info "$info" edition)
        local version=$(parse_wad_info "$info" version)
        local desc=$(parse_wad_info "$info" desc)
        
        if [ "$type" = "UNKNOWN" ]; then
            log_warn "$basename"
            echo "       Size: $(format_size "$size")"
            echo "       SHA256: ${sha256:0:16}..."
            echo "       Status: Unknown WAD (not in database)"
        else
            log_ok "$basename"
            echo "       Type: $type ($edition)"
            echo "       Version: $version"
            echo "       Description: $desc"
            echo "       SHA256: ${sha256:0:16}..."
        fi
        echo ""
    done
    
    if [ "$count" -eq 0 ]; then
        log_warn "No WAD files found in $WADS_DIR"
        echo ""
        echo "Place your WAD files there, then run: $0 identify"
    else
        echo "Found $count WAD file(s)"
    fi
}

# List available configurations
cmd_list() {
    echo "=== WAD Payload Configurations ==="
    echo ""
    
    local config
    for config in "${WAD_CONFIGS[@]}"; do
        IFS='|' read -r name iwad pwad title desc <<< "$config"
        
        # Check IWAD
        local iwad_path
        iwad_path=$(find_wad "$iwad") || true
        local iwad_ok=false
        local iwad_info=""
        
        if [ -n "$iwad_path" ]; then
            iwad_ok=true
            iwad_info=$(identify_wad "$iwad_path") || true
        fi
        
        # Check PWAD if needed
        local pwad_ok=true
        local pwad_info=""
        if [ -n "$pwad" ]; then
            local pwad_path
            pwad_path=$(find_wad "$pwad") || true
            if [ -n "$pwad_path" ]; then
                pwad_info=$(identify_wad "$pwad_path") || true
            else
                pwad_ok=false
            fi
        fi
        
        # Display status
        if $iwad_ok && $pwad_ok; then
            log_ok "$title ($name)"
            echo "    $desc"
            
            local iwad_edition=$(parse_wad_info "$iwad_info" edition)
            echo "    IWAD: $iwad ($iwad_edition)"
            
            if [ -n "$pwad" ]; then
                local pwad_version=$(parse_wad_info "$pwad_info" version)
                echo "    PWAD: $pwad (v$pwad_version)"
            fi
            
        else
            log_error "$title ($name)"
            if ! $iwad_ok; then
                echo "    Missing IWAD: $iwad"
            fi
            if [ -n "$pwad" ] && ! $pwad_ok; then
                echo "    Missing PWAD: $pwad"
            fi
        fi
        echo ""
    done
}

# Create payload for a WAD configuration
create_payload() {
    local name="$1"
    local iwad="$2"
    local pwad="$3"
    local title="$4"
    local desc="$5"
    
    local payload_dir="$PAYLOADS_DIR/$name"
    mkdir -p "$payload_dir"
    
    # Find WAD paths
    local iwad_path
    iwad_path=$(find_wad "$iwad") || true
    local iwad_basename=$(basename "$iwad_path")
    
    local pwad_path=""
    local pwad_basename=""
    if [ -n "$pwad" ]; then
        pwad_path=$(find_wad "$pwad") || true
        pwad_basename=$(basename "$pwad_path")
    fi
    
    # Symlink doomgeneric from base doom payload
    if [ -f "$PAYLOADS_DIR/doom/doomgeneric" ]; then
        ln -sf ../doom/doomgeneric "$payload_dir/doomgeneric"
    else
        log_error "Base doom payload not found. Run build.sh first."
        return 1
    fi
    
    # Handle IWAD: symlink to base payloads to save space, or copy if this IS the base
    if [ "$iwad_basename" = "doom.wad" ] && [ "$name" != "doom-registered" ]; then
        # Symlink to doom-registered payload
        ln -sf ../doom-registered/doom.wad "$payload_dir/doom.wad"
    elif [ "$iwad_basename" = "doom2.wad" ] && [ "$name" != "doom2" ]; then
        # Symlink to doom2 payload
        ln -sf ../doom2/doom2.wad "$payload_dir/doom2.wad"
    else
        # This is a base payload or unique IWAD - copy the file
        cp "$iwad_path" "$payload_dir/$iwad_basename"
    fi
    
    # Copy PWAD files (these are unique per payload)
    if [ -n "$pwad_path" ]; then
        cp "$pwad_path" "$payload_dir/$pwad_basename"
    fi
    
    # Generate payload.sh
    cat > "$payload_dir/payload.sh" << PAYLOAD
#!/bin/bash
# Title: $title
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

LOG "$desc"
LOG ""
LOG "Controls:"
LOG "D-pad=Move  Red=Fire"
LOG "Green=Select/Use"
LOG "Red+Green=Quit"
LOG ""
LOG "Press any button..."
WAIT_FOR_INPUT >/dev/null 2>&1

# Stop services to free CPU and memory for DOOM
/etc/init.d/php8-fpm stop 2>/dev/null
/etc/init.d/nginx stop 2>/dev/null
/etc/init.d/bluetoothd stop 2>/dev/null
/etc/init.d/pineapplepager stop 2>/dev/null
/etc/init.d/pineapd stop 2>/dev/null
echo 3 > /proc/sys/vm/drop_caches 2>/dev/null

sleep 1

# Build command line
DOOM_ARGS="-iwad \"\$PAYLOAD_DIR/$iwad_basename\""
PAYLOAD

    # Add PWAD argument if present
    if [ -n "$pwad_basename" ]; then
        cat >> "$payload_dir/payload.sh" << PAYLOAD
DOOM_ARGS="\$DOOM_ARGS -file \"\$PAYLOAD_DIR/$pwad_basename\""
PAYLOAD
    fi

    # Complete the payload script
    cat >> "$payload_dir/payload.sh" << 'PAYLOAD'

# Run DOOM
eval "$PAYLOAD_DIR/doomgeneric $DOOM_ARGS" >/tmp/doom.log 2>&1

# Restore services after DOOM exits
/etc/init.d/php8-fpm start 2>/dev/null &
/etc/init.d/nginx start 2>/dev/null &
/etc/init.d/bluetoothd start 2>/dev/null &
/etc/init.d/pineapplepager start 2>/dev/null &
/etc/init.d/pineapd start 2>/dev/null &

LOG ""
LOG "DOOM exited. Press any button..."
WAIT_FOR_INPUT >/dev/null 2>&1
PAYLOAD

    chmod +x "$payload_dir/payload.sh"
    
    # Create SHA256SUMS
    (cd "$payload_dir" && sha256sum *.wad *.WAD payload.sh 2>/dev/null > SHA256SUMS) || true
    
    log_ok "Created: $name"
}

# Install all available configurations
cmd_install() {
    echo "=== Installing WAD Payloads ==="
    echo ""
    
    # Check for base doom payload
    if [ ! -f "$PAYLOADS_DIR/doom/doomgeneric" ]; then
        log_error "Base doom payload not found!"
        echo "Run build.sh first to create the base DOOM payload."
        exit 1
    fi
    
    local installed=0
    local skipped=0
    local config
    
    # Install base payloads first (doom-registered, doom2) so others can symlink to them
    local ordered_configs=()
    for config in "${WAD_CONFIGS[@]}"; do
        IFS='|' read -r name _ _ _ _ <<< "$config"
        if [ "$name" = "doom-registered" ] || [ "$name" = "doom2" ]; then
            ordered_configs=("$config" "${ordered_configs[@]}")
        else
            ordered_configs+=("$config")
        fi
    done
    
    for config in "${ordered_configs[@]}"; do
        IFS='|' read -r name iwad pwad title desc <<< "$config"
        
        # Skip base doom payloads (handled by build.sh)
        if [ "$name" = "doom" ] || [ "$name" = "doom-deathmatch" ]; then
            continue
        fi
        
        # Check if WADs exist
        local iwad_path
        iwad_path=$(find_wad "$iwad") || true
        local pwad_path=""
        local can_install=true
        
        if [ -z "$iwad_path" ]; then
            can_install=false
        fi
        
        if [ -n "$pwad" ]; then
            pwad_path=$(find_wad "$pwad") || true
            if [ -z "$pwad_path" ]; then
                can_install=false
            fi
        fi
        
        if $can_install; then
            create_payload "$name" "$iwad" "$pwad" "$title" "$desc"
            ((installed++)) || true
        else
            ((skipped++)) || true
        fi
    done
    
    echo ""
    echo "Installed: $installed payload(s)"
    [ "$skipped" -gt 0 ] && echo "Skipped: $skipped (missing WADs)"
    echo ""
    echo "To deploy to Pager: $0 deploy"
}

# Deploy to Pager
cmd_deploy() {
    echo "=== Deploying WAD Payloads to Pager ==="
    echo ""
    
    # Test connection
    if ! ssh -o ConnectTimeout=5 "$PAGER" "echo connected" >/dev/null 2>&1; then
        log_error "Cannot connect to $PAGER"
        echo "Make sure the Pager is connected and accessible."
        exit 1
    fi
    
    local deployed=0
    local config
    
    # Deploy base payloads first (doom-registered and doom2) so others can symlink to them
    local ordered_configs=()
    for config in "${WAD_CONFIGS[@]}"; do
        IFS='|' read -r name _ _ _ _ <<< "$config"
        if [ "$name" = "doom-registered" ] || [ "$name" = "doom2" ]; then
            ordered_configs=("$config" "${ordered_configs[@]}")
        else
            ordered_configs+=("$config")
        fi
    done
    
    for config in "${ordered_configs[@]}"; do
        IFS='|' read -r name iwad pwad title desc <<< "$config"
        local payload_dir="$PAYLOADS_DIR/$name"
        
        # Skip if not installed locally
        [ ! -d "$payload_dir" ] && continue
        
        log_info "Deploying $name..."
        
        # Create remote directory
        ssh "$PAGER" "mkdir -p $PAGER_DEST/$name"
        
        # Handle IWAD deployment: copy or symlink based on payload type
        local iwad_basename=$(basename "$iwad")
        if [ "$iwad_basename" = "doom.wad" ] && [ "$name" != "doom-registered" ]; then
            # Symlink to doom-registered
            ssh "$PAGER" "cd $PAGER_DEST/$name && rm -f doom.wad && ln -s ../doom-registered/doom.wad ."
        elif [ "$iwad_basename" = "doom2.wad" ] && [ "$name" != "doom2" ]; then
            # Symlink to doom2
            ssh "$PAGER" "cd $PAGER_DEST/$name && rm -f doom2.wad && ln -s ../doom2/doom2.wad ."
        else
            # Copy the IWAD (this is a base payload or unique IWAD like tnt.wad)
            scp -q "$payload_dir/$iwad_basename" "$PAGER:$PAGER_DEST/$name/" 2>/dev/null || true
        fi
        
        # Copy PWAD files (always unique per payload)
        if [ -n "$pwad" ]; then
            local pwad_basename=$(basename "$pwad")
            scp -q "$payload_dir/$pwad_basename" "$PAGER:$PAGER_DEST/$name/" 2>/dev/null || true
        fi
        
        # Copy payload script and checksums
        scp -q "$payload_dir/payload.sh" "$payload_dir/SHA256SUMS" "$PAGER:$PAGER_DEST/$name/"
        
        # Create symlink to shared doomgeneric binary
        ssh "$PAGER" "cd $PAGER_DEST/$name && rm -f doomgeneric && ln -s ../doom/doomgeneric . && chmod +x payload.sh"
        
        log_ok "Deployed $name"
        ((deployed++)) || true
    done
    
    echo ""
    echo "Deployed $deployed payload(s) to $PAGER"
    echo ""
    echo "New games should appear in: Payloads > User > Games"
}

# Clean up generated payloads
cmd_clean() {
    echo "=== Cleaning WAD Payloads ==="
    echo ""
    
    local cleaned=0
    local config
    
    for config in "${WAD_CONFIGS[@]}"; do
        IFS='|' read -r name iwad pwad title desc <<< "$config"
        local payload_dir="$PAYLOADS_DIR/$name"
        
        # Don't clean base doom payloads
        if [ "$name" = "doom" ] || [ "$name" = "doom-deathmatch" ]; then
            continue
        fi
        
        if [ -d "$payload_dir" ]; then
            rm -rf "$payload_dir"
            log_ok "Removed: $name"
            ((cleaned++)) || true
        fi
    done
    
    echo ""
    echo "Cleaned $cleaned payload(s)"
}

# ============================================================================
# Main
# ============================================================================

# Create wads directory if it doesn't exist
mkdir -p "$WADS_DIR"

case "${1:-}" in
    list)     cmd_list ;;
    identify) cmd_identify ;;
    install)  cmd_install ;;
    deploy)   cmd_deploy ;;
    clean)    cmd_clean ;;
    -h|--help|help)
        usage
        ;;
    "")
        usage
        echo ""
        log_info "Run '$0 list' to see available configurations"
        ;;
    *)
        log_error "Unknown command: $1"
        echo ""
        usage
        exit 1
        ;;
esac
