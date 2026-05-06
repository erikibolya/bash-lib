#!/usr/bin/env bash
set -euo pipefail

source "${BASH_SOURCE%/*}/../core.sh"

dependencies "python3"

DEFAULT_CONFIG="${MY_SSH_CONFIG:-$HOME/.ssh/servers.yaml}"

usage() {
    cat <<USAGE
Usage:
  my-ssh --list [--config PATH]
  my-ssh [--config PATH] [--dry-run] [--open] <server> [extra ssh args]
  
Examples:
  ./my-ssh.sh --list
  ./my-ssh.sh production
  ./my-ssh.sh production -N -L 0.0.0.0:9000:172.17.0.1:9000
  ./my-ssh.sh --config my-ssh-example.yaml bastion -A

Options:
  --list         List configured servers and exit
  --config PATH  Path to YAML config (default: ${DEFAULT_CONFIG})
  --dry-run      Print resolved ssh command and exit
  --open         If -N and -L are used, open detected local URL in browser
  -h, --help     Show this help
USAGE
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "Error: required command not found: $1" >&2
        exit 1
    }
}

# --- ROBUST SSH-AGENT HELPER ---
# Ensures the private key is loaded into an agent socket[cite: 1]
ensure_ssh_agent() {
    local key_path="$1"
    [[ -z "$key_path" || ! -f "$key_path" ]] && return 0

    local agent_sock="/tmp/ssh-agent-$(id -u).sock"
    export SSH_AUTH_SOCK="$agent_sock"

    local rc=0
    ssh-add -l >/dev/null 2>&1 || rc=$?

    if [[ "$rc" -eq 2 ]]; then
        rm -rf "$agent_sock"
        if ! ssh-agent -a "$agent_sock" >/dev/null; then
            echo "Error: Failed to start ssh-agent process." >&2
            return 1
        fi
        
        local timeout=10
        while [[ ! -S "$agent_sock" ]]; do
            if (( timeout-- <= 0 )); then
                echo "Error: Timeout waiting for socket $agent_sock" >&2
                return 1
            fi
            sleep 0.2
        done
    fi

    local key_fp
    key_fp=$(ssh-keygen -lf "$key_path" | awk '{print $2}')
    
    if ! ssh-add -l 2>/dev/null | grep -q "$key_fp"; then
        echo "Key not in agent. Adding: $key_path"
        ssh-add "$key_path"
    fi
}

# --- YAML PARSER VIA PYTHON ---
# Calls Python to parse the YAML inventory file[cite: 1]
py_yaml() {
    local mode="$1"
    local config="$2"
    local name="${3:-}"
    local field="${4:-}"
    python3 - "$mode" "$config" "$name" "$field" <<'PY'
import os, sys
try:
    import yaml
except ImportError:
    print("Python module 'yaml' is missing. Install it with: sudo apt install python3-yaml", file=sys.stderr)
    sys.exit(3)

mode, config, name, field = sys.argv[1:5]
path = os.path.expanduser(config)
if not os.path.exists(path):
    print(f"Config file does not exist: {path}", file=sys.stderr)
    sys.exit(2)

with open(path, 'r', encoding='utf-8') as f:
    data = yaml.safe_load(f) or {}

if not isinstance(data, dict):
    print("Top-level YAML structure must be a mapping.", file=sys.stderr)
    sys.exit(2)

servers = data.get('servers', {})
if not isinstance(servers, dict):
    print("'servers' must be a mapping.", file=sys.stderr)
    sys.exit(2)

if mode == 'list':
    for key in sorted(servers.keys()):
        raw = servers.get(key) or {}
        if not isinstance(raw, dict):
            continue
        host = raw.get('host', '')
        user = raw.get('user') or ''
        port = raw.get('port')
        desc = raw.get('desc') or raw.get('label') or ''
        proxyjump = raw.get('proxyjump') or ''
        target = f"{user + '@' if user else ''}{host}{':' + str(port) if port else ''}"
        extras = []
        if proxyjump:
            extras.append(f"jump via {proxyjump}")
        if desc:
            extras.append(desc)
        if extras:
            print(f"{key}\t{target}\t{' | '.join(extras)}")
        else:
            print(f"{key}\t{target}")
    sys.exit(0)

raw = servers.get(name)
if raw is None:
    sys.exit(4)
if not isinstance(raw, dict):
    print(f"Server '{name}' must be a mapping.", file=sys.stderr)
    sys.exit(2)

host = raw.get('host')
if not host:
    print(f"Server '{name}' is missing required field 'host'.", file=sys.stderr)
    sys.exit(2)

value = raw.get(field)
if value is None:
    sys.exit(0)
print(value)
PY
}

# Displays a list of all configured servers[cite: 1]
list_servers() {
    local config="$1"
    local lines
    if ! lines="$(py_yaml list "$config")"; then
        return 1
    fi

    if [[ -z "$lines" ]]; then
        echo "No servers found."
        return 1
    fi

    cecho "$CYAN" "Available servers:"
    echo
    while IFS=$'\t' read -r name target details; do
        [[ -z "$name" ]] && continue
        if [[ -n "${details:-}" ]]; then
            printf "  ${GREEN}%-20s${RESET} %s — %s\n" "$name" "$target" "$details"
        else
            printf "  ${GREEN}%-20s${RESET} %s\n" "$name" "$target"
        fi
    done <<< "$lines"
}

# Extracts the first valid local forward spec (-L) from arguments[cite: 1, 2]
extract_local_forward_spec() {
    local i=1
    while [[ $i -le $# ]]; do
        local arg="${!i}"
        local value=""
        
        # Handle both -L value and -Lvalue syntax[cite: 1]
        if [[ "$arg" == "-L" ]]; then
            ((i++))
            [[ $i -le $# ]] && value="${!i}"
        elif [[ "$arg" == -L* ]]; then
            value="${arg#-L}"
        fi

        if [[ -n "$value" ]]; then
            # Case 1: bind_address:port:remote_host:remote_port (4 parts)[cite: 1, 2]
            if [[ "$value" =~ ^([^:]+):([0-9]+):[^:]+:[0-9]+$ ]]; then
                printf '%s\t%s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
                return 0
            # Case 2: port:remote_host:remote_port (3 parts)[cite: 1, 2]
            elif [[ "$value" =~ ^([0-9]+):[^:]+:[0-9]+$ ]]; then
                printf '\t%s\n' "${BASH_REMATCH[1]}"
                return 0
            fi
        fi
        ((i++))
    done
    return 1
}

# Waits for a local port to become active[cite: 1]
wait_for_local_port() {
    local host="$1" port="$2" timeout="${3:-5}"
    python3 - "$host" "$port" "$timeout" <<'PY'
import socket, sys, time
host = sys.argv[1]
port = int(sys.argv[2])
timeout = float(sys.argv[3])
deadline = time.time() + timeout
while time.time() < deadline:
    try:
        with socket.create_connection((host, port), timeout=0.5):
            sys.exit(0)
    except OSError:
        time.sleep(0.1)
sys.exit(1)
PY
}

# Detects whether the local port is HTTP or HTTPS[cite: 1]
detect_local_url_scheme() {
    local host="$1" port="$2"
    python3 - "$host" "$port" <<'PY'
import socket, ssl, sys
host = sys.argv[1]
port = int(sys.argv[2])
try:
    context = ssl.create_default_context()
    context.check_hostname = False
    context.verify_mode = ssl.CERT_NONE
    with socket.create_connection((host, port), timeout=1.5) as sock:
        with context.wrap_socket(sock, server_hostname='localhost'):
            print('https')
            sys.exit(0)
except ssl.SSLError:
    print('http')
except OSError:
    print('http')
PY
}

open_url() {
    local url="$1"
    if command -v xdg-open >/dev/null 2>&1; then
        xdg-open "$url" >/dev/null 2>&1 &
    elif command -v open >/dev/null 2>&1; then
        open "$url" >/dev/null 2>&1 &
    else
        echo "Warning: no browser opener found (xdg-open/open)." >&2
        return 1
    fi
}

quote_args() {
    local out="" part
    for part in "$@"; do
        printf -v out '%s %q' "$out" "$part"
    done
    printf '%s\n' "${out# }"
}

# --- MAIN LOGIC ---
main() {
    require_cmd ssh
    require_cmd python3

    local config="$DEFAULT_CONFIG"
    local do_list=0 dry_run=0 do_open=0
    local server=""
    local -a extra_ssh_args=()

    while (($#)); do
        case "$1" in
            --list) do_list=1; shift ;;
            --dry-run) dry_run=1; shift ;;
            --open) do_open=1; shift ;;
            --config)
                [[ $# -ge 2 ]] || { echo "Error: --config requires a path" >&2; exit 1; }
                config="$2"
                shift 2 ;;
            --help|-h) usage; exit 0 ;;
            --) shift; break ;;
            -*) echo "Error: unknown option: $1" >&2; usage >&2; exit 1 ;;
            *) break ;;
        esac
    done

    if (( do_list )); then
        list_servers "$config"
        exit $?
    fi

    [[ $# -ge 1 ]] || { usage >&2; exit 1; }
    server="$1"
    shift
    extra_ssh_args=("$@")

    local host user key port proxyjump
    if ! host="$(py_yaml get "$config" "$server" host)"; then
        rc=$?
        if [[ $rc -eq 4 ]]; then
            echo "Error: server '$server' was not found in $config" >&2
            list_servers "$config" >&2 || true
            exit 1
        fi
        exit "$rc"
    fi
    user="$(py_yaml get "$config" "$server" user || true)"
    key="$(py_yaml get "$config" "$server" key || true)"
    port="$(py_yaml get "$config" "$server" port || true)"
    proxyjump="$(py_yaml get "$config" "$server" proxyjump || true)"

    key="${key/#\~/$HOME}"

    if [[ -n "$key" ]] && [[ "$dry_run" -eq 0 ]]; then
        ensure_ssh_agent "$key"
    fi

    local -a command=(ssh)
    [[ -n "$port" ]] && command+=(-p "$port")
    [[ -n "$proxyjump" ]] && command+=(-J "$proxyjump")
    [[ -n "$user" ]] && command+=(-l "$user")
    [[ -n "$key" ]] && command+=(-i "$key")
    command+=("${extra_ssh_args[@]}")
    command+=("$host")

    cecho "$GREEN" "Resolved command:"
    echo "  $(quote_args "${command[@]}")"

    local lspec local_bind local_port browser_host test_host scheme url has_N=0
    for arg in "${extra_ssh_args[@]}"; do
        [[ "$arg" == "-N" ]] && has_N=1
    done

    # Extract tunnel spec and check for success[cite: 1]
    if lspec=$(extract_local_forward_spec "${extra_ssh_args[@]}"); then
        IFS=$'\t' read -r local_bind local_port <<< "$lspec"
        
        # Map 0.0.0.0 to localhost for browser usage[cite: 2]
        browser_host="${local_bind:-localhost}"
        [[ "$browser_host" == "0.0.0.0" ]] && browser_host="localhost"
        
        # Use 127.0.0.1 for internal port connectivity checks[cite: 1]
        test_host="$browser_host"
        [[ "$test_host" == "localhost" ]] && test_host="127.0.0.1"

        if (( dry_run )); then
            echo "Potential local URL: http(s)://${browser_host}:${local_port}/"
            exit 0
        fi

        if (( has_N )); then
            "${command[@]}" &
            local ssh_pid=$!
            trap 'kill "$ssh_pid" >/dev/null 2>&1 || true' EXIT

            if wait_for_local_port "$test_host" "$local_port" 5; then
                scheme="$(detect_local_url_scheme "$test_host" "$local_port")"
                url="${scheme}://${browser_host}:${local_port}/"
                
                cecho "$CYAN" "Tunnel ready: $url"
                
                if (( do_open )); then
                    open_url "$url" || true
                fi
            else
                echo "Tunnel started, but local port ${local_port} on ${browser_host} did not become ready." >&2
            fi

            wait "$ssh_pid"
            trap - EXIT
            return $?
        fi
    fi

    if (( dry_run )); then
        exit 0
    fi

    exec "${command[@]}"
}

main "$@"