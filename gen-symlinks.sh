#!/usr/bin/env bash

set -u

# Resolve repository root from this script location.
DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
FYAML="$DIR/linked-files.yaml"
YAML_PARSER=""

_check() { type "$@" >/dev/null 2>&1; }

DATE_FORMAT=%Y%m%d%H%M
BACKUP_SUFFIX="~$(date +"$DATE_FORMAT")-$RANDOM"
while test 0 -ne "$(find "$HOME" -maxdepth 1 -name "*${BACKUP_SUFFIX}" | wc -l)"; do
  BACKUP_SUFFIX="~$(date +"$DATE_FORMAT")-$RANDOM"
done

_backup_path() {
  local target="$1"
  test -e "$target" || test -L "$target" || return 0
  mv "$target" "${target}${BACKUP_SUFFIX}"
}

_ensure_parent_dir() {
  local dest="$1"
  local parent
  parent="$(dirname "$dest")"
  test -d "$parent" || mkdir -p "$parent"
}

_ensure_line_in_file() {
  local file_path="$1"
  local line="$2"
  _ensure_parent_dir "$file_path"
  test -e "$file_path" || : > "$file_path"
  rg -F -q -- "$line" "$file_path" || printf '\n%s\n' "$line" >> "$file_path"
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
  ln -sfn "$src" "$dest"
}

_install_copy() {
  local src="$1"
  local dest="$2"
  _ensure_parent_dir "$dest"
  if test -d "$src"; then
    if test -e "$dest" || test -L "$dest"; then
      _backup_path "$dest"
    fi
    cp -R "$src" "$dest"
  else
    if test -e "$dest" || test -L "$dest"; then
      cmp -s "$src" "$dest" && return 0
      _backup_path "$dest"
    fi
    cp "$src" "$dest"
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
    if rg -F -q -- "$line" "$dest"; then
      return 0
    fi
  fi

  {
    printf '# managed by env-files\n'
    printf '%s' "$line"
  } > "$dest"
}

_install_append_stub() {
  local src="$1"
  local dest="$2"
  local type_="$3"
  local format_="$4"
  local line
  line="$(_stub_line_for "$src" "$type_" "$format_")"
  _ensure_parent_dir "$dest"
  test -e "$dest" || : > "$dest"
  rg -F -q -- "$line" "$dest" || {
    printf '\n# managed by env-files\n%s' "$line" >> "$dest"
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

_init_yaml_parser || {
  # Prefer PyYAML when Python is available.
  { _check pip3 && pip3 install pyyaml; } ||
  { _check pip && pip install pyyaml; } ||
  { _check pip && pip install shyaml; } ||
  { _check brew && brew install shyaml; } ||
  { _check pip3 && pip3 install shyaml; }
  _init_yaml_parser || true
}

cat > "${HOME}/.set_env_repo" <<EOF
export ENV_REPO=${DIR}/src
EOF
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
      dest="$(eval "echo $to_expr")"
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

bkups=($(find "$HOME" -maxdepth 1 -name "*${BACKUP_SUFFIX}"))
test ${#bkups[@]} -gt 0 &&
  >&2 echo "=> ${#bkups[@]} backup files created with suffix '${BACKUP_SUFFIX}'"

