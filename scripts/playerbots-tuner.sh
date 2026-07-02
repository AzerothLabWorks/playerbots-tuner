#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SERVER_DIR="${SERVER_DIR:-}"
COMMAND=""
DRY_RUN=0
YES=0
RESTART=0
REBUILD=0
SKIP_COMPOSE=0
BOT_COUNT=""
MIN_LEVEL=""
MAX_LEVEL=""
FOLLOW_DISTANCE=""

BACKUP_STAMP="$(date +%Y%m%d-%H%M%S)"
BACKED_UP_FILES=""

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/playerbots-tuner.sh [options] COMMAND [args]

Options:
  --server-dir PATH       AzerothCore/Playerbots server source or install directory.
  --dry-run               Show intended changes without writing files or running Docker.
  --yes                   Do not prompt before restart/rebuild.
  --restart               Restart ac-worldserver after config changes.
  --rebuild               Rebuild and restart ac-worldserver after patch changes.
  --skip-compose          Do not update docker-compose.override.yml environment values.
  --bots N                Override preset random bot count.
  --min-level N           Override preset random bot minimum level.
  --max-level N           Override preset random bot maximum level.
  --follow-distance N     Override preset follow distance in yards.
  -h, --help              Show this help.

Commands:
  list-presets            Show available presets.
  apply-preset NAME       Apply a config preset.
  apply-patches lfg       Apply optional Playerbots LFG reliability patches.
  doctor                  Check install layout and important Playerbots settings.
  diagnose-lfg            Show LFG-related config and recent worldserver logs.
  diagnose-pvp            Show PvP-related config and recent worldserver logs.
  print-macros            Print useful in-game Playerbots party commands.
  restart                 Restart ac-worldserver.
  rebuild                 Rebuild and restart ac-worldserver.

Presets:
  quiet-social            Disable repeated greetings/emotes while preserving useful bot chat.
  solo-controller         Quiet, stable party play for controller/low-friction leveling.
  dungeon-lfg             Leveling dungeon density, LFG participation, role-biased specs.
  pvp-3v3                 Conservative level-80 rated 3v3 seeding.
  living-server           Dungeon + PvP + world social defaults.

Examples:
  ./scripts/playerbots-tuner.sh --server-dir ~/wow-server-playerbots apply-preset solo-controller --restart
  ./scripts/playerbots-tuner.sh --server-dir ~/wow-server-playerbots apply-preset dungeon-lfg --bots 1000 --dry-run
  ./scripts/playerbots-tuner.sh --server-dir ~/wow-server-playerbots apply-patches lfg --rebuild
  ./scripts/playerbots-tuner.sh --server-dir ~/wow-server-playerbots doctor
USAGE
}

log() { printf '\033[0;36m==>\033[0m %s\n' "$*" >&2; }
warn() { printf '\033[1;33mWARN:\033[0m %s\n' "$*" >&2; }
die() { printf '\033[0;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

confirm_or_die() {
  local prompt="$1"
  [[ "$YES" == "1" ]] && return 0
  printf '%s [y/N] ' "$prompt"
  read -r answer
  [[ "$answer" =~ ^[Yy]$ ]] || die "Cancelled."
}

run_cmd() {
  if [[ "$DRY_RUN" == "1" ]]; then
    printf '[dry-run] %q ' "$@"
    printf '\n'
  else
    "$@"
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --server-dir) SERVER_DIR="${2:-}"; shift 2 ;;
      --dry-run) DRY_RUN=1; shift ;;
      --yes) YES=1; shift ;;
      --restart) RESTART=1; shift ;;
      --rebuild) REBUILD=1; shift ;;
      --skip-compose) SKIP_COMPOSE=1; shift ;;
      --bots) BOT_COUNT="${2:-}"; shift 2 ;;
      --min-level) MIN_LEVEL="${2:-}"; shift 2 ;;
      --max-level) MAX_LEVEL="${2:-}"; shift 2 ;;
      --follow-distance) FOLLOW_DISTANCE="${2:-}"; shift 2 ;;
      -h|--help) usage; exit 0 ;;
      list-presets|apply-preset|apply-patches|doctor|diagnose-lfg|diagnose-pvp|print-macros|restart|rebuild)
        COMMAND="$1"
        shift
        COMMAND_ARGS=("$@")
        return 0
        ;;
      *) die "Unknown option or command: $1" ;;
    esac
  done

  COMMAND_ARGS=()
}

require_server_dir() {
  [[ -n "$SERVER_DIR" ]] || die "SERVER_DIR is not set. Use --server-dir PATH."
  [[ -d "$SERVER_DIR" ]] || die "Server directory does not exist: $SERVER_DIR"
}

require_docker_compose_file() {
  require_server_dir
  [[ -f "$SERVER_DIR/docker-compose.yml" || -f "$SERVER_DIR/compose.yml" ]] || die "No docker-compose.yml or compose.yml found in: $SERVER_DIR"
}

find_playerbots_dist_config() {
  local candidates=(
    "$SERVER_DIR/env/dist/etc/modules/playerbots.conf.dist"
    "$SERVER_DIR/etc/modules/playerbots.conf.dist"
    "$SERVER_DIR/configs/modules/playerbots.conf.dist"
    "$SERVER_DIR/modules/mod-playerbots/conf/playerbots.conf.dist"
  )

  local candidate
  for candidate in "${candidates[@]}"; do
    [[ -f "$candidate" ]] && { printf '%s\n' "$candidate"; return 0; }
  done

  find "$SERVER_DIR" -path '*/modules/*' -name 'playerbots.conf.dist' -type f 2>/dev/null | head -1
}

find_playerbots_config() {
  local candidates=(
    "$SERVER_DIR/env/dist/etc/modules/playerbots.conf"
    "$SERVER_DIR/etc/modules/playerbots.conf"
    "$SERVER_DIR/configs/modules/playerbots.conf"
    "$SERVER_DIR/modules/mod-playerbots/conf/playerbots.conf"
  )

  local candidate
  for candidate in "${candidates[@]}"; do
    [[ -f "$candidate" ]] && { printf '%s\n' "$candidate"; return 0; }
  done

  find "$SERVER_DIR" -path '*/modules/*' -name 'playerbots.conf' -type f 2>/dev/null | head -1
}

ensure_playerbots_config() {
  require_server_dir

  local config_file
  config_file="$(find_playerbots_config || true)"
  if [[ -n "$config_file" ]]; then
    printf '%s\n' "$config_file"
    return 0
  fi

  local dist_file
  dist_file="$(find_playerbots_dist_config || true)"
  [[ -n "$dist_file" ]] || die "Could not find playerbots.conf or playerbots.conf.dist. Is mod-playerbots installed?"

  local target_dir="$SERVER_DIR/env/dist/etc/modules"
  local target_file="$target_dir/playerbots.conf"
  log "Creating Playerbots runtime config from: $dist_file"
  if [[ "$DRY_RUN" == "1" ]]; then
    printf '[dry-run] mkdir -p %q\n' "$target_dir" >&2
    printf '[dry-run] cp %q %q\n' "$dist_file" "$target_file" >&2
  else
    mkdir -p "$target_dir"
    cp "$dist_file" "$target_file"
  fi

  printf '%s\n' "$target_file"
}

compose_override_file() {
  local override="$SERVER_DIR/docker-compose.override.yml"
  [[ -f "$override" ]] && { printf '%s\n' "$override"; return 0; }
  printf '%s\n' "$override"
}

backup_file_once() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  [[ " $BACKED_UP_FILES " == *" $file "* ]] && return 0

  local backup="${file}.bak.${BACKUP_STAMP}"
  if [[ "$DRY_RUN" == "1" ]]; then
    printf '[dry-run] cp %q %q\n' "$file" "$backup"
  else
    cp "$file" "$backup"
  fi
  BACKED_UP_FILES="$BACKED_UP_FILES $file"
}

set_conf_value() {
  local file="$1"
  local key="$2"
  local value="$3"

  backup_file_once "$file"
  if [[ "$DRY_RUN" == "1" ]]; then
    printf '[dry-run] set %s = %s in %s\n' "$key" "$value" "$file"
    return 0
  fi

  if grep -qE "^[[:space:]]*#?[[:space:]]*${key}[[:space:]]*=" "$file"; then
    sed -i -E "s|^[[:space:]]*#?[[:space:]]*${key}[[:space:]]*=.*|${key} = ${value}|" "$file"
  else
    printf '\n%s = %s\n' "$key" "$value" >> "$file"
  fi
}

ensure_compose_override() {
  local file
  file="$(compose_override_file)"

  if [[ -f "$file" ]]; then
    printf '%s\n' "$file"
    return 0
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    printf '[dry-run] create %s with ac-worldserver environment block\n' "$file" >&2
  else
    cat > "$file" <<'YAML'
services:
  ac-worldserver:
    environment: {}
YAML
  fi
  printf '%s\n' "$file"
}

set_compose_environment_value() {
  [[ "$SKIP_COMPOSE" == "1" ]] && return 0

  local key="$1"
  local value="$2"
  local file
  file="$(ensure_compose_override)"
  backup_file_once "$file"

  if [[ "$DRY_RUN" == "1" ]]; then
    printf '[dry-run] set %s: "%s" in %s\n' "$key" "$value" "$file"
    return 0
  fi

  if grep -qE "^[[:space:]]+${key}:" "$file"; then
    sed -i -E "s|^([[:space:]]+${key}:).*|\\1 \"${value}\"|" "$file"
    return 0
  fi

  local temp_file
  temp_file="$(mktemp)"
  if awk -v key="$key" -v value="$value" '
    {
      if (!inserted && $0 ~ /^[[:space:]]+environment:[[:space:]]*(\{\})?[[:space:]]*$/) {
        match($0, /^[[:space:]]+/)
        indent = substr($0, RSTART, RLENGTH)
        if ($0 ~ /\{\}/) {
          print indent "environment:"
          print indent "  " key ": \"" value "\""
        } else {
          print
          print indent "  " key ": \"" value "\""
        }
        inserted = 1
      } else {
        print
      }
    }
    END { exit inserted ? 0 : 1 }
  ' "$file" > "$temp_file"; then
    mv "$temp_file" "$file"
  else
    rm -f "$temp_file"
    warn "Could not find environment block in $file. Leaving $key unchanged."
  fi
}

set_playerbot_value() {
  local config="$1"
  local key="$2"
  local value="$3"
  set_conf_value "$config" "$key" "$value"
}

set_playerbot_env() {
  local key="$1"
  local value="$2"
  set_compose_environment_value "$key" "$value"
}

apply_quiet_social() {
  local config="$1"
  set_playerbot_value "$config" "AiPlayerbot.EnableGreet" "0"
  set_playerbot_value "$config" "AiPlayerbot.RandomBotEmote" "0"
  set_playerbot_value "$config" "AiPlayerbot.RandomBotSayWithoutMaster" "0"
  set_playerbot_value "$config" "AiPlayerbot.RandomBotTalk" "1"
  set_playerbot_value "$config" "AiPlayerbot.EnableBroadcasts" "1"

  set_playerbot_env "AC_AI_PLAYERBOT_ENABLE_GREET" "0"
  set_playerbot_env "AC_AI_PLAYERBOT_RANDOM_BOT_EMOTE" "0"
  set_playerbot_env "AC_AI_PLAYERBOT_RANDOM_BOT_SAY_WITHOUT_MASTER" "0"
}

apply_solo_controller() {
  local config="$1"
  local bots="${BOT_COUNT:-500}"
  local min_level="${MIN_LEVEL:-1}"
  local max_level="${MAX_LEVEL:-80}"
  local follow_distance="${FOLLOW_DISTANCE:-2.5}"

  apply_quiet_social "$config"
  set_playerbot_value "$config" "AiPlayerbot.RandomBotAutologin" "1"
  set_playerbot_value "$config" "AiPlayerbot.MinRandomBots" "$bots"
  set_playerbot_value "$config" "AiPlayerbot.MaxRandomBots" "$bots"
  set_playerbot_value "$config" "AiPlayerbot.RandomBotAccountCount" "0"
  set_playerbot_value "$config" "AiPlayerbot.RandomBotMinLevel" "$min_level"
  set_playerbot_value "$config" "AiPlayerbot.RandomBotMaxLevel" "$max_level"
  set_playerbot_value "$config" "AiPlayerbot.SyncLevelWithPlayers" "1"
  set_playerbot_value "$config" "AiPlayerbot.GroupInvitationPermission" "2"
  set_playerbot_value "$config" "AiPlayerbot.SummonWhenGroup" "1"
  set_playerbot_value "$config" "AiPlayerbot.AllowSummonWhenMasterIsDead" "1"
  set_playerbot_value "$config" "AiPlayerbot.AllowSummonWhenBotIsDead" "1"
  set_playerbot_value "$config" "AiPlayerbot.ReviveBotWhenSummoned" "1"
  set_playerbot_value "$config" "AiPlayerbot.FollowDistance" "$follow_distance"
  set_playerbot_value "$config" "AiPlayerbot.ApplyInstanceStrategies" "1"
  set_playerbot_value "$config" "AiPlayerbot.AutoAvoidAoe" "1"
  set_playerbot_value "$config" "AiPlayerbot.AutoPartyBuffs" "2"

  set_playerbot_env "AC_AI_PLAYERBOT_RANDOM_BOT_AUTOLOGIN" "1"
  set_playerbot_env "AC_AI_PLAYERBOT_MIN_RANDOM_BOTS" "$bots"
  set_playerbot_env "AC_AI_PLAYERBOT_MAX_RANDOM_BOTS" "$bots"
  set_playerbot_env "AC_AI_PLAYERBOT_RANDOM_BOT_MIN_LEVEL" "$min_level"
  set_playerbot_env "AC_AI_PLAYERBOT_RANDOM_BOT_MAX_LEVEL" "$max_level"
  set_playerbot_env "AC_AI_PLAYERBOT_SYNC_LEVEL_WITH_PLAYERS" "1"
  set_playerbot_env "AC_AI_PLAYERBOT_GROUP_INVITATION_PERMISSION" "2"
  set_playerbot_env "AC_AI_PLAYERBOT_SUMMON_WHEN_GROUP" "1"
  set_playerbot_env "AC_AI_PLAYERBOT_ALLOW_SUMMON_WHEN_MASTER_IS_DEAD" "1"
  set_playerbot_env "AC_AI_PLAYERBOT_ALLOW_SUMMON_WHEN_BOT_IS_DEAD" "1"
  set_playerbot_env "AC_AI_PLAYERBOT_REVIVE_BOT_WHEN_SUMMONED" "1"
  set_playerbot_env "AC_AI_PLAYERBOT_FOLLOW_DISTANCE" "$follow_distance"
  set_playerbot_env "AC_AI_PLAYERBOT_APPLY_INSTANCE_STRATEGIES" "1"
  set_playerbot_env "AC_AI_PLAYERBOT_AUTO_AVOID_AOE" "1"
  set_playerbot_env "AC_AI_PLAYERBOT_AUTO_PARTY_BUFFS" "2"
}

apply_role_bias() {
  local config="$1"
  set_playerbot_value "$config" "AiPlayerbot.RandomClassSpecProb.1.0" "20"
  set_playerbot_value "$config" "AiPlayerbot.RandomClassSpecProb.1.1" "25"
  set_playerbot_value "$config" "AiPlayerbot.RandomClassSpecProb.1.2" "55"
  set_playerbot_value "$config" "AiPlayerbot.RandomClassSpecProb.2.0" "40"
  set_playerbot_value "$config" "AiPlayerbot.RandomClassSpecProb.2.1" "40"
  set_playerbot_value "$config" "AiPlayerbot.RandomClassSpecProb.2.2" "20"
  set_playerbot_value "$config" "AiPlayerbot.RandomClassSpecProb.5.0" "45"
  set_playerbot_value "$config" "AiPlayerbot.RandomClassSpecProb.5.1" "35"
  set_playerbot_value "$config" "AiPlayerbot.RandomClassSpecProb.5.2" "20"
  set_playerbot_value "$config" "AiPlayerbot.RandomClassSpecProb.6.0" "35"
  set_playerbot_value "$config" "AiPlayerbot.RandomClassSpecProb.6.1" "35"
  set_playerbot_value "$config" "AiPlayerbot.RandomClassSpecProb.6.2" "30"
  set_playerbot_value "$config" "AiPlayerbot.RandomClassSpecProb.7.0" "25"
  set_playerbot_value "$config" "AiPlayerbot.RandomClassSpecProb.7.1" "25"
  set_playerbot_value "$config" "AiPlayerbot.RandomClassSpecProb.7.2" "50"
  set_playerbot_value "$config" "AiPlayerbot.RandomClassSpecProb.11.0" "15"
  set_playerbot_value "$config" "AiPlayerbot.RandomClassSpecProb.11.1" "35"
  set_playerbot_value "$config" "AiPlayerbot.RandomClassSpecProb.11.2" "35"
  set_playerbot_value "$config" "AiPlayerbot.RandomClassSpecProb.11.3" "15"
}

apply_dungeon_lfg() {
  local config="$1"
  local bots="${BOT_COUNT:-1500}"
  local min_level="${MIN_LEVEL:-15}"
  local max_level="${MAX_LEVEL:-80}"
  local follow_distance="${FOLLOW_DISTANCE:-2.5}"

  BOT_COUNT="$bots" MIN_LEVEL="$min_level" MAX_LEVEL="$max_level" FOLLOW_DISTANCE="$follow_distance" apply_solo_controller "$config"
  set_playerbot_value "$config" "AiPlayerbot.RandomBotJoinLfg" "1"
  set_playerbot_value "$config" "AiPlayerbot.ApplyInstanceStrategies" "1"
  set_playerbot_value "$config" "AiPlayerbot.SummonWhenGroup" "1"
  apply_role_bias "$config"

  set_playerbot_env "AC_AI_PLAYERBOT_RANDOM_BOT_JOIN_LFG" "1"
  set_playerbot_env "AC_AI_PLAYERBOT_APPLY_INSTANCE_STRATEGIES" "1"
  set_playerbot_env "AC_AI_PLAYERBOT_SUMMON_WHEN_GROUP" "1"
}

apply_pvp_3v3() {
  local config="$1"
  set_playerbot_value "$config" "AiPlayerbot.RandomBotJoinBG" "1"
  set_playerbot_value "$config" "AiPlayerbot.RandomBotAutoJoinBG" "1"
  set_playerbot_value "$config" "AiPlayerbot.RandomBotAutoJoinArenaBracket" "14"
  set_playerbot_value "$config" "AiPlayerbot.RandomBotAutoJoinBGRatedArena3v3Count" "2"
  set_playerbot_value "$config" "AiPlayerbot.RandomBotArenaTeam3v3Count" "40"

  set_playerbot_env "AC_AI_PLAYERBOT_RANDOM_BOT_JOIN_BG" "1"
  set_playerbot_env "AC_AI_PLAYERBOT_RANDOM_BOT_AUTO_JOIN_BG" "1"
  set_playerbot_env "AC_AI_PLAYERBOT_RANDOM_BOT_AUTO_JOIN_ARENA_BRACKET" "14"
  set_playerbot_env "AC_AI_PLAYERBOT_RANDOM_BOT_AUTO_JOIN_BG_RATED_ARENA_3V3_COUNT" "2"
  set_playerbot_env "AC_AI_PLAYERBOT_RANDOM_BOT_ARENA_TEAM_3V3_COUNT" "40"
}

apply_living_server() {
  local config="$1"
  apply_dungeon_lfg "$config"
  apply_pvp_3v3 "$config"
}

list_presets() {
  cat <<'PRESETS'
quiet-social     Disable repeated greetings/emotes while preserving useful bot chat.
solo-controller  Quiet, stable party play for controller/low-friction leveling.
dungeon-lfg      Leveling dungeon density, LFG participation, role-biased specs.
pvp-3v3          Conservative level-80 rated 3v3 seeding.
living-server    Dungeon + PvP + world social defaults.
PRESETS
}

apply_preset() {
  local preset="${1:-}"
  [[ -n "$preset" ]] || die "Missing preset name. Run list-presets."

  local config
  config="$(ensure_playerbots_config)"
  log "Applying preset '$preset' to: $config"

  case "$preset" in
    quiet-social) apply_quiet_social "$config" ;;
    solo-controller) apply_solo_controller "$config" ;;
    dungeon-lfg) apply_dungeon_lfg "$config" ;;
    pvp-3v3) apply_pvp_3v3 "$config" ;;
    living-server) apply_living_server "$config" ;;
    *) die "Unknown preset: $preset" ;;
  esac

  log "Preset '$preset' complete."
  if [[ "$RESTART" == "1" ]]; then
    restart_worldserver
  else
    log "Restart ac-worldserver for config changes to take effect."
  fi
}

docker_compose() {
  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    docker compose "$@"
  elif command -v docker-compose >/dev/null 2>&1; then
    docker-compose "$@"
  else
    return 127
  fi
}

restart_worldserver() {
  require_docker_compose_file
  confirm_or_die "Restart ac-worldserver in $SERVER_DIR?"
  log "Restarting ac-worldserver..."
  if [[ "$DRY_RUN" == "1" ]]; then
    printf '[dry-run] cd %q && docker compose restart ac-worldserver\n' "$SERVER_DIR"
  else
    (cd "$SERVER_DIR" && docker_compose restart ac-worldserver)
  fi
}

rebuild_worldserver() {
  require_docker_compose_file
  confirm_or_die "Rebuild and restart ac-worldserver in $SERVER_DIR?"
  log "Rebuilding ac-worldserver..."
  if [[ "$DRY_RUN" == "1" ]]; then
    printf '[dry-run] cd %q && docker compose up -d --build ac-worldserver\n' "$SERVER_DIR"
  else
    (cd "$SERVER_DIR" && docker_compose up -d --build ac-worldserver)
  fi
}

apply_lfg_patches() {
  require_server_dir
  local module_dir="$SERVER_DIR/modules/mod-playerbots"
  [[ -d "$module_dir" ]] || die "mod-playerbots is not installed at: $module_dir"

  local patch_dir="$REPO_ROOT/patches/playerbots"
  local patches=("$patch_dir"/*.patch)
  [[ -f "${patches[0]:-}" ]] || die "No patch files found in: $patch_dir"

  local patch_file
  for patch_file in "${patches[@]}"; do
    log "Checking $(basename "$patch_file")"
    if (cd "$SERVER_DIR" && git apply --check --recount "$patch_file"); then
      if [[ "$DRY_RUN" == "1" ]]; then
        printf '[dry-run] cd %q && git apply --recount %q\n' "$SERVER_DIR" "$patch_file"
      else
        (cd "$SERVER_DIR" && git apply --recount "$patch_file")
      fi
      log "Applied $(basename "$patch_file")."
    elif (cd "$SERVER_DIR" && git apply --reverse --check --recount "$patch_file"); then
      warn "Already applied: $(basename "$patch_file")"
    else
      die "Could not apply Playerbots patch: $patch_file"
    fi
  done

  if [[ "$REBUILD" == "1" ]]; then
    rebuild_worldserver
  else
    log "Rebuild ac-worldserver for patch changes to take effect."
  fi
}

apply_patches() {
  local patch_set="${1:-}"
  case "$patch_set" in
    lfg) apply_lfg_patches ;;
    *) die "Unknown patch set: ${patch_set:-}. Available patch set: lfg" ;;
  esac
}

grep_config() {
  local config="$1"
  local pattern="$2"
  if [[ -f "$config" ]]; then
    grep -E "$pattern" "$config" || true
  else
    warn "Config file not found: $config"
  fi
}

doctor() {
  require_server_dir
  log "Server directory: $SERVER_DIR"

  if [[ -d "$SERVER_DIR/modules/mod-playerbots" ]]; then
    log "Found mod-playerbots module."
  else
    warn "Could not find $SERVER_DIR/modules/mod-playerbots"
  fi

  local config
  config="$(find_playerbots_config || true)"
  if [[ -n "$config" ]]; then
    log "Found Playerbots config: $config"
    grep_config "$config" '^[[:space:]]*AiPlayerbot\.(EnableGreet|RandomBotEmote|RandomBotSayWithoutMaster|SummonWhenGroup|AllowSummonWhenMasterIsDead|AllowSummonWhenBotIsDead|ReviveBotWhenSummoned|FollowDistance|RandomBotAutologin|MinRandomBots|MaxRandomBots|RandomBotJoinLfg|RandomBotJoinBG|RandomBotAutoJoinBG|RandomBotAutoJoinArenaBracket|RandomBotAutoJoinBGRatedArena3v3Count|RandomBotArenaTeam3v3Count|KeepAltsInGroup|EnablePeriodicOnlineOffline)[[:space:]]*='
  else
    warn "No playerbots.conf found. apply-preset can create one from playerbots.conf.dist."
  fi

  local override
  override="$(compose_override_file)"
  if [[ -f "$override" ]]; then
    log "Found Docker compose override: $override"
    grep -E 'AC_AI_PLAYERBOT_|AC_PLAYERBOTS' "$override" || true
  else
    warn "No docker-compose.override.yml found. The tuner can create one for environment overrides."
  fi

  cat <<'NOTE'

Gameplay notes:
- Repeated nearby greetings are controlled by EnableGreet and RandomBotEmote.
- For stable long-session parties, altbots/addclass bots are safer than roaming randombots.
- If bots lose follow after death/resurrection, use party chat: /p follow
- To hold bots in place for quest objectives, use party chat: /p stay
NOTE
}

diagnose_lfg() {
  require_server_dir
  local config
  config="$(find_playerbots_config || true)"

  log "Playerbots LFG-related config"
  grep_config "$config" '^[[:space:]]*AiPlayerbot\.(RandomBotJoinLfg|ApplyInstanceStrategies|SummonWhenGroup|GroupInvitationPermission|RandomBotAutologin|MinRandomBots|MaxRandomBots|RandomBotMinLevel|RandomBotMaxLevel|SyncLevelWithPlayers|EnableGreet|RandomBotTalk|RandomBotEmote|EnableBroadcasts|RandomBotSayWithoutMaster|FollowDistance|RandomClassSpecProb\.(1|2|5|6|7|11)\.[0-3])[[:space:]]*='

  local override
  override="$(compose_override_file)"
  log "Docker override LFG-related environment"
  if [[ -f "$override" ]]; then
    grep -E 'AC_AI_PLAYERBOT_(RANDOM_BOT_JOIN_LFG|RANDOM_BOT_MIN_LEVEL|RANDOM_BOT_MAX_LEVEL|SYNC_LEVEL_WITH_PLAYERS|APPLY_INSTANCE_STRATEGIES|SUMMON_WHEN_GROUP|MIN_RANDOM_BOTS|MAX_RANDOM_BOTS|FOLLOW_DISTANCE)|AC_PLAYERBOTS' "$override" || true
  else
    warn "No docker-compose.override.yml found."
  fi

  log "Recent worldserver lines mentioning LFG, dungeon, teleport, proposal, or playerbots"
  if [[ "$DRY_RUN" == "1" ]]; then
    printf '[dry-run] cd %q && docker compose logs --since 45m ac-worldserver | grep ...\n' "$SERVER_DIR"
  elif (cd "$SERVER_DIR" && docker_compose ps ac-worldserver >/dev/null 2>&1); then
    (cd "$SERVER_DIR" && docker_compose logs --since "${PLAYERBOTS_LFG_LOG_SINCE:-45m}" ac-worldserver 2>/dev/null \
      | grep -Ei 'playerbot|lfg|dungeon|proposal|role check|teleport|summon|group invite|instance|follow|resurrect|death' \
      | tail -n "${PLAYERBOTS_LFG_LOG_LINES:-240}") || warn "No matching recent log lines found."
  else
    warn "Could not read ac-worldserver logs. Is Docker running and is the server started?"
  fi
}

diagnose_pvp() {
  require_server_dir
  local config
  config="$(find_playerbots_config || true)"

  log "Playerbots BG/arena-related config"
  grep_config "$config" '^[[:space:]]*AiPlayerbot\.(RandomBotJoinBG|RandomBotAutoJoinBG|RandomBotAutoJoinArenaBracket|RandomBotAutoJoinBGRatedArena2v2Count|RandomBotAutoJoinBGRatedArena3v3Count|RandomBotAutoJoinBGRatedArena5v5Count|RandomBotArenaTeam2v2Count|RandomBotArenaTeam3v3Count|RandomBotArenaTeam5v5Count|RandomBotArenaTeamMinRating|RandomBotArenaTeamMaxRating|DeleteRandomBotArenaTeams|MinRandomBots|MaxRandomBots|RandomBotMinLevel|RandomBotMaxLevel|SyncLevelWithPlayers)[[:space:]]*='

  local override
  override="$(compose_override_file)"
  log "Docker override BG/arena-related environment"
  if [[ -f "$override" ]]; then
    grep -E 'AC_AI_PLAYERBOT_(RANDOM_BOT_JOIN_BG|RANDOM_BOT_AUTO_JOIN_BG|RANDOM_BOT_AUTO_JOIN_ARENA_BRACKET|RANDOM_BOT_AUTO_JOIN_BG_RATED_ARENA|RANDOM_BOT_ARENA_TEAM|MIN_RANDOM_BOTS|MAX_RANDOM_BOTS|RANDOM_BOT_MIN_LEVEL|RANDOM_BOT_MAX_LEVEL|SYNC_LEVEL_WITH_PLAYERS)|AC_PLAYERBOTS' "$override" || true
  else
    warn "No docker-compose.override.yml found."
  fi

  log "Recent worldserver lines mentioning arena, battleground, rated queue, or playerbots"
  if [[ "$DRY_RUN" == "1" ]]; then
    printf '[dry-run] cd %q && docker compose logs --since 45m ac-worldserver | grep ...\n' "$SERVER_DIR"
  elif (cd "$SERVER_DIR" && docker_compose ps ac-worldserver >/dev/null 2>&1); then
    (cd "$SERVER_DIR" && docker_compose logs --since "${PLAYERBOTS_PVP_LOG_SINCE:-45m}" ac-worldserver 2>/dev/null \
      | grep -Ei 'playerbot|arena|rated|3v3|2v2|5v5|battleground|battlefield|bg queue|queue.*arena|arena.*queue|skirmish' \
      | tail -n "${PLAYERBOTS_PVP_LOG_LINES:-240}") || warn "No matching recent log lines found."
  else
    warn "Could not read ac-worldserver logs. Is Docker running and is the server started?"
  fi
}

print_macros() {
  cat <<'MACROS'
Useful Playerbots party commands:

/p follow
  Re-assert follow after death, resurrection, summon, or pathing drift.

/p stay
  Hold the party at its current position for quest objectives or careful pulls.

/p follow near
  Tighten follow distance.

/p follow far
  Increase follow distance.

/p follow info
  Ask bots to report follow settings.

/p orders delay 5
  Make bots wait before engaging, useful when a quest needs controlled damage.

/p reset
  Reset bot states, orders, and loot list.

Tip:
  Party chat commands apply to bots in the party. Whisper the same command to one bot
  when you only want a specific bot to obey it.
MACROS
}

main() {
  COMMAND_ARGS=()
  parse_args "$@"
  [[ -n "$COMMAND" ]] || { usage; exit 1; }

  case "$COMMAND" in
    list-presets) list_presets ;;
    apply-preset) apply_preset "${COMMAND_ARGS[@]}" ;;
    apply-patches) apply_patches "${COMMAND_ARGS[@]}" ;;
    doctor) doctor ;;
    diagnose-lfg) diagnose_lfg ;;
    diagnose-pvp) diagnose_pvp ;;
    print-macros) print_macros ;;
    restart) restart_worldserver ;;
    rebuild) rebuild_worldserver ;;
    *) die "Unknown command: $COMMAND" ;;
  esac
}

main "$@"
