#!/usr/bin/env bash

set -u

# Resolve repository root from this script location.
DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
FYAML="$DIR/linked-files.yaml"
YAML_PARSER=""
MODE="${1:-install}"
MODE_ARG="${2:-}"
STUB_END_MARKER="# env-files: managed-stub-end"
DRY_RUN=0
ALLOW_DEP_INSTALL=1

_check() { type "$@" >/dev/null 2>&1; }

_print_help() {
  cat <<'EOF'
Usage:
  gen-symlinks.sh [mode] [arg]

Modes:
  install                      Default mode. Apply links/stubs/copies from linked-files.yaml.
  --dry-run                    Simulate install actions without writing changes.
  --check-stub-drift           Check for non-empty content after managed stub marker.
  --ack-stub-drift [path|all]  Append a fresh managed marker to one file or all stub targets.
  --prune-backups [days]       Delete backup run directories older than N days (default: 30).
  --help                       Show this help text.

Dependency control:
  --no-install-deps            Do not attempt to install YAML parser dependencies.
  --install-deps               Force dependency auto-install behavior (default).

Examples:
  ./gen-symlinks.sh
  ./gen-symlinks.sh --dry-run
  ./gen-symlinks.sh --check-stub-drift
  ./gen-symlinks.sh --ack-stub-drift "$HOME/.bashrc"
  ./gen-symlinks.sh --prune-backups 14
  ./gen-symlinks.sh --no-install-deps
EOF
}

_log_action() {
  echo "DRY-RUN: $*" >&2
}

_expand_path_expr() {
  local expr="$1"
  expr="${expr//\$\{HOME\}/$HOME}"
  expr="${expr//\$HOME/$HOME}"
  expr="${expr//\$\{USER\}/$USER}"
  expr="${expr//\$USER/$USER}"
  case "$expr" in
    "~/"*) expr="${HOME}/${expr#~/}" ;;
    "~") expr="$HOME" ;;
  esac
  printf '%s\n' "$expr"
}

DATE_FORMAT=%Y%m%d%H%M
RUN_STAMP="$(date +"$DATE_FORMAT")-$RANDOM"
BACKUP_ROOT="${ENV_FILES_BACKUP_ROOT:-$HOME/.env-files-backups}"
BACKUP_DIR="$BACKUP_ROOT/$RUN_STAMP"
BACKUP_COUNT=0

_backup_destination_for() {
  local target="$1"
  local rel
  case "$target" in
    "$HOME"/*) rel="${target#"$HOME"/}" ;;
    /*) rel="${target#/}" ;;
    *) rel="$target" ;;
  esac
  printf '%s/%s\n' "$BACKUP_DIR" "$rel"
}

_backup_path() {
  local target="$1"
  local backup_path
  test -e "$target" || test -L "$target" || return 0
  backup_path="$(_backup_destination_for "$target")"
  if test "$DRY_RUN" -eq 1; then
    _log_action "backup '$target' -> '$backup_path'"
    return 0
  fi
  mkdir -p "$(dirname "$backup_path")"
  mv "$target" "$backup_path"
  BACKUP_COUNT=$((BACKUP_COUNT + 1))
}

_ensure_parent_dir() {
  local dest="$1"
  local parent
  parent="$(dirname "$dest")"
  if ! test -d "$parent"; then
    if test "$DRY_RUN" -eq 1; then
      _log_action "mkdir -p '$parent'"
    else
      mkdir -p "$parent"
    fi
  fi
}

_ensure_line_in_file() {
  local file_path="$1"
  local line="$2"
  _ensure_parent_dir "$file_path"
  test -e "$file_path" || {
    if test "$DRY_RUN" -eq 1; then
      _log_action "create file '$file_path'"
    else
      : > "$file_path"
    fi
  }
  rg -F -q -- "$line" "$file_path" || {
    if test "$DRY_RUN" -eq 1; then
      _log_action "append line to '$file_path': $line"
    else
      printf '\n%s\n' "$line" >> "$file_path"
    fi
  }
}

_ensure_env_repo_source_hooks() {
  local source_line='. "$HOME/.set_env_repo"'
  _ensure_line_in_file "$HOME/.profile" "$source_line"

  if _check bash; then
    _ensure_line_in_file "$HOME/.bash_profile" "$source_line"
    _ensure_line_in_file "$HOME/.bashrc" "$source_line"
  fi
  if _check zsh; then
    _ensure_line_in_file "$HOME/.zprofile" "$source_line"
    _ensure_line_in_file "$HOME/.zshrc" "$source_line"
  fi
}

_is_windows_host() {
  case "$(uname -s 2>/dev/null || echo unknown)" in
    CYGWIN*|MINGW*|MSYS*) return 0 ;;
    *) return 1 ;;
  esac
}

_to_windows_path() {
  local path_="$1"
  if _check cygpath; then
    cygpath -w "$path_"
    return 0
  fi
  printf '%s\n' "$path_"
}

_run_windows_cmd() {
  env MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' \
    cmd.exe /c "$1"
}

_run_windows_powershell() {
  env MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' \
    powershell.exe -NoProfile -NonInteractive -Command "$1"
}

_install_windows_link_fallback() {
  local src="$1"
  local dest="$2"
  local src_win dest_win

  src_win="$(_to_windows_path "$src")"
  dest_win="$(_to_windows_path "$dest")"

  # Junctions generally work for directories without symlink privilege.
  if test -d "$src"; then
    if _check powershell.exe; then
      _run_windows_powershell \
        "New-Item -ItemType Junction -Path '$dest_win' -Target '$src_win' -Force | Out-Null" \
        >/dev/null 2>&1 && return 0
    fi
    _run_windows_cmd "mklink /J \"$dest_win\" \"$src_win\"" >/dev/null 2>&1 && return 0
  else
    # Hard links can be a useful file fallback when symlink privilege is missing.
    if _check powershell.exe; then
      _run_windows_powershell \
        "New-Item -ItemType HardLink -Path '$dest_win' -Target '$src_win' -Force | Out-Null" \
        >/dev/null 2>&1 && return 0
    fi
    _run_windows_cmd "mklink /H \"$dest_win\" \"$src_win\"" >/dev/null 2>&1 && return 0
  fi

  return 1
}

_install_symlink() {
  local src="$1"
  local dest="$2"
  _ensure_parent_dir "$dest"
  if test -L "$dest"; then
    local current_target
    current_target="$(readlink "$dest" || true)"
    if test "$current_target" = "$src"; then
      return 0
    fi
  elif test -e "$dest"; then
    _backup_path "$dest"
  fi
  if test "$DRY_RUN" -eq 1; then
    _log_action "ln -sfn '$src' '$dest'"
    return 0
  fi
  ln -sfn "$src" "$dest" && return 0

  # On Windows shells, fallback to Windows-native link types only when symlink failed.
  if _is_windows_host; then
    echo "WARNING: symlink failed for '$dest'; trying Windows-native fallback link type." >&2
    _install_windows_link_fallback "$src" "$dest" && return 0
  fi

  return 1
}

_install_copy() {
  local src="$1"
  local dest="$2"
  _ensure_parent_dir "$dest"
  if test -d "$src"; then
    if test -e "$dest" || test -L "$dest"; then
      _backup_path "$dest"
    fi
    if test "$DRY_RUN" -eq 1; then
      _log_action "cp -R '$src' '$dest'"
    else
      cp -R "$src" "$dest"
    fi
  else
    if test -e "$dest" || test -L "$dest"; then
      cmp -s "$src" "$dest" && return 0
      _backup_path "$dest"
    fi
    if test "$DRY_RUN" -eq 1; then
      _log_action "cp '$src' '$dest'"
    else
      cp "$src" "$dest"
    fi
  fi
}

_stub_line_for() {
  local src="$1"
  local type_="$2"
  local format_="$3"
  if test "$format_" = "vimscript"; then
    printf 'source %s\n' "$src"
  elif test "$type_" = "script_file"; then
    printf '. "%s"\n' "$src"
  else
    printf '# managed by env-files\n# source: %s\n' "$src"
  fi
}

_render_stub_block() {
  local line="$1"
  local stamp
  stamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  printf '# managed by env-files\n'
  printf '%s' "$line"
  printf '# env-files: managed-stub-ts %s\n' "$stamp"
  printf '%s\n' "$STUB_END_MARKER"
}

_install_source_stub() {
  local src="$1"
  local dest="$2"
  local type_="$3"
  local format_="$4"
  local line
  line="$(_stub_line_for "$src" "$type_" "$format_")"
  _ensure_parent_dir "$dest"

  if test -L "$dest"; then
    _backup_path "$dest"
  elif test -s "$dest"; then
    # Keep local edits, only ensure the include line exists.
    if rg -F -q -- "$line" "$dest" && rg -F -q -- "$STUB_END_MARKER" "$dest"; then
      return 0
    fi
    echo "WARNING: existing file '$dest' has content; appending managed stub block." >&2
    if test "$DRY_RUN" -eq 1; then
      _log_action "append managed source_stub block to '$dest'"
    else
      printf '\n' >> "$dest"
      _render_stub_block "$line" >> "$dest"
    fi
    return 0
  fi

  if test "$DRY_RUN" -eq 1; then
    _log_action "write managed source_stub block to '$dest'"
  else
    _render_stub_block "$line" > "$dest"
  fi
}

_install_append_stub() {
  local src="$1"
  local dest="$2"
  local type_="$3"
  local format_="$4"
  local line
  line="$(_stub_line_for "$src" "$type_" "$format_")"
  _ensure_parent_dir "$dest"
  test -e "$dest" || {
    if test "$DRY_RUN" -eq 1; then
      _log_action "create file '$dest'"
    else
      : > "$dest"
    fi
  }
  rg -F -q -- "$line" "$dest" || {
    if test "$DRY_RUN" -eq 1; then
      _log_action "append managed append_stub block to '$dest'"
    else
      printf '\n' >> "$dest"
      _render_stub_block "$line" >> "$dest"
    fi
  }
}

_apply_install() {
  local install="$1"
  local src="$2"
  local dest="$3"
  local type_="$4"
  local format_="$5"

  case "$install" in
    symlink) _install_symlink "$src" "$dest" ;;
    copy) _install_copy "$src" "$dest" ;;
    source_stub) _install_source_stub "$src" "$dest" "$type_" "$format_" ;;
    append_stub) _install_append_stub "$src" "$dest" "$type_" "$format_" ;;
    *)
      echo "Unknown install strategy '$install' for '$dest'." >&2
      return 1
      ;;
  esac
}

_default_install_for_type() {
  local type_="$1"
  case "$type_" in
    directory) printf 'symlink' ;;
    script_file) printf 'source_stub' ;;
    *) printf 'symlink' ;;
  esac
}

_read_yaml_value() {
  local path_="$1"
  _yaml_get_value "$path_"
}

_yaml_keys() {
  local path_="${1:-}"
  case "$YAML_PARSER" in
    shyaml)
      if test -n "$path_"; then
        shyaml keys "$path_" < "$FYAML" 2>/dev/null || true
      else
        shyaml keys < "$FYAML" 2>/dev/null || true
      fi
      ;;
    yq)
      if test -n "$path_"; then
        yq -r ".${path_} | keys | .[]" "$FYAML" 2>/dev/null || true
      else
        yq -r 'keys | .[]' "$FYAML" 2>/dev/null || true
      fi
      ;;
    ruby)
      ruby - <<'RUBY' "$FYAML" "$path_"
fyaml = ARGV[0]
path = ARGV[1]
require 'yaml'
data = YAML.load_file(fyaml)
node = data
unless path.nil? || path.empty?
  path.split('.').each do |k|
    node = node.is_a?(Hash) ? node[k] : nil
    break if node.nil?
  end
end
if node.is_a?(Hash)
  node.keys.each { |k| puts k }
end
RUBY
      ;;
    python)
      python3 - <<'PY' "$FYAML" "$path_"
import sys
import yaml

fyaml = sys.argv[1]
path = sys.argv[2]
with open(fyaml, "r", encoding="utf-8") as f:
    data = yaml.safe_load(f) or {}

node = data
if path:
    for key in path.split("."):
        node = node.get(key) if isinstance(node, dict) else None
        if node is None:
            break

if isinstance(node, dict):
    for k in node.keys():
        print(k)
PY
      ;;
    *)
      return 1
      ;;
  esac
}

_yaml_get_value() {
  local path_="$1"
  case "$YAML_PARSER" in
    shyaml)
      shyaml get-value "$path_" < "$FYAML" 2>/dev/null || true
      ;;
    yq)
      yq -r ".${path_} // \"\"" "$FYAML" 2>/dev/null || true
      ;;
    ruby)
      ruby - <<'RUBY' "$FYAML" "$path_"
fyaml = ARGV[0]
path = ARGV[1]
require 'yaml'
data = YAML.load_file(fyaml)
node = data
path.split('.').each do |k|
  node = node.is_a?(Hash) ? node[k] : nil
  break if node.nil?
end
case node
when nil
  puts ""
when TrueClass
  puts "true"
when FalseClass
  puts "false"
else
  puts node.to_s
end
RUBY
      ;;
    python)
      python3 - <<'PY' "$FYAML" "$path_"
import sys
import yaml

fyaml = sys.argv[1]
path = sys.argv[2]
with open(fyaml, "r", encoding="utf-8") as f:
    data = yaml.safe_load(f) or {}

node = data
for key in path.split("."):
    node = node.get(key) if isinstance(node, dict) else None
    if node is None:
        break

if node is None:
    print("")
elif isinstance(node, bool):
    print("true" if node else "false")
else:
    print(str(node))
PY
      ;;
    *)
      return 1
      ;;
  esac
}

_init_yaml_parser() {
  if _check shyaml; then
    YAML_PARSER="shyaml"
    return 0
  fi
  if _check yq; then
    YAML_PARSER="yq"
    return 0
  fi
  if _check python3 && python3 - <<'PY' >/dev/null 2>&1
import yaml
PY
  then
    YAML_PARSER="python"
    return 0
  fi
  if _check ruby; then
    YAML_PARSER="ruby"
    return 0
  fi
  return 1
}

_minimal_fallback_install() {
  echo "Using minimal fallback install (no YAML parser available)." >&2

  # Always useful baseline links/stubs.
  _apply_install symlink "$DIR" "$HOME/.env-files" directory ""
  _apply_install source_stub "$DIR/src/profile" "$HOME/.profile" script_file ""
  _apply_install source_stub "$DIR/src/rc" "$HOME/.rc" script_file ""

  # Shell-specific startup files when shell exists and source file is present.
  if _check bash; then
    test -e "$DIR/src/bashrc" &&
      _apply_install source_stub "$DIR/src/bashrc" "$HOME/.bashrc" script_file ""
    test -e "$DIR/src/bash.profile" &&
      _apply_install source_stub "$DIR/src/bash.profile" "$HOME/.bash_profile" script_file ""
  fi
  if _check zsh; then
    test -e "$DIR/src/zshrc" &&
      _apply_install source_stub "$DIR/src/zshrc" "$HOME/.zshrc" script_file ""
    test -e "$DIR/src/zprofile" &&
      _apply_install source_stub "$DIR/src/zprofile" "$HOME/.zprofile" script_file ""
  fi
}

_stub_has_nonempty_after_marker() {
  local file_path="$1"
  awk -v marker="$STUB_END_MARKER" '
    $0 == marker { last = NR }
    { lines[NR] = $0 }
    END {
      if (!last) exit 2
      for (i = last + 1; i <= NR; i++) {
        if (lines[i] !~ /^[[:space:]]*$/) exit 0
      }
      exit 1
    }
  ' "$file_path"
}

_iter_stub_targets_from_yaml() {
  local keys_ k f to_expr type_ install dest
  keys_="$(_yaml_keys)"
  while read -r k; do
    test -n "$k" || continue
    _check "$k" || continue
    while read -r f; do
      test -n "$f" || continue
      to_expr="$(_read_yaml_value "$k.$f.to")"
      type_="$(_read_yaml_value "$k.$f.type")"
      install="$(_read_yaml_value "$k.$f.install")"
      test -n "$to_expr" || continue
      test -n "$type_" || type_="config_file"
      test -n "$install" || install="$(_default_install_for_type "$type_")"
      case "$install" in
        source_stub|append_stub)
          dest="$(_expand_path_expr "$to_expr")"
          printf '%s\n' "$dest"
          ;;
      esac
    done < <(_yaml_keys "$k")
  done < <(printf '%s\n' "$keys_")
}

_check_stub_drift_mode() {
  local checked=0 drifted=0 file
  if test -n "$YAML_PARSER" && test -s "$FYAML"; then
    while read -r file; do
      test -n "$file" || continue
      test -e "$file" || continue
      checked=$((checked + 1))
      if _stub_has_nonempty_after_marker "$file"; then
        echo "DRIFT: non-empty content after managed marker in '$file'" >&2
        drifted=$((drifted + 1))
      else
        rc=$?
        if test "$rc" -eq 2; then
          echo "INFO: no managed marker found in '$file' (legacy/manual file)." >&2
        fi
      fi
    done < <(_iter_stub_targets_from_yaml | awk '!seen[$0]++')
  else
    echo "Unable to parse YAML; checking minimal known stub targets only." >&2
    for file in "$HOME/.profile" "$HOME/.rc" "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.zshrc" "$HOME/.zprofile"; do
      test -e "$file" || continue
      checked=$((checked + 1))
      if _stub_has_nonempty_after_marker "$file"; then
        echo "DRIFT: non-empty content after managed marker in '$file'" >&2
        drifted=$((drifted + 1))
      fi
    done
  fi

  if test "$drifted" -gt 0; then
    echo "Checked $checked stub file(s); found $drifted drift issue(s)." >&2
    return 1
  fi
  echo "Checked $checked stub file(s); no drift after managed marker." >&2
  return 0
}

_write_ack_marker() {
  local file_path="$1"
  local stamp
  stamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  test -e "$file_path" || {
    if test "$DRY_RUN" -eq 1; then
      _log_action "create file '$file_path'"
    else
      : > "$file_path"
    fi
  }
  if test "$DRY_RUN" -eq 1; then
    _log_action "append ack marker to '$file_path'"
  else
    printf '\n# env-files: managed-stub-ts %s\n%s\n' "$stamp" "$STUB_END_MARKER" >> "$file_path"
  fi
  echo "ACK: wrote new managed marker in '$file_path'" >&2
}

_ack_stub_drift_mode() {
  local target="${1:-all}"
  local file

  if test "$target" != "all"; then
    _write_ack_marker "$target"
    return 0
  fi

  if test -n "$YAML_PARSER" && test -s "$FYAML"; then
    while read -r file; do
      test -n "$file" || continue
      test -e "$file" || continue
      _write_ack_marker "$file"
    done < <(_iter_stub_targets_from_yaml | awk '!seen[$0]++')
  else
    echo "Unable to parse YAML; acknowledging minimal known stub targets only." >&2
    for file in "$HOME/.profile" "$HOME/.rc" "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.zshrc" "$HOME/.zprofile"; do
      test -e "$file" || continue
      _write_ack_marker "$file"
    done
  fi
}

_prune_backups_mode() {
  local days="${1:-30}"
  local pruned=0
  local d

  case "$days" in
    ''|*[!0-9]*)
      echo "Invalid prune value '$days'. Use a non-negative integer day count." >&2
      return 2
      ;;
  esac

  test -d "$BACKUP_ROOT" || {
    echo "No backup root found at '$BACKUP_ROOT'; nothing to prune." >&2
    return 0
  }

  while read -r d; do
    test -n "$d" || continue
    if test "$DRY_RUN" -eq 1; then
      _log_action "rm -rf '$d'"
    else
      rm -rf "$d"
    fi
    pruned=$((pruned + 1))
  done < <(find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d -mtime +"$days")

  if test "$DRY_RUN" -eq 1; then
    echo "DRY-RUN: would prune $pruned backup directorie(s) older than $days day(s) from '$BACKUP_ROOT'." >&2
  else
    echo "Pruned $pruned backup directorie(s) older than $days day(s) from '$BACKUP_ROOT'." >&2
  fi
}

if test "$MODE" = "--help"; then
  _print_help
  exit 0
fi

if test "$MODE" = "--no-install-deps"; then
  ALLOW_DEP_INSTALL=0
  MODE="install"
fi
if test "$MODE" = "--install-deps"; then
  ALLOW_DEP_INSTALL=1
  MODE="install"
fi

_init_yaml_parser || {
  if test "$ALLOW_DEP_INSTALL" -eq 1; then
    # Prefer PyYAML when Python is available.
    { _check pip3 && pip3 install pyyaml; } ||
    { _check pip && pip install pyyaml; } ||
    { _check pip && pip install shyaml; } ||
    { _check brew && brew install shyaml; } ||
    { _check pip3 && pip3 install shyaml; }
    _init_yaml_parser || true
  else
    echo "YAML parser not available and dependency auto-install is disabled." >&2
  fi
}

if test "$MODE" = "--check-stub-drift"; then
  _check_stub_drift_mode
  exit $?
fi
if test "$MODE" = "--ack-stub-drift"; then
  _ack_stub_drift_mode "${MODE_ARG:-all}"
  exit $?
fi
if test "$MODE" = "--dry-run"; then
  DRY_RUN=1
  MODE="install"
fi
if test "$MODE" = "--prune-backups"; then
  _prune_backups_mode "${MODE_ARG:-30}"
  exit $?
fi

if test "$DRY_RUN" -eq 1; then
  _log_action "write '$HOME/.set_env_repo' with ENV_REPO export"
else
  cat > "${HOME}/.set_env_repo" <<EOF
export ENV_REPO=${DIR}/src
EOF
fi
_ensure_env_repo_source_hooks

if test -n "$YAML_PARSER" && test -s "$FYAML"; then
  keys_="$(_yaml_keys)"
  while read -r k; do
    test -n "$k" || continue
    _check "$k" || continue
    while read -r f; do
      test -n "$f" || continue
      from_rel="$(_read_yaml_value "$k.$f.from")"
      to_expr="$(_read_yaml_value "$k.$f.to")"
      type_="$(_read_yaml_value "$k.$f.type")"
      format_="$(_read_yaml_value "$k.$f.format")"
      install="$(_read_yaml_value "$k.$f.install")"

      test -n "$from_rel" || continue
      test -n "$to_expr" || continue

      src="$DIR/$from_rel"
      dest="$(_expand_path_expr "$to_expr")"
      test -n "$type_" || type_="config_file"
      test -n "$install" || install="$(_default_install_for_type "$type_")"

      if ! test -e "$src"; then
        echo "Skipping missing source: $src" >&2
        continue
      fi

      _apply_install "$install" "$src" "$dest" "$type_" "$format_"
    done < <(_yaml_keys "$k")
  done < <(printf '%s\n' "$keys_")
else
  >&2 echo "Unable to read links from '$FYAML' with available parsers."
  _minimal_fallback_install
fi

# Default behavior: always warn on stub drift after install/update runs.
if ! _check_stub_drift_mode; then
  >&2 echo "WARNING: stub drift detected. Review files, then run --ack-stub-drift when done."
fi

if test "$DRY_RUN" -eq 1; then
  >&2 echo "DRY-RUN: backups would be written under '$BACKUP_DIR'"
elif test "$BACKUP_COUNT" -gt 0; then
  >&2 echo "=> $BACKUP_COUNT backup file(s) saved under '$BACKUP_DIR'"
fi

