#!/usr/bin/env bash
set -euo pipefail

SYMLINK_MODE=0
PROFILE="classic"
SCRIPT_PATH="${BASH_SOURCE[0]:-${0}}"
SCRIPT_DIR="$(cd "$(dirname "${SCRIPT_PATH}")" && pwd)"
TEMPLATE_DIR=""

log() {
  printf '[%s] %s\n' "$1" "$2" >&2
}

die() {
  log 'ERROR' "$1"
  exit 1
}

usage() {
  cat <<'USAGE'
Usage: install_zsh.sh [--copy|--link] [--profile <name>] [--help]

--copy        Copy profile files into place (default).
--link        Symlink profile files from the repository.
--profile     Profile name under profiles/ to deploy (default: classic).
--help        Show this help message and exit.
USAGE
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Required command '$1' is not available. Please install it and retry."
}

main() {
  parse_args "$@"

  TEMPLATE_DIR="${SCRIPT_DIR}/profiles/${PROFILE}"
  [[ -d "${TEMPLATE_DIR}" ]] || die "Profile '${PROFILE}' not found (expected ${TEMPLATE_DIR})."

  require_cmd curl
  require_cmd git
  require_cmd zsh
  require_cmd tar
  require_cmd find

  local home_dir
  home_dir=${HOME:-""}
  [[ -n "${home_dir}" ]] || die 'Unable to determine HOME directory.'

  local timestamp backup_root backup_dir
  timestamp=$(date +%Y%m%d-%H%M%S)
  backup_root="${home_dir}/.zsh-backups"
  backup_dir="${backup_root}/${timestamp}"
  mkdir -p "${backup_dir}"

  local zsh_install_path zsh_custom p10k_template has_p10k fastfetch_logo_template
  zsh_install_path="${home_dir}/.oh-my-zsh"
  zsh_custom="${ZSH_CUSTOM:-${zsh_install_path}/custom}"
  p10k_template="${TEMPLATE_DIR}/p10k.zsh"
  has_p10k=0
  [[ -f "${p10k_template}" ]] && has_p10k=1
  fastfetch_logo_template="${TEMPLATE_DIR}/fastfetch_logo.txt"

  install_oh_my_zsh "${zsh_install_path}"
  install_powerlevel10k "${zsh_custom}"
  install_pure_theme "${zsh_custom}"
  install_plugins "${zsh_custom}"
  install_external_tools
  install_meslo_fonts
  install_p10k_config "${home_dir}" "${backup_dir}" "${p10k_template}" "${has_p10k}"
  install_zshrc "${home_dir}" "${backup_dir}"
  install_fastfetch_logo "${home_dir}" "${backup_dir}" "${fastfetch_logo_template}"
  ensure_default_shell

  write_manifest "${backup_dir}" "${timestamp}"

  log 'INFO' "Backups stored in ${backup_dir}"
  log 'INFO' 'Installation complete. Set MesloLGS NF in your terminal profile to finish setup.'
  log 'HINT' 'Install autojump manually if needed: sudo apt install autojump'
  log 'HINT' 'Install direnv manually if needed: sudo apt install direnv'
  log 'HINT' 'Install sqlite3 manually if needed: sudo apt install sqlite3'
  log 'HINT' 'Install Pygments manually if needed: sudo apt install python3-pygments'
  log 'HINT' 'Download fastfetch manually if needed: https://github.com/fastfetch-cli/fastfetch/releases'
}

parse_args() {
  local positional=()
  while (($#)); do
    case "$1" in
      --link)
        SYMLINK_MODE=1
        ;;
      --copy)
        SYMLINK_MODE=0
        ;;
      --profile)
        shift || die '--profile requires an argument'
        PROFILE="$1"
        ;;
      --profile=*)
        PROFILE="${1#*=}"
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      --)
        shift
        break
        ;;
      *)
        positional+=("$1")
        ;;
    esac
    shift || true
  done

  if (($#)); then
    positional+=("$@")
  fi

  if ((${#positional[@]})); then
    die "Unknown argument(s): ${positional[*]}"
  fi
}

install_oh_my_zsh() {
  local target
  target="$1"
  if [[ -d "${target}" ]]; then
    log 'INFO' 'Oh My Zsh already present. Updating...'
    git -C "${target}" pull --ff-only || die 'Failed to update Oh My Zsh.'
  else
    log 'INFO' 'Installing Oh My Zsh...'
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
      sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" || \
      die 'Oh My Zsh installation failed.'
  fi
}

install_powerlevel10k() {
  local zsh_custom theme_dir
  zsh_custom="$1"
  theme_dir="${zsh_custom}/themes/powerlevel10k"
  log 'INFO' 'Setting up Powerlevel10k...'
  if [[ -d "${theme_dir}/.git" ]]; then
    git -C "${theme_dir}" pull --ff-only || die 'Failed to update Powerlevel10k.'
  else
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${theme_dir}" || \
      die 'Powerlevel10k clone failed.'
  fi
}

install_pure_theme() {
  local zsh_custom theme_dir
  zsh_custom="$1"
  theme_dir="${zsh_custom}/themes/pure"
  log 'INFO' 'Setting up Pure prompt...'
  if [[ -d "${theme_dir}/.git" ]]; then
    git -C "${theme_dir}" pull --ff-only || die 'Failed to update Pure prompt.'
  else
    git clone --depth=1 https://github.com/sindresorhus/pure.git "${theme_dir}" || \
      die 'Pure prompt clone failed.'
  fi
}

install_plugins() {
  local zsh_custom
  zsh_custom="$1"
  declare -A plugin_repos=(
    [zsh-autosuggestions]=https://github.com/zsh-users/zsh-autosuggestions.git
    [zsh-completions]=https://github.com/zsh-users/zsh-completions.git
    [zsh-syntax-highlighting]=https://github.com/zsh-users/zsh-syntax-highlighting.git
    [fast-syntax-highlighting]=https://github.com/zdharma-continuum/fast-syntax-highlighting.git
    [zsh-histdb]=https://github.com/larkery/zsh-histdb.git
    [fzf-tab]=https://github.com/Aloxaf/fzf-tab.git
  )

  for plugin in "${!plugin_repos[@]}"; do
    local dest
    dest="${zsh_custom}/plugins/${plugin}"
    if [[ -d "${dest}/.git" ]]; then
      log 'INFO' "Updating plugin ${plugin}..."
      git -C "${dest}" pull --ff-only || die "Failed to update ${plugin}."
    else
      log 'INFO' "Installing plugin ${plugin}..."
      git clone --depth=1 "${plugin_repos[${plugin}]}" "${dest}" || \
        die "Failed to clone plugin ${plugin}."
    fi
  done
}

install_external_tools() {
  ensure_command_available autojump autojump
  ensure_command_available direnv direnv
  ensure_command_available sqlite3 sqlite3
  ensure_command_available pygmentize python3-pygments
  ensure_command_available fastfetch fastfetch
}

ensure_command_available() {
  local binary package
  binary="$1"
  package="$2"

  if command -v "${binary}" >/dev/null 2>&1; then
    return
  fi

  if [[ "${binary}" == "fastfetch" ]]; then
    install_fastfetch_release
    return
  fi

  local apt_cmd
  if command -v apt-get >/dev/null 2>&1; then
    apt_cmd=apt-get
  elif command -v apt >/dev/null 2>&1; then
    apt_cmd=apt
  else
    log 'WARN' "${binary} not found. Install manually (e.g., sudo apt install ${package})."
    return
  fi

  local sudo_prefix=()
  if (( EUID != 0 )); then
    if command -v sudo >/dev/null 2>&1; then
      sudo_prefix=(sudo)
    else
      log 'WARN' "Root privileges required to install ${package}. Install manually: sudo ${apt_cmd} install ${package}"
      return
    fi
  fi

  log 'INFO' "Installing ${package} via ${apt_cmd}..."
  if ! "${sudo_prefix[@]}" "${apt_cmd}" install -y "${package}"; then
    log 'WARN' "Failed to install ${package}. Install manually: sudo ${apt_cmd} install ${package}"
  else
    hash -r || true
  fi
}

install_meslo_fonts() {
  local fonts_dir
  case "${OSTYPE:-}" in
    darwin*) fonts_dir="${HOME}/Library/Fonts" ;;
    *) fonts_dir="${HOME}/.local/share/fonts" ;;
  esac
  mkdir -p "${fonts_dir}"

  local base url font_name escaped_path
  base='https://github.com/romkatv/powerlevel10k-media/raw/master'
  while read -r font_name; do
    escaped_path=${font_name// /%20}
    url="${base}/${escaped_path}"
    log 'INFO' "Installing font ${font_name}..."
    curl -fLso "${fonts_dir}/${font_name}" --create-dirs "${url}" || \
      die "Failed to download font ${font_name}."
  done <<<'MesloLGS NF Regular.ttf
MesloLGS NF Bold.ttf
MesloLGS NF Italic.ttf
MesloLGS NF Bold Italic.ttf'

  if command -v fc-cache >/dev/null 2>&1; then
    fc-cache -f "${fonts_dir}" >/dev/null 2>&1 || true
  fi
}

install_fastfetch_release() {
  local arch platform_url tmp_dir archive_path extracted_binary dest_bin

  arch=$(uname -m)
  case "${arch}" in
    x86_64|amd64)
      platform_url="https://github.com/fastfetch-cli/fastfetch/releases/latest/download/fastfetch-linux-amd64.tar.gz"
      ;;
    aarch64|arm64)
      platform_url="https://github.com/fastfetch-cli/fastfetch/releases/latest/download/fastfetch-linux-aarch64.tar.gz"
      ;;
    armv7l|armhf)
      platform_url="https://github.com/fastfetch-cli/fastfetch/releases/latest/download/fastfetch-linux-armv7.tar.gz"
      ;;
    *)
      log 'WARN' "fastfetch is not available for architecture '${arch}'. Install it manually from https://github.com/fastfetch-cli/fastfetch/releases"
      return
  esac

  tmp_dir=$(mktemp -d)
  archive_path="${tmp_dir}/fastfetch.tar.gz"
  log 'INFO' "Downloading fastfetch from ${platform_url}"
  if ! curl -fsSL "${platform_url}" -o "${archive_path}"; then
    rm -rf "${tmp_dir}"
    log 'WARN' 'Failed to download fastfetch release archive. Install manually from https://github.com/fastfetch-cli/fastfetch/releases'
    return
  fi

  if ! tar -xzf "${archive_path}" -C "${tmp_dir}"; then
    rm -rf "${tmp_dir}"
    log 'WARN' 'Failed to extract fastfetch archive. Install manually from https://github.com/fastfetch-cli/fastfetch/releases'
    return
  fi

  extracted_binary=$(find "${tmp_dir}" -type f -name fastfetch -perm -u+x | head -n 1)
  if [[ -z "${extracted_binary}" ]]; then
    rm -rf "${tmp_dir}"
    log 'WARN' 'fastfetch binary not found in archive. Install manually from https://github.com/fastfetch-cli/fastfetch/releases'
    return
  fi

  dest_bin="${HOME}/.local/bin"
  mkdir -p "${dest_bin}"
  if ! cp "${extracted_binary}" "${dest_bin}/fastfetch"; then
    rm -rf "${tmp_dir}"
    log 'WARN' "Failed to install fastfetch into ${dest_bin}. Install manually from https://github.com/fastfetch-cli/fastfetch/releases"
    return
  fi
  chmod +x "${dest_bin}/fastfetch"
  rm -rf "${tmp_dir}"
  hash -r || true

  if ! command -v fastfetch >/dev/null 2>&1; then
    log 'WARN' "fastfetch installed to ${dest_bin}, but the directory is not in PATH. Add 'export PATH=\"${dest_bin}:\$PATH\"' to your shell init."
  else
    log 'INFO' "fastfetch installed to ${dest_bin}/fastfetch"
  fi
}

install_p10k_config() {
  local home_dir backup_dir template has_template dest
  home_dir="$1"
  backup_dir="$2"
  template="$3"
  has_template="$4"
  dest="${home_dir}/.p10k.zsh"

  if [[ "${has_template}" -eq 0 || ! -f "${template}" ]]; then
    if [[ -f "${dest}" ]]; then
      log 'INFO' 'Skipping .p10k.zsh update for this profile; existing file left in place.'
    else
      log 'INFO' 'No Powerlevel10k configuration for this profile; skipping.'
    fi
    return
  fi

  deploy_file "${template}" "${dest}" "${backup_dir}"
}

install_zshrc() {
  local home_dir backup_dir template dest base_dir
  home_dir="$1"
  backup_dir="$2"
  template="${TEMPLATE_DIR}/zshrc"
  base_dir="${ZDOTDIR:-${home_dir}}"
  dest="${base_dir}/.zshrc"

  deploy_file "${template}" "${dest}" "${backup_dir}"
}

install_fastfetch_logo() {
  local home_dir backup_dir template config_dir dest config_file
  home_dir="$1"
  backup_dir="$2"
  template="$3"

  [[ -f "${template}" ]] || return

  config_dir="${XDG_CONFIG_HOME:-${home_dir}/.config}/fastfetch"
  dest="${config_dir}/logo.txt"
  config_file="${config_dir}/config.jsonc"
  mkdir -p "${config_dir}"

  if [[ -f "${dest}" ]]; then
    cp "${dest}" "${backup_dir}/$(basename "${dest}")" || \
      die 'Failed to back up existing fastfetch logo.'
  fi

  cp "${template}" "${dest}" || die 'Failed to install fastfetch logo.'

  if [[ -f "${config_file}" ]] && grep -q '"type"[[:space:]]*:[[:space:]]*"ascii"' "${config_file}"; then
    log 'INFO' "Updating fastfetch config to file-based logo"
    rm -f "${config_file}"
  fi

  if [[ ! -f "${config_file}" ]]; then
    cat >"${config_file}" <<EOF
{
  "logo": {
    "type": "file",
    "source": "${dest}"
  },
  "modules": [
    "title",
    "separator",
    {
      "type": "os"
    },
    "kernel",
    "uptime",
    "packages",
    "shell",
    "terminal",
    "cpu",
    "memory",
    "break",
    "gpu",
    "disk",
    "display",
    "battery",
    "media"
  ]
}
EOF
  fi
}

ensure_default_shell() {
  local current_shell target_shell
  target_shell=$(command -v zsh)
  current_shell=${SHELL:-}

  if [[ "${current_shell}" != "${target_shell}" ]]; then
    if chsh -s "${target_shell}"; then
      log 'INFO' "Default shell changed to ${target_shell}."
    else
      log 'WARN' 'Unable to change default shell automatically. Please run `chsh -s $(which zsh)` manually.'
    fi
  else
    log 'INFO' 'Zsh is already the default shell.'
  fi
}

deploy_file() {
  local src dest backup_dir dest_dir backup_target
  src="$1"
  dest="$2"
  backup_dir="$3"

  [[ -f "${src}" ]] || die "Template '${src}' is missing."

  dest_dir="$(dirname "${dest}")"
  mkdir -p "${dest_dir}"

  if [[ -e "${dest}" || -L "${dest}" ]]; then
    backup_target="${backup_dir}/$(basename "${dest}")"
    cp -a "${dest}" "${backup_target}" || die "Failed to back up ${dest}."
    rm -rf "${dest}"
  fi

  if (( SYMLINK_MODE )); then
    ln -s "${src}" "${dest}" || die "Failed to symlink ${src} -> ${dest}."
  else
    cp "${src}" "${dest}" || die "Failed to copy ${src} to ${dest}."
  fi
}

write_manifest() {
  local backup_dir timestamp manifest git_commit mode
  backup_dir="$1"
  timestamp="$2"
  manifest="${backup_dir}/install_manifest.txt"

  if git -C "${SCRIPT_DIR}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git_commit=$(git -C "${SCRIPT_DIR}" rev-parse HEAD 2>/dev/null || echo 'unknown')
  else
    git_commit='unknown'
  fi

  if (( SYMLINK_MODE )); then
    mode='link'
  else
    mode='copy'
  fi

  {
    printf 'timestamp=%s\n' "${timestamp}"
    printf 'script_path=%s\n' "${SCRIPT_PATH}"
    printf 'repo_root=%s\n' "${SCRIPT_DIR}"
    printf 'git_commit=%s\n' "${git_commit}"
    printf 'mode=%s\n' "${mode}"
    printf 'profile=%s\n' "${PROFILE}"
  } > "${manifest}"
}

main "$@"
