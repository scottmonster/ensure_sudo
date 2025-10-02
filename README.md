#### DISCLAIMER:

I'm not a programmer, software developer, engineer, or any other fancy title that sounds like I speak fluent binary. I am not a network engineer. I do not even have any sort of IT or tech job. I am simply a hobbyist who dabbles in code to fix relatively minor issues and annoyances. Most of the time, I throw what little I know about "good" coding standards out the window and beat my head against the wall just trying to get the thing to work. To highlight some of my key skills:

- **Memory Management**: The only thing I know about pointers is that they can be used to identify where the fire has started after I inevitably create one of my signature infinite loops. Because I lack memory management skills, I rely heavily on the far superior and quicker (Garbage Collected) languages, especially the GOAT... JavaScript.
- **Debugging**: I have exceptional and unmatched debugging skills... ugly cry while button mashing until I accidentally fix the problem.
- **Scalability**: I don't need to worry about scalability issues because I highly doubt any more than three people will ever use something I write.
- **Dependency Management**: `rm -rf node_modules`
- **Recursion**: You can recursively drag these balls across your face.
- **Version Control Conflicts**: Please see the "Dependency Management" section and apply similar techniques.
- **Security Concerns**: I adhere to strict safety protocols by ensuring the proper use of PPE, including flame-resistant attire, a fire extinguisher, and a respirator, before running the code I write. Furthermore, I continually review, update, and practice evacuation procedures to maintain a secure environment.

Self-deprecating jokes aside, I know I do not write the cleanest, most efficient, or safest code. Sometimes it's because the task doesn't require it and sometimes it's because I don't know how. I am always interested in learning, though. So if you happen to come across this and want to learn me some education or you simply want to use something that I've mangled together, feel free to refactor some of my code.

Thank you,  
ScottMonster <br>
As is. Run at your own risk. I'm not accountable for your poor judgment. You've been warned.


# Ensure Sudo

A demonstration script for automatically setting up sudo access without manual script restarts.

## Problem

I've repeatedly encountered situations where I need to ensure sudo is available and usable in automated scripts, but the user either:

- Doesn't have sudo installed
- Isn't in the sudo/wheel group
- Has sudo misconfigured

Every time this happens, I have to refigure out how to handle it properly. This repository serves as a reference implementation so I don't have to solve this problem again.

## Solution

The `ensure_sudo.sh` script automatically:

1. **Detects the operating system** and determines the appropriate sudo group (`sudo` vs `wheel`)
2. **Checks if sudo is installed** - installs it if missing
3. **Verifies user group membership** - adds user to sudo/wheel group if needed
4. **Handles the restart gracefully** - uses `sg` to restart the script with new group permissions

## Key Features

- **Cross-platform detection**: Works on Ubuntu, Debian, RHEL, Fedora, Arch, SUSE, and derivatives
- **Minimal user interaction**: Only asks for root password when actually needed
- **Proper group handling**: Uses distribution-appropriate GIDs when creating groups
- **Script continuity**: Automatically restarts itself with sudo privileges after setup

## How it works

The script follows a systematic approach to ensure sudo access:

### 1. Operating System Detection

The script first identifies the operating system using `/etc/os-release` or fallback methods:

- **Debian-based systems** (Ubuntu, Debian, Pop!_OS, etc.) → uses `sudo` group
- **Red Hat-based systems** (Fedora, RHEL, CentOS, etc.) → uses `wheel` group
- **Arch-based systems** (Arch, Manjaro, etc.) → uses `wheel` group
- **SUSE systems** → uses `wheel` group

### 2. Root User Verification

The script ensures it's not running as root (which would bypass sudo entirely) and exits if it detects root execution.

### 3. Sudo Availability Check

Using `sudo -v`, the script tests whether sudo is usable without actually running a command. This can fail for several reasons:

- Sudo is not installed
- User is not in the appropriate sudo group
- Sudo is misconfigured

### 4. Automatic Setup Process

If sudo is not usable, the script builds a series of commands to run as root:

**a) Install sudo** (if missing):

- Detects the package manager (`apt`, `dnf`, `yum`, `zypper`, `pacman`)
- Adds the appropriate install command to the execution queue

**b) Add user to sudo group** (if not a member):

- Creates the appropriate group (`sudo` or `wheel`) if it doesn't exist
- Uses distribution-specific Group IDs when possible (27 for Debian, 10 for RHEL, 998 for Arch)
- Adds the current user to the group using `usermod -aG`

### 5. Root Execution

The script executes the queued commands using `su -l -c`, prompting for the root password only once.

### 6. Script Restart

After successful setup, the script restarts itself with new group permissions using `sg` (switch group):

```bash
exec sg sudo -c "$0 $*"
```

This ensures the script continues execution with proper sudo access without requiring the user to manually restart it.

## Usage

Although you can use it, it is more of a demonstration and reference.

```bash
# Basic usage
./ensure_sudo.sh

# Or integrate the functions into your own script
source ensure_sudo.sh
verify_not_root
if ! sudo -v 2>/dev/null; then
    ensure_sudo
fi
```
