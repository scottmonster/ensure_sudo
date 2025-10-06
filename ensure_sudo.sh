#!/usr/bin/env bash

# used by get_install_cmd, get_sudo_or_wheel, get_group_id
function get_os() {
  # Prefer os-release if present (most modern distros)
  if [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    # ID like: ubuntu, debian, pop, linuxmint, fedora, rhel, centos, arch, manjaro, opensuse-leap, etc.
    case "${ID:-}" in
      ubuntu)    echo "ubuntu"; return 0 ;;
      debian)    echo "debian"; return 0 ;;
      pop)       echo "pop_os"; return 0 ;;
      linuxmint) echo "linuxmint"; return 0 ;;
      elementary)echo "elementary"; return 0 ;;
      raspbian)  echo "raspbian"; return 0 ;;
      mx)        echo "mx"; return 0 ;;
      kali)      echo "kali"; return 0 ;;
      parrot)    echo "parrot"; return 0 ;;
      dietpi)    echo "dietpi"; return 0 ;;
      zorin)     echo "zorin"; return 0 ;;
      fedora)    echo "fedora"; return 0 ;;
      rhel)      echo "redhat"; return 0 ;;
      centos)    echo "centos"; return 0 ;;
      rocky)     echo "rocky"; return 0 ;;
      almalinux) echo "almalinux"; return 0 ;;
      arch)      echo "arch"; return 0 ;;
      manjaro)   echo "manjaro"; return 0 ;;
      endeavouros) echo "endeavouros"; return 0 ;;
      garuda)    echo "garuda"; return 0 ;;
      opensuse*|sles)
                 echo "suse"; return 0 ;;
      alpine)    echo "alpine"; return 0 ;;
    esac

    # Fall back to ID_LIKE if ID wasn’t matched
    case "${ID_LIKE:-}" in
      *debian*)  # includes ubuntu, pop_os, mint families
                 # try to be more specific if NAME/VERSION/LIKE give hints
                 if [ "${ID_LIKE#*ubuntu}" != "$ID_LIKE" ]; then
                   echo "ubuntu-like"
                 else
                   echo "debian-like"
                 fi
                 return 0
                 ;;
      *rhel*|*fedora*|*centos*)
                 echo "redhat-like"; return 0 ;;
      *arch*)    echo "arch-like"; return 0 ;;
      *suse*)    echo "suse-like"; return 0 ;;
    esac
  fi

  # If os-release missing or inconclusive, use package managers
  case "$OSTYPE" in
    linux-gnu*)
      if command -v apt-get >/dev/null 2>&1; then
        # Try lsb_release for finer detail if installed
        if command -v lsb_release >/dev/null 2>&1; then
          dist_id=$(lsb_release -si 2>/dev/null | tr '[:upper:]' '[:lower:]')
          case "$dist_id" in
            ubuntu)    echo "ubuntu" ;;
            debian)    echo "debian" ;;
            pop)       echo "pop_os" ;;
            linuxmint) echo "linuxmint" ;;
            *)         echo "debian-like" ;;
          esac
        else
          echo "debian-like"
        fi
      elif command -v dnf >/dev/null 2>&1 || command -v yum >/dev/null 2>&1; then
        echo "redhat-like"
      elif command -v pacman >/dev/null 2>&1; then
        echo "arch"
      elif command -v zypper >/dev/null 2>&1; then
        echo "suse"
      elif command -v apk >/dev/null 2>&1; then
        echo "alpine"
      else
        echo "linux"
      fi
      ;;
    darwin*) echo "macos" ;;
    cygwin*|msys*|win32*) echo "windows" ;;
    *) echo "unknown" ;;
  esac
}

function get_install_cmd(){
  local os
  os=$(get_os)
  case "$os" in
    ubuntu|debian|pop_os|linuxmint|elementary|raspbian|mx|kali|parrot|dietpi|zorin|ubuntu-like|debian-like)
      echo "apt-get install -y"
      ;;
    fedora)
      echo "dnf install -y"
      ;;
    redhat|centos|rocky|almalinux|redhat-like)
      if command -v dnf >/dev/null 2>&1; then
        echo "dnf install -y"
      else
        echo "yum install -y"
      fi
      ;;
    suse|suse-like)
      echo "zypper install -y"
      ;;
    arch|manjaro|endeavouros|garuda|arch-like)
      echo "pacman -S --noconfirm"
      ;;
    alpine)
      echo "apk add"
      ;;
    macos)
      echo "brew install"
      ;;
    windows)
      echo "choco install -y"
      ;;
    *)
      # Unknown: return empty to signal caller to handle it
      echo ""
      ;;
  esac
}

function get_sudo_or_wheel(){
  # get_os then echo sudo or wheel accordingly
  local os
  os=$(get_os)
  case "$os" in
    ubuntu|debian|pop_os|linuxmint|elementary|raspbian|mx|kali|parrot|dietpi|zorin|ubuntu-like|debian-like)
      echo "sudo"
      ;;
    fedora|redhat|centos|rocky|almalinux|redhat-like|suse|suse-like|arch|manjaro|endeavouros|garuda|arch-like|alpine)
      echo "wheel"
      ;;
    *)
      # Default to sudo if unknown
      echo "sudo"
      ;;
  esac
}

function get_group_id(){
  local os
  os=$(get_os)
  case "$os" in
    ubuntu|debian|pop_os|linuxmint|elementary|raspbian|mx|kali|parrot|dietpi|zorin|ubuntu-like|debian-like)
      echo "27"
      ;;
    arch|manjaro|endeavouros|garuda|arch-like)
      echo "998"
      ;;
    fedora|redhat|centos|rocky|almalinux|redhat-like|suse|suse-like)
      echo "10"
      ;;
    alpine)
      echo "10"
      ;;
    *)
      echo "27"
      ;;
  esac
}


function ensure_sudo(){
  
  # At this point we know sudo is not usable but we don't know why
  # POISSIBLE REASONS:
  # 1. sudo not installed
  # 2. user not in sudoers
  # 3. sudoers misconfigured
  # 4. sudo binary broken or lost setuid bit
  # For now we are just going to worry about the first two

  # we will use this to build up commands to run as root
  local to_run=""
  if ! command -v sudo >/dev/null 2>&1; then
    echo "sudo not found, attempting to install it"
    local os
    os=$(get_os)
    local install_cmd

    # add the install command to the the string to_run as root
    install_cmd=$(get_install_cmd "$os")
    to_run+="$install_cmd sudo && "
  fi



  function add_user_to_group(){
    local user_to_add="$1"
    local group_name="$2"
    local group_id="$3"
    echo "Adding user '$user_to_add' to ${group_name} group..."


    # make sure the group exists
    if ! getent group "$group_name" >/dev/null; then
      echo "Group ${group_name} not found—creating it now."
      if ! getent group | grep -qE '^[^:]+:[^:]*:'"${group_id}"':'; then
        echo "$group_id is free"
        groupadd -g $group_id "$group_name"
        echo "Created group ${group_name} with GID ${group_id}."
      else
        echo "$group_id is in use"
        groupadd "$group_name"
        echo "GID ${group_id} is in use; created group ${group_name} with default GID."
      fi
    else
      echo "Group ${group_name} already exists."
    fi

    
    # add user to the group
    if ! getent group "$group_name" | grep -q "\b${user_to_add}\b"; then
      usermod -aG "$group_name" "$user_to_add"
      echo "User $user_to_add added to ${group_name} group."
    else
      echo "User $user_to_add is already in the ${group_name} group."
    fi

    # verify the user was added
    echo "Verifying with getent group ${group_name}:"
    getent group "$group_name"
    if ! getent group "$group_name" | grep -q "\b${user_to_add}\b"; then
      echo "ERROR: Failed to add ${user_to_add} to ${group_name} group!"
      return 1
    else
      echo "User ${user_to_add} successfully added to ${group_name} group"
    fi

    echo "add_user_to_sudo finished for $user_to_add"
  }

  
  # if user is not in the sudo or wheel group add add_user_to_group to_run as root
  local sudo_or_wheel=$(get_sudo_or_wheel)
  local group_id=$(get_group_id)
  if ! id -nG "$USER" | tr ' ' '\n' | grep -Eqx 'sudo|wheel'; then
    echo "User $USER is not in the sudo group, adding now..."
    to_run+="$(declare -f add_user_to_group); "
    to_run+="add_user_to_group $USER $sudo_or_wheel $group_id; "
  fi

  if [[ -n "$to_run" ]]; then
    echo "Attempting to setup sudo"
    echo "Enter the root password:"
    # attempt to run the commands as root
    su -l -c "bash -c '${to_run}'" < /dev/tty || {
      echo "Failed to configure sudo."
      exit 1
    }

    # restart the script with sudo access
    # how this is accomplished will depend on how the script was invoked
    # if it was started with something like:
    #   curl -sSL https://path/to/script.sh | bash
    #   the easiest thing i've found to do is instead start it with:
    #   curl -sSL https://path/to/script.sh | tee /tmp/run.sh | bash 
    #   then here we can just do:
    #   exec sg sudo -c 'bash /tmp/run.sh'
    # I probably need to work on this some more
    exec sg sudo -c "$0 $*"
    # exec sg sudo -c 'bash -euo pipefail /tmp/run.sh'
    # cat /tmp/run.sh | exec sg sudo -c 'bash -euo pipefail -s --'
    # exec sg sudo -c 'bash -euo pipefail -s --' < /tmp/run.sh
  else
    echo "User $USER is already in the sudo group, no action needed."
  fi

}

# if we are root exit
function verify_not_root(){
  if [[ $EUID -eq 0 ]] || [ "$(id -u)" -eq 0 ]; then
    echo "Currently running as root."
    echo "Please run as a normal user"
    exit 1
  fi
}


# Main execution
function main() {

  # verify we are not running as root
  verify_not_root

  # sudo -v probes validate sudo access without running a command
  # - If sudo is not installed it will fail
  # - If sudo is installed but user not in sudoers it will fail
  # - If sudo is installed and user input incorrect password it will fail
  if ! sudo -v 2> /dev/null; then
    echo "sudo not usable (validation failed)"
    echo "calling ensure_sudo"
    ensure_sudo
  else
    echo "sudo is usable"
  fi
  exit 0
}

# Run main function
main "$@"



exit

