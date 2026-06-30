#!/usr/bin/env bash
# Copy files/folders from this machine to a remote machine (or vice versa) using rsync over SSH.

set -euo pipefail

# ── Configuration ─────────────────────────────────────────────────────────────
REMOTE_USER="${REMOTE_USER:-}"
REMOTE_HOST="${REMOTE_HOST:-}"
REMOTE_PORT="${REMOTE_PORT:-22}"
SSH_KEY="${SSH_KEY:-}"          # optional: path to private key
DIRECTION="${DIRECTION:-push}"  # push = local→remote, pull = remote→local
# ──────────────────────────────────────────────────────────────────────────────

usage() {
    cat <<EOF
Usage: $0 [OPTIONS] <source> <destination>

Copy files/folders between two laptops via rsync over SSH.

Positional arguments:
  source       Local path (push) or remote path hint (pull)
  destination  Remote path (push) or local path (pull)

Options:
  -u USER      Remote username          (or set \$REMOTE_USER)
  -h HOST      Remote hostname/IP       (or set \$REMOTE_HOST)
  -p PORT      SSH port [default: 22]   (or set \$REMOTE_PORT)
  -i KEY       Path to SSH private key  (or set \$SSH_KEY)
  -d DIR       Direction: push|pull     (or set \$DIRECTION) [default: push]
  -n           Dry-run (show what would be copied without copying)
  --help       Show this help

Examples:
  # Push a folder to a remote laptop
  $0 -u alice -h 192.168.1.42 -d push ~/Documents/project /home/alice/project

  # Pull a folder from a remote laptop
  $0 -u alice -h 192.168.1.42 -d pull /home/alice/project ~/Documents/project

  # Push with a custom SSH key
  $0 -u alice -h laptop2.local -i ~/.ssh/id_rsa -d push ~/photos /home/alice/photos

  # Using environment variables
  REMOTE_USER=alice REMOTE_HOST=192.168.1.42 $0 ~/Music /home/alice/Music
EOF
    exit 0
}

# ── Parse arguments ────────────────────────────────────────────────────────────
DRY_RUN=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        -u) REMOTE_USER="$2"; shift 2 ;;
        -h) REMOTE_HOST="$2"; shift 2 ;;
        -p) REMOTE_PORT="$2"; shift 2 ;;
        -i) SSH_KEY="$2";     shift 2 ;;
        -d) DIRECTION="$2";   shift 2 ;;
        -n) DRY_RUN="--dry-run"; shift ;;
        --help) usage ;;
        --) shift; break ;;
        -*) echo "Unknown option: $1" >&2; usage ;;
        *)  break ;;
    esac
done

SOURCE="${1:-}"
DEST="${2:-}"

# ── Validate ───────────────────────────────────────────────────────────────────
errors=0
[[ -z "$REMOTE_USER" ]] && { echo "ERROR: Remote user not set (-u or \$REMOTE_USER)." >&2; ((errors++)); }
[[ -z "$REMOTE_HOST" ]] && { echo "ERROR: Remote host not set (-h or \$REMOTE_HOST)." >&2; ((errors++)); }
[[ -z "$SOURCE" ]]      && { echo "ERROR: Source path not provided." >&2; ((errors++)); }
[[ -z "$DEST" ]]        && { echo "ERROR: Destination path not provided." >&2; ((errors++)); }
[[ "$DIRECTION" != "push" && "$DIRECTION" != "pull" ]] && {
    echo "ERROR: Direction must be 'push' or 'pull'." >&2; ((errors++))
}
((errors > 0)) && { echo; usage; }

# ── Build SSH options ──────────────────────────────────────────────────────────
SSH_OPTS="-o StrictHostKeyChecking=ask -p ${REMOTE_PORT}"
[[ -n "$SSH_KEY" ]] && SSH_OPTS="$SSH_OPTS -i $SSH_KEY"

# ── Build rsync command ────────────────────────────────────────────────────────
RSYNC_OPTS=(
    --archive           # preserves permissions, timestamps, symlinks, owner
    --verbose
    --human-readable
    --progress
    --compress          # compress during transfer
    --partial           # resume interrupted transfers
    --exclude='.DS_Store'
    --exclude='Thumbs.db'
    --exclude='desktop.ini'
)
[[ -n "$DRY_RUN" ]] && RSYNC_OPTS+=("--dry-run")

REMOTE="${REMOTE_USER}@${REMOTE_HOST}"

if [[ "$DIRECTION" == "push" ]]; then
    SRC="$SOURCE"
    DST="${REMOTE}:${DEST}"
else
    SRC="${REMOTE}:${SOURCE}"
    DST="$DEST"
    # Create local destination if it doesn't exist
    mkdir -p "$DEST"
fi

# ── Summary ────────────────────────────────────────────────────────────────────
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  rsync copy"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Direction : $DIRECTION"
echo "  From      : $SRC"
echo "  To        : $DST"
echo "  SSH port  : $REMOTE_PORT"
[[ -n "$SSH_KEY" ]] && echo "  SSH key   : $SSH_KEY"
[[ -n "$DRY_RUN" ]] && echo "  Mode      : DRY RUN (no files will be transferred)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo

rsync "${RSYNC_OPTS[@]}" \
    -e "ssh $SSH_OPTS" \
    "$SRC" "$DST"

echo
echo "Done."
