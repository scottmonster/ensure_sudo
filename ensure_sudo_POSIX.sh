#!/bin/sh

# POSIX-compliant script for sudo setup and verification

# Used by get_install_cmd, get_sudo_or_wheel, get_group_id
get_os() {
  # Prefer os-release if present (most modern distros)
  if [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    # ID like: ubuntu, debian, pop, linuxmint, fedora, rhel, centos, arch, etc.
    case "${ID:-}" in
      ubuntu)    printf "ubuntu"; return 0 ;;
      debian)    printf "debian"; return 0 ;;
      pop)       printf "pop_os"; return 0 ;;
      linuxmint) printf "linuxmint"; return 0 ;;
      elementary) printf "elementary"; return 0 ;;
      raspbian)  printf "raspbian"; return 0 ;;
      mx)        printf "mx"; return 0 ;;
      kali)      printf "kali"; return 0 ;;
      parrot)    printf "parrot"; return 0 ;;
      dietpi)    printf "dietpi"; return 0 ;;
      zorin)     printf "zorin"; return 0 ;;
      fedora)    printf "fedora"; return 0 ;;
      rhel)      printf "redhat"; return 0 ;;
      centos)    printf "centos"; return 0 ;;
      rocky)     printf "rocky"; return 0 ;;
      almalinux) printf "almalinux"; return 0 ;;
      arch)      printf "arch"; return 0 ;;
      manjaro)   printf "manjaro"; return 0 ;;
      endeavouros) printf "endeavouros"; return 0 ;;
      garuda)    printf "garuda"; return 0 ;;
      opensuse*|sles)
                 printf "suse"; return 0 ;;
      alpine)    printf "alpine"; return 0 ;;
    esac

    # Fall back to ID_LIKE if ID wasn't matched
    case "${ID_LIKE:-}" in
      *debian*)
        # Check if ubuntu is in ID_LIKE
        if [ "${ID_LIKE#*ubuntu}" != "$ID_LIKE" ]; then
          printf "ubuntu-like"
        else
          printf "debian-like"
        fi
        return 0
        ;;
      *rhel*|*fedora*|*centos*)
        printf "redhat-like"; return 0 ;;
      *arch*)
        printf "arch-like"; return 0 ;;
      *suse*)
        printf "suse-like"; return 0 ;;
    esac
  fi

  # If os-release missing or inconclusive, use package managers
  # OSTYPE is bash-specific, so we use uname instead
  os_type=$(uname -s)
  case "$os_type" in
    Linux)
      if command -v apt-get >/dev/null 2>&1; then
        # Try lsb_release for finer detail if installed
        if command -v lsb_release >/dev/null 2>&1; then
          dist_id=$(lsb_release -si 2>/dev/null | tr '[:upper:]' '[:lower:]')
          case "$dist_id" in
            ubuntu)    printf "ubuntu" ;;
            debian)    printf "debian" ;;
            pop)       printf "pop_os" ;;
            linuxmint) printf "linuxmint" ;;
            *)         printf "debian-like" ;;
          esac
        else
          printf "debian-like"
        fi
      elif command -v dnf >/dev/null 2>&1 || command -v yum >/dev/null 2>&1; then
        printf "redhat-like"
      elif command -v pacman >/dev/null 2>&1; then
        printf "arch"
      elif command -v zypper >/dev/null 2>&1; then
        printf "suse"
      elif command -v apk >/dev/null 2>&1; then
        printf "alpine"
      else
        printf "linux"
      fi
      ;;
    Darwin) printf "macos" ;;
    CYGWIN*|MSYS*|MINGW*) printf "windows" ;;
    *) printf "unknown" ;;
  esac
}

get_install_cmd() {
  os=$(get_os)
  case "$os" in
    ubuntu|debian|pop_os|linuxmint|elementary|raspbian|mx|kali|parrot|dietpi|zorin|ubuntu-like|debian-like)
      printf "apt-get install -y"
      ;;
    fedora)
      printf "dnf install -y"
      ;;
    redhat|centos|rocky|almalinux|redhat-like)
      if command -v dnf >/dev/null 2>&1; then
        printf "dnf install -y"
      else
        printf "yum install -y"
      fi
      ;;
    suse|suse-like)
      printf "zypper install -y"
      ;;
    arch|manjaro|endeavouros|garuda|arch-like)
      printf "pacman -S --noconfirm"
      ;;
    alpine)
      printf "apk add"
      ;;
    macos)
      printf "brew install"
      ;;
    windows)
      printf "choco install -y"
      ;;
    *)
      # Unknown: return empty to signal caller to handle it
      printf ""
      ;;
  esac
}

get_sudo_or_wheel() {
  os=$(get_os)
  case "$os" in
    ubuntu|debian|pop_os|linuxmint|elementary|raspbian|mx|kali|parrot|dietpi|zorin|ubuntu-like|debian-like)
      printf "sudo"
      ;;
    fedora|redhat|centos|rocky|almalinux|redhat-like|suse|suse-like|arch|manjaro|endeavouros|garuda|arch-like|alpine)
      printf "wheel"
      ;;
    macos)
      printf "admin"
      ;;
    *)
      # Default to sudo if unknown
      printf "sudo"
      ;;
  esac
}

get_group_id() {
  os=$(get_os)
  case "$os" in
    ubuntu|debian|pop_os|linuxmint|elementary|raspbian|mx|kali|parrot|dietpi|zorin|ubuntu-like|debian-like)
      printf "27"
      ;;
    arch|manjaro|endeavouros|garuda|arch-like)
      printf "998"
      ;;
    fedora|redhat|centos|rocky|almalinux|redhat-like|suse|suse-like)
      printf "10"
      ;;
    alpine)
      printf "10"
      ;;
    macos)
      printf "80"
      ;;
    *)
      printf "27"
      ;;
  esac
}

add_user_to_group() {
  user_to_add="$1"
  group_name="$2"
  group_id="$3"
  
  printf "Adding user '%s' to %s group...\n" "$user_to_add" "$group_name"

  # Detect OS for platform-specific commands
  os_type=$(uname -s)

  if [ "$os_type" = "Darwin" ]; then
    # macOS-specific group management
    # Check if group exists
    if ! dscl . -read /Groups/"$group_name" >/dev/null 2>&1; then
      printf "Group %s not found—creating it now.\n" "$group_name"
      dseditgroup -o create -i "$group_id" "$group_name" 2>/dev/null || dseditgroup -o create "$group_name"
      printf "Created group %s.\n" "$group_name"
    else
      printf "Group %s already exists.\n" "$group_name"
    fi

    # Check if user is already in the group
    if ! dsmemberutil checkmembership -U "$user_to_add" -G "$group_name" 2>/dev/null | grep -q "user is a member"; then
      dseditgroup -o edit -a "$user_to_add" -t user "$group_name"
      printf "User %s added to %s group.\n" "$user_to_add" "$group_name"
    else
      printf "User %s is already in the %s group.\n" "$user_to_add" "$group_name"
    fi

    # Verify the user was added
    printf "Verifying membership:\n"
    if dsmemberutil checkmembership -U "$user_to_add" -G "$group_name" 2>/dev/null | grep -q "user is a member"; then
      printf "User %s successfully added to %s group\n" "$user_to_add" "$group_name"
    else
      printf "ERROR: Failed to add %s to %s group!\n" "$user_to_add" "$group_name"
      return 1
    fi
  else
    # Linux-specific group management
    # Make sure the group exists
    if ! getent group "$group_name" >/dev/null; then
      printf "Group %s not found—creating it now.\n" "$group_name"
      if ! getent group | grep -qE '^[^:]+:[^:]*:'"${group_id}"':'; then
        printf "%s is free\n" "$group_id"
        groupadd -g "$group_id" "$group_name"
        printf "Created group %s with GID %s.\n" "$group_name" "$group_id"
      else
        printf "%s is in use\n" "$group_id"
        groupadd "$group_name"
        printf "GID %s is in use; created group %s with default GID.\n" \
          "$group_id" "$group_name"
      fi
    else
      printf "Group %s already exists.\n" "$group_name"
    fi

    # Add user to the group
    if ! getent group "$group_name" | grep -q "\b${user_to_add}\b"; then
      usermod -aG "$group_name" "$user_to_add"
      printf "User %s added to %s group.\n" "$user_to_add" "$group_name"
    else
      printf "User %s is already in the %s group.\n" "$user_to_add" "$group_name"
    fi

    # Verify the user was added
    printf "Verifying with getent group %s:\n" "$group_name"
    getent group "$group_name"
    if ! getent group "$group_name" | grep -q "\b${user_to_add}\b"; then
      printf "ERROR: Failed to add %s to %s group!\n" "$user_to_add" "$group_name"
      return 1
    else
      printf "User %s successfully added to %s group\n" "$user_to_add" "$group_name"
    fi
  fi

  printf "add_user_to_group finished for %s\n" "$user_to_add"
}

ensure_sudo() {
  # At this point we know sudo is not usable but we don't know why
  # POSSIBLE REASONS:
  # 1. sudo not installed
  # 2. user not in sudoers
  # 3. sudoers misconfigured
  # 4. sudo binary broken or lost setuid bit
  # For now we are just going to worry about the first two

  to_run=""
  
  if ! command -v sudo >/dev/null 2>&1; then
    printf "sudo not found, attempting to install it\n"
    os=$(get_os)
    install_cmd=$(get_install_cmd "$os")
    to_run="${install_cmd} sudo && "
  fi

  # Check if user is not in the sudo or wheel group
  sudo_or_wheel=$(get_sudo_or_wheel)
  group_id=$(get_group_id)
  
  if ! id -nG "$USER" | tr ' ' '\n' | grep -Eqx 'sudo|wheel|admin'; then
    printf "User %s is not in the sudo/wheel/admin group, adding now...\n" "$USER"
    
    # Since we can't use declare -f in POSIX, we'll inline the function
    to_run="${to_run}"'
add_user_to_group() {
  user_to_add="$1"
  group_name="$2"
  group_id="$3"
  
  printf "Adding user '\''%s'\'' to %s group...\n" "$user_to_add" "$group_name"

  os_type=$(uname -s)

  if [ "$os_type" = "Darwin" ]; then
    if ! dscl . -read /Groups/"$group_name" >/dev/null 2>&1; then
      printf "Group %s not found—creating it now.\n" "$group_name"
      dseditgroup -o create -i "$group_id" "$group_name" 2>/dev/null || dseditgroup -o create "$group_name"
      printf "Created group %s.\n" "$group_name"
    else
      printf "Group %s already exists.\n" "$group_name"
    fi

    if ! dsmemberutil checkmembership -U "$user_to_add" -G "$group_name" 2>/dev/null | grep -q "user is a member"; then
      dseditgroup -o edit -a "$user_to_add" -t user "$group_name"
      printf "User %s added to %s group.\n" "$user_to_add" "$group_name"
    else
      printf "User %s is already in the %s group.\n" "$user_to_add" "$group_name"
    fi

    printf "Verifying membership:\n"
    if dsmemberutil checkmembership -U "$user_to_add" -G "$group_name" 2>/dev/null | grep -q "user is a member"; then
      printf "User %s successfully added to %s group\n" "$user_to_add" "$group_name"
    else
      printf "ERROR: Failed to add %s to %s group!\n" "$user_to_add" "$group_name"
      return 1
    fi
  else
    if ! getent group "$group_name" >/dev/null; then
      printf "Group %s not found—creating it now.\n" "$group_name"
      if ! getent group | grep -qE "^[^:]+:[^:]*:'"${group_id}"':"; then
        printf "%s is free\n" "$group_id"
        groupadd -g "$group_id" "$group_name"
        printf "Created group %s with GID %s.\n" "$group_name" "$group_id"
      else
        printf "%s is in use\n" "$group_id"
        groupadd "$group_name"
        printf "GID %s is in use; created group %s with default GID.\n" \
          "$group_id" "$group_name"
      fi
    else
      printf "Group %s already exists.\n" "$group_name"
    fi

    if ! getent group "$group_name" | grep -q "\b${user_to_add}\b"; then
      usermod -aG "$group_name" "$user_to_add"
      printf "User %s added to %s group.\n" "$user_to_add" "$group_name"
    else
      printf "User %s is already in the %s group.\n" "$user_to_add" "$group_name"
    fi

    printf "Verifying with getent group %s:\n" "$group_name"
    getent group "$group_name"
    if ! getent group "$group_name" | grep -q "\b${user_to_add}\b"; then
      printf "ERROR: Failed to add %s to %s group!\n" "$user_to_add" "$group_name"
      return 1
    else
      printf "User %s successfully added to %s group\n" "$user_to_add" "$group_name"
    fi
  fi
}
'
    to_run="${to_run}add_user_to_group $USER $sudo_or_wheel $group_id; "
  fi

  if [ -n "$to_run" ]; then
    printf "Attempting to setup sudo\n"
    printf "Enter the root password:\n"
    
    # Attempt to run the commands as root
    su -l -c "sh -c '${to_run}'" root < /dev/tty || {
      printf "Failed to configure sudo.\n"
      exit 1
    }

    # Restart the script with sudo access
    # Note: sg may not be available on all systems, newgrp is more portable
    if command -v sg >/dev/null 2>&1; then
      exec sg "$sudo_or_wheel" -c "$0 $*"
    elif command -v newgrp >/dev/null 2>&1; then
      # newgrp changes the current group and restarts shell
      printf "Please run the script again after group membership is active.\n"
      printf "You may need to log out and back in for group changes to take effect.\n"
      exit 0
    else
      printf "Group activation command not found. Please log out and back in.\n"
      exit 0
    fi
  else
    printf "User %s is already in the sudo group, no action needed.\n" "$USER"
  fi
}

verify_not_root() {
  if [ "$(id -u)" -eq 0 ]; then
    printf "Currently running as root.\n"
    printf "Please run as a normal user\n"
    exit 1
  fi
}

# Main execution
main() {
  verify_not_root

  # sudo -v probes validate sudo access without running a command
  # - If sudo is not installed it will fail
  # - If sudo is installed but user not in sudoers it will fail
  # - If sudo is installed and user input incorrect password it will fail
  if ! sudo -v 2>/dev/null; then
    printf "sudo not usable (validation failed)\n"
    printf "calling ensure_sudo\n"
    ensure_sudo
  else
    printf "sudo is usable\n"
  fi
  exit 0
}

# Run main function
main "$@"