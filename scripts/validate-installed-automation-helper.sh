#!/usr/bin/env sh
set -eu

SELF_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SELF_DIR/.." && pwd)

CONFIGURATION=Debug
DERIVED_DATA_PATH="$REPO_ROOT/.build/InstalledAppValidation/DerivedData"
INSTALL_APP_PATH="$REPO_ROOT/.build/InstalledAppValidation/Sirious.app"
RUN_REGISTRATION=0
KEEP_INSTALLED=0
SKIP_BUILD=0

usage() {
    cat <<'USAGE'
Usage: scripts/validate-installed-automation-helper.sh [options]

Build Sirious, copy the app to a stable local test path, and validate the bundled
SiriousAutomationHelper LaunchAgent shape.

Options:
  --configuration NAME     Xcode configuration to build. Default: Debug.
  --derived-data PATH      DerivedData path for the validation build.
  --install-app PATH       Destination .app path for the test install.
  --register               Register, XPC-check, and unregister the LaunchAgent.
  --skip-build             Reuse the app already built under the DerivedData path.
  --keep-installed         Leave the copied .app in place after validation.
  -h, --help               Show this help.

The default install path stays inside the repository's .build directory. For a
closer local install test, pass a stable user location such as:

  --install-app "$HOME/Applications/SiriousInstalledAppValidation/Sirious.app"
USAGE
}

log() {
    printf '%s\n' "$*"
}

fail() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

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
        --install-app)
            [ "$#" -ge 2 ] || fail "--install-app requires a value."
            INSTALL_APP_PATH=$2
            shift 2
            ;;
        --register)
            RUN_REGISTRATION=1
            shift
            ;;
        --skip-build)
            SKIP_BUILD=1
            shift
            ;;
        --keep-installed)
            KEEP_INSTALLED=1
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

BUILT_APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/Sirious.app"
INSTALLED_HELPER_PATH="$INSTALL_APP_PATH/Contents/Resources/SiriousAutomationHelper"
INSTALLED_AGENT_PLIST="$INSTALL_APP_PATH/Contents/Library/LaunchAgents/com.galewilliams.Sirious.AutomationHelper.plist"
INSTALLED_APP_EXECUTABLE="$INSTALL_APP_PATH/Contents/MacOS/Sirious"

cleanup() {
    if [ "$KEEP_INSTALLED" -eq 0 ]; then
        rm -rf "$INSTALL_APP_PATH"
    fi
}

trap cleanup EXIT

cd "$REPO_ROOT"

if [ "$SKIP_BUILD" -eq 0 ]; then
    log "Building Sirious $CONFIGURATION into $DERIVED_DATA_PATH."
    xcodebuild build \
        -project Sirious.xcodeproj \
        -scheme Sirious \
        -configuration "$CONFIGURATION" \
        -destination "platform=macOS,arch=arm64" \
        -derivedDataPath "$DERIVED_DATA_PATH"
fi

[ -d "$BUILT_APP_PATH" ] || fail "Expected built app at $BUILT_APP_PATH, but it does not exist."

log "Installing validation copy at $INSTALL_APP_PATH."
mkdir -p "$(dirname -- "$INSTALL_APP_PATH")"
rm -rf "$INSTALL_APP_PATH"
cp -R "$BUILT_APP_PATH" "$INSTALL_APP_PATH"

[ -x "$INSTALLED_APP_EXECUTABLE" ] || fail "Installed app executable is missing or not executable at $INSTALLED_APP_EXECUTABLE."
[ -x "$INSTALLED_HELPER_PATH" ] || fail "Installed helper executable is missing or not executable at $INSTALLED_HELPER_PATH."
[ -f "$INSTALLED_AGENT_PLIST" ] || fail "Installed LaunchAgent plist is missing at $INSTALLED_AGENT_PLIST."

log "Installed app signature:"
codesign --verify --deep --strict --verbose=2 "$INSTALL_APP_PATH"

log "Installed helper signature:"
codesign --verify --strict --verbose=2 "$INSTALLED_HELPER_PATH"

log "Installed LaunchAgent plist:"
plutil -p "$INSTALLED_AGENT_PLIST"

log "Direct helper diagnostic:"
"$INSTALLED_HELPER_PATH" --status

log "ServiceManagement status from installed app:"
STATUS_OUTPUT=$("$INSTALLED_APP_EXECUTABLE" --automation-helper-status)
printf '%s\n' "$STATUS_OUTPUT"

case "$STATUS_OUTPUT" in
    *notFound*)
        fail "ServiceManagement still reports the automation helper as notFound from the installed app at $INSTALL_APP_PATH."
        ;;
esac

if [ "$RUN_REGISTRATION" -eq 0 ]; then
    log "Skipping registration because --register was not provided."
    exit 0
fi

log "Registering installed automation helper."
"$INSTALLED_APP_EXECUTABLE" --automation-helper-register

log "ServiceManagement status after registration:"
REGISTERED_STATUS_OUTPUT=$("$INSTALLED_APP_EXECUTABLE" --automation-helper-status)
printf '%s\n' "$REGISTERED_STATUS_OUTPUT"

case "$REGISTERED_STATUS_OUTPUT" in
    *enabled*)
        log "Checking installed automation helper XPC status."
        "$INSTALLED_APP_EXECUTABLE" --automation-helper-xpc-status
        ;;
    *requiresApproval*)
        log "macOS requires Login Items approval before the LaunchAgent can run; skipping XPC status until approval is granted."
        ;;
    *)
        fail "Expected enabled or requiresApproval after registration, but got: $REGISTERED_STATUS_OUTPUT"
        ;;
esac

log "Unregistering installed automation helper."
"$INSTALLED_APP_EXECUTABLE" --automation-helper-unregister
