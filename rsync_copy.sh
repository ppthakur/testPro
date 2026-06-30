#!/usr/bin/env bash
# Copy files/folders between two laptops on the same WiFi network using rsync over SSH.
#
# Prerequisites (both laptops):
#   Linux/macOS : rsync and ssh are usually pre-installed
#   Windows     : install WSL2 (recommended), or Git-Bash + cwRsync
#
# Quick-start:
#   1. Find the remote laptop's local IP:
#        Linux/macOS : ip addr  OR  hostname -I
#        Windows     : ipconfig  (look for "IPv4 Address" under your WiFi adapter)
#   2. Make sure SSH is running on the remote laptop:
#        Linux   : sudo systemctl enable --now ssh
#        macOS   : System Settings → General → Sharing → Remote Login → ON
#        Windows : Settings → System → Optional Features → Add "OpenSSH Server"
#                  then: net start sshd
#   3. Run this script (see examples at the bottom).

set -euo pipefail

# ── Configuration (override via env vars or CLI flags) ────────────────────────
REMOTE_USER="${REMOTE_USER:-}"
REMOTE_HOST="${REMOTE_HOST:-}"
REMOTE_PORT="${REMOTE_PORT:-22}"
SSH_KEY="${SSH_KEY:-}"          # optional: path to private key
DIRECTION="${DIRECTION:-push}"  # push = local→remote | pull = remote→local
# ─────────────────────────────────────────────────────────────────────────────

usage() {
    cat <<EOF
Usage: $0 [OPTIONS] <source> <destination>

Copy files/folders between two laptops on the same WiFi using rsync over SSH.

Options:
  -u USER      Remote username          (or set \$REMOTE_USER)
  -h HOST      Remote IP / hostname     (or set \$REMOTE_HOST)
  -p PORT      SSH port [default: 22]   (or set \$REMOTE_PORT)
  -i KEY       Path to SSH private key  (or set \$SSH_KEY)
  -d DIR       Direction: push|pull     [default: push]
  -n           Dry-run — show what would transfer without copying
  --scan       Scan WiFi subnet for live hosts (requires nmap)
  --help       Show this help

Examples — WiFi LAN (both laptops on same router):

  # Push a folder to the other laptop
  $0 -u alice -h 192.168.1.42 ~/Documents/project /home/alice/project

  # Pull a folder from the other laptop
  $0 -u alice -h 192.168.1.42 -d pull /home/alice/photos ~/Pictures/photos

  # Dry-run first to preview what will be copied
  $0 -u alice -h 192.168.1.42 -n ~/Music /home/alice/Music

  # Windows path via WSL (backslashes → forward slashes)
  $0 -u alice -h 192.168.1.42 /mnt/c/Users/You/Documents /home/alice/Documents

  # Using environment variables
  REMOTE_USER=alice REMOTE_HOST=192.168.1.42 $0 ~/Videos /home/alice/Videos

Tip — find the other laptop's IP:
  Linux/macOS : ip addr  |  hostname -I
  Windows     : ipconfig (look for IPv4 under Wi-Fi adapter)
EOF
    exit 0
}

scan_network() {
    if ! command -v nmap &>/dev/null; then
        echo "nmap is not installed. Install it with:"
        echo "  Linux : sudo apt install nmap"
        echo "  macOS : brew install nmap"
        exit 1
    fi
    # Detect local subnet automatically
    local subnet
    subnet=$(ip route | awk '/proto kernel/ && /src/ {print $1; exit}' 2>/dev/null \
             || route -n get default 2>/dev/null | awk '/interface/{print $2}' \
             || echo "192.168.1.0/24")
    echo "Scanning subnet $subnet for live hosts..."
    nmap -sn "$subnet" | awk '/report for/{print $NF} /MAC Address/{print "  "$0}'
    exit 0
}

# ── Parse arguments ────────────────────────────────────────────────────────────
DRY_RUN=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        -u)     REMOTE_USER="$2"; shift 2 ;;
        -h)     REMOTE_HOST="$2"; shift 2 ;;
        -p)     REMOTE_PORT="$2"; shift 2 ;;
        -i)     SSH_KEY="$2";     shift 2 ;;
        -d)     DIRECTION="$2";   shift 2 ;;
        -n)     DRY_RUN="--dry-run"; shift ;;
        --scan) scan_network ;;
        --help) usage ;;
        --)     shift; break ;;
        -*)     echo "Unknown option: $1" >&2; echo; usage ;;
        *)      break ;;
    esac
done

SOURCE="${1:-}"
DEST="${2:-}"

# ── Validate ───────────────────────────────────────────────────────────────────
errors=0
[[ -z "$REMOTE_USER" ]] && { echo "ERROR: Remote user not set. Use -u USER or \$REMOTE_USER." >&2; ((errors++)); }
[[ -z "$REMOTE_HOST" ]] && { echo "ERROR: Remote host/IP not set. Use -h HOST or \$REMOTE_HOST." >&2; ((errors++)); }
[[ -z "$SOURCE" ]]      && { echo "ERROR: Source path not provided." >&2; ((errors++)); }
[[ -z "$DEST" ]]        && { echo "ERROR: Destination path not provided." >&2; ((errors++)); }
[[ "$DIRECTION" != "push" && "$DIRECTION" != "pull" ]] && {
    echo "ERROR: Direction must be 'push' or 'pull', got '$DIRECTION'." >&2; ((errors++))
}
((errors > 0)) && { echo; usage; }

# ── Build SSH options ──────────────────────────────────────────────────────────
# StrictHostKeyChecking=ask prompts only on first connect, then remembers the key.
SSH_OPTS="-o StrictHostKeyChecking=ask -o ConnectTimeout=10 -p ${REMOTE_PORT}"
[[ -n "$SSH_KEY" ]] && SSH_OPTS="$SSH_OPTS -i $SSH_KEY"

# ── Build rsync flags ──────────────────────────────────────────────────────────
RSYNC_OPTS=(
    --archive           # preserve permissions, timestamps, symlinks, owner
    --verbose
    --human-readable
    --progress
    --compress          # compress data during LAN transfer
    --partial           # resume interrupted transfers
    --exclude='.DS_Store'
    --exclude='Thumbs.db'
    --exclude='desktop.ini'
    --exclude='*.tmp'
)
[[ -n "$DRY_RUN" ]] && RSYNC_OPTS+=("--dry-run")

REMOTE="${REMOTE_USER}@${REMOTE_HOST}"

if [[ "$DIRECTION" == "push" ]]; then
    SRC="$SOURCE"
    DST="${REMOTE}:${DEST}"
else
    SRC="${REMOTE}:${SOURCE}"
    DST="$DEST"
    mkdir -p "$DEST"
fi

# ── Summary ────────────────────────────────────────────────────────────────────
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  rsync copy  (WiFi LAN)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
printf "  %-12s %s\n" "Direction:"  "$DIRECTION  (local → remote: push | remote → local: pull)"
printf "  %-12s %s\n" "From:"       "$SRC"
printf "  %-12s %s\n" "To:"         "$DST"
printf "  %-12s %s\n" "Remote IP:"  "$REMOTE_HOST  port $REMOTE_PORT"
[[ -n "$SSH_KEY" ]]  && printf "  %-12s %s\n" "SSH key:"    "$SSH_KEY"
[[ -n "$DRY_RUN" ]]  && printf "  %-12s %s\n" "Mode:"       "DRY RUN — no files will be transferred"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo

rsync "${RSYNC_OPTS[@]}" \
    -e "ssh $SSH_OPTS" \
    "$SRC" "$DST"

echo
echo "Transfer complete."
