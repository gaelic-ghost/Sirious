#!/usr/bin/env sh
set -eu

SELF_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SELF_DIR/.." && pwd)

ACTION=status
CONFIGURATION=Debug
DERIVED_DATA_PATH="$REPO_ROOT/.build/ExternalAutomationHelper/DerivedData"
INSTALL_ROOT="$HOME/Library/Application Support/Sirious/AutomationHelper"
LAUNCH_AGENT_DIR="$HOME/Library/LaunchAgents"
LABEL="com.galewilliams.Sirious.AutomationHelper"
HELPER_NAME="SiriousAutomationHelper"
SKIP_BUILD=0
CHECK_XPC=0

usage() {
    cat <<'USAGE'
Usage: scripts/manage-external-automation-helper.sh [action] [options]

Install, inspect, or uninstall SiriousAutomationHelper as an external user
LaunchAgent. This is the local non-App-Store path for testing a non-sandboxed
Accessibility helper outside the sandboxed app bundle.

Actions:
  install       Build the helper, install it under Application Support, write
                ~/Library/LaunchAgents, and bootstrap it into the GUI session.
  status        Print helper file, launchd, direct CLI, and optional XPC status.
  restart       Boot out and bootstrap the installed LaunchAgent again.
  uninstall     Boot out the LaunchAgent and remove the installed plist/helper.

Options:
  --configuration NAME     Xcode configuration to build. Default: Debug.
  --derived-data PATH      DerivedData path for the helper build.
  --install-root PATH      Directory for the helper executable.
  --launch-agent-dir PATH  Directory for the LaunchAgent plist.
  --skip-build             Reuse an already built helper for install.
  --check-xpc              Ask the built app to connect to the helper Mach service.
  -h, --help               Show this help.
USAGE
}

log() {
    printf '%s\n' "$*"
}

fail() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

case "${1:-}" in
    install|status|restart|uninstall)
        ACTION=$1
        shift
        ;;
esac

while [ "$#" -gt 0 ]; do
    case "$1" in
        --configuration)
            [ "$#" -ge 2 ] || fail "--configuration requires a value."
            CONFIGURATION=$2
            shift 2
            ;;
        --derived-data)
            [ "$#" -ge 2 ] || fail "--derived-data requires a value."
            DERIVED_DATA_PATH=$2
            shift 2
            ;;
        --install-root)
            [ "$#" -ge 2 ] || fail "--install-root requires a value."
            INSTALL_ROOT=$2
            shift 2
            ;;
        --launch-agent-dir)
            [ "$#" -ge 2 ] || fail "--launch-agent-dir requires a value."
            LAUNCH_AGENT_DIR=$2
            shift 2
            ;;
        --skip-build)
            SKIP_BUILD=1
            shift
            ;;
        --check-xpc)
            CHECK_XPC=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            fail "Unsupported argument '$1'. Run with --help for usage."
            ;;
    esac
done

case "$INSTALL_ROOT" in
    "$HOME"/*)
        ;;
    *)
        fail "--install-root must be under $HOME for this user LaunchAgent workflow."
        ;;
esac

case "$LAUNCH_AGENT_DIR" in
    "$HOME"/*)
        ;;
    *)
        fail "--launch-agent-dir must be under $HOME for this user LaunchAgent workflow."
        ;;
esac

HELPER_PATH="$INSTALL_ROOT/$HELPER_NAME"
PLIST_PATH="$LAUNCH_AGENT_DIR/$LABEL.plist"
BUILT_HELPER_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/$HELPER_NAME"
BUILT_APP_EXECUTABLE="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/Sirious.app/Contents/MacOS/Sirious"
DOMAIN="gui/$(id -u)"
SERVICE_NAME="$DOMAIN/$LABEL"

bootout_if_loaded() {
    if launchctl print "$SERVICE_NAME" >/dev/null 2>&1; then
        log "Booting out existing LaunchAgent $SERVICE_NAME."
        launchctl bootout "$DOMAIN" "$PLIST_PATH"
    fi
}

write_plist() {
    mkdir -p "$LAUNCH_AGENT_DIR"
    cat > "$PLIST_PATH" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>AssociatedBundleIdentifiers</key>
	<array>
		<string>com.galewilliams.Sirious</string>
	</array>
	<key>Label</key>
	<string>$LABEL</string>
	<key>LimitLoadToSessionType</key>
	<string>Aqua</string>
	<key>MachServices</key>
	<dict>
		<key>$LABEL</key>
		<true/>
	</dict>
	<key>ProgramArguments</key>
	<array>
		<string>$HELPER_PATH</string>
	</array>
</dict>
</plist>
PLIST
}

build_helper() {
    if [ "$SKIP_BUILD" -eq 1 ]; then
        return
    fi

    log "Building SiriousAutomationHelper $CONFIGURATION into $DERIVED_DATA_PATH."
    xcodebuild build \
        -project "$REPO_ROOT/Sirious.xcodeproj" \
        -scheme SiriousAutomationHelper \
        -configuration "$CONFIGURATION" \
        -destination "platform=macOS,arch=arm64" \
        -derivedDataPath "$DERIVED_DATA_PATH"
}

install_helper() {
    build_helper
    [ -x "$BUILT_HELPER_PATH" ] || fail "Expected built helper at $BUILT_HELPER_PATH, but it does not exist or is not executable."

    log "Installing helper executable at $HELPER_PATH."
    mkdir -p "$INSTALL_ROOT"
    cp "$BUILT_HELPER_PATH" "$HELPER_PATH"
    chmod 755 "$HELPER_PATH"

    log "Writing LaunchAgent plist at $PLIST_PATH."
    write_plist
    plutil -lint "$PLIST_PATH"

    log "Installed helper signature:"
    codesign --verify --strict --verbose=2 "$HELPER_PATH"

    bootout_if_loaded
    log "Bootstrapping LaunchAgent $SERVICE_NAME."
    launchctl bootstrap "$DOMAIN" "$PLIST_PATH"
    log "Kickstarting LaunchAgent $SERVICE_NAME."
    launchctl kickstart -k "$SERVICE_NAME"
}

print_status() {
    if [ -x "$HELPER_PATH" ]; then
        log "Installed helper executable: $HELPER_PATH"
        "$HELPER_PATH" --status
    else
        log "Installed helper executable is missing at $HELPER_PATH."
    fi

    if [ -f "$PLIST_PATH" ]; then
        log "Installed LaunchAgent plist:"
        plutil -p "$PLIST_PATH"
    else
        log "Installed LaunchAgent plist is missing at $PLIST_PATH."
    fi

    if launchctl print "$SERVICE_NAME"; then
        log "LaunchAgent $SERVICE_NAME is loaded."
    else
        log "LaunchAgent $SERVICE_NAME is not loaded."
    fi

    if [ "$CHECK_XPC" -eq 1 ]; then
        if [ "$SKIP_BUILD" -eq 0 ] || [ ! -x "$BUILT_APP_EXECUTABLE" ]; then
            log "Building Sirious app so the sandboxed app executable can run the XPC diagnostic."
            xcodebuild build \
                -project "$REPO_ROOT/Sirious.xcodeproj" \
                -scheme Sirious \
                -configuration "$CONFIGURATION" \
                -destination "platform=macOS,arch=arm64" \
                -derivedDataPath "$DERIVED_DATA_PATH"
        fi

        log "XPC status from sandboxed Sirious app executable:"
        "$BUILT_APP_EXECUTABLE" --automation-helper-xpc-status
    fi
}

uninstall_helper() {
    bootout_if_loaded

    if [ -f "$PLIST_PATH" ]; then
        log "Removing LaunchAgent plist at $PLIST_PATH."
        rm -f "$PLIST_PATH"
    fi

    if [ -e "$HELPER_PATH" ]; then
        log "Removing helper executable at $HELPER_PATH."
        rm -f "$HELPER_PATH"
    fi

    if [ -d "$INSTALL_ROOT" ]; then
        rmdir "$INSTALL_ROOT" 2>/dev/null || true
    fi
}

cd "$REPO_ROOT"

case "$ACTION" in
    install)
        install_helper
        print_status
        ;;
    status)
        print_status
        ;;
    restart)
        [ -f "$PLIST_PATH" ] || fail "Cannot restart missing LaunchAgent plist at $PLIST_PATH."
        bootout_if_loaded
        log "Bootstrapping LaunchAgent $SERVICE_NAME."
        launchctl bootstrap "$DOMAIN" "$PLIST_PATH"
        log "Kickstarting LaunchAgent $SERVICE_NAME."
        launchctl kickstart -k "$SERVICE_NAME"
        print_status
        ;;
    uninstall)
        uninstall_helper
        ;;
    *)
        fail "Unsupported action '$ACTION'. Run with --help for usage."
        ;;
esac
