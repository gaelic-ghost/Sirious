#!/usr/bin/env sh
set -eu

SELF_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SELF_DIR/.." && pwd)

CONFIGURATION=Debug
DERIVED_DATA_PATH="$REPO_ROOT/.build/InstalledAppValidation/DerivedData"
INSTALL_APP_PATH="$REPO_ROOT/.build/InstalledAppValidation/Sirious.app"
INSTALL_APP_PATH_WAS_SET=0
PACKAGE_PATH="$REPO_ROOT/.build/InstalledAppValidation/SiriousInstalledAppValidation.pkg"
PACKAGE_ROOT="$REPO_ROOT/.build/InstalledAppValidation/PackageRoot"
PACKAGE_COMPONENT_PLIST="$REPO_ROOT/.build/InstalledAppValidation/SiriousInstalledAppValidation-components.plist"
PACKAGE_IDENTIFIER="com.galewilliams.Sirious.InstalledAppValidation"
PACKAGE_VERSION=1
PACKAGE_STYLE=0
RUN_REGISTRATION=0
REQUIRE_SERVICE_FOUND=0
KEEP_INSTALLED=0
SKIP_BUILD=0
UNINSTALL_ONLY=0

usage() {
    cat <<'USAGE'
Usage: scripts/validate-installed-automation-helper.sh [options]

Build Sirious, copy the app to a stable local test path, and validate the bundled
SiriousAutomationHelper LaunchAgent shape.

Options:
  --configuration NAME     Xcode configuration to build. Default: Debug.
  --derived-data PATH      DerivedData path for the validation build.
  --install-app PATH       Destination .app path for the test install.
  --package-style          Install the validation app through a local .pkg first.
  --package-path PATH      Local package output path. Default: repo .build path.
  --package-root PATH      Local package staging root. Default: repo .build path.
  --package-components PATH
                           Local component plist path. Default: repo .build path.
  --register               Register, XPC-check, and unregister the LaunchAgent.
  --require-service-found  Fail when Service Management reports notFound.
  --skip-build             Reuse the app already built under the DerivedData path.
  --keep-installed         Leave the copied .app in place after validation.
  --uninstall              Remove the validation .app at --install-app and exit.
  -h, --help               Show this help.

The default install path stays inside the repository's .build directory. Passing
--keep-installed keeps the validation copy so the next run updates it in place.
For a closer local install test, pass a stable user location such as:

  --install-app "$HOME/Applications/SiriousInstalledAppValidation/Sirious.app"

For a package-style probe, install the validation app through macOS Installer
into a user Application Support location before checking Service Management:

  --package-style --keep-installed

Remove a retained validation copy with:

  --install-app "$HOME/Applications/SiriousInstalledAppValidation/Sirious.app" --uninstall
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
            INSTALL_APP_PATH_WAS_SET=1
            shift 2
            ;;
        --package-style)
            PACKAGE_STYLE=1
            shift
            ;;
        --package-path)
            [ "$#" -ge 2 ] || fail "--package-path requires a value."
            PACKAGE_PATH=$2
            shift 2
            ;;
        --package-root)
            [ "$#" -ge 2 ] || fail "--package-root requires a value."
            PACKAGE_ROOT=$2
            shift 2
            ;;
        --package-components)
            [ "$#" -ge 2 ] || fail "--package-components requires a value."
            PACKAGE_COMPONENT_PLIST=$2
            shift 2
            ;;
        --register)
            RUN_REGISTRATION=1
            shift
            ;;
        --require-service-found)
            REQUIRE_SERVICE_FOUND=1
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
        --uninstall)
            UNINSTALL_ONLY=1
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

if [ "$PACKAGE_STYLE" -eq 1 ] && [ "$INSTALL_APP_PATH_WAS_SET" -eq 0 ]; then
    INSTALL_APP_PATH="$HOME/Library/Application Support/SiriousInstalledAppValidation/Sirious.app"
fi

PACKAGE_PAYLOAD_APP_PATH=
if [ "$PACKAGE_STYLE" -eq 1 ]; then
    case "$INSTALL_APP_PATH" in
        "$HOME"/*)
            PACKAGE_PAYLOAD_APP_PATH=${INSTALL_APP_PATH#"$HOME"/}
            ;;
        *)
            fail "--package-style requires --install-app to be under $HOME so installer -target CurrentUserHomeDirectory writes only to the current user's domain."
            ;;
    esac
fi

BUILT_APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/Sirious.app"
INSTALLED_HELPER_PATH="$INSTALL_APP_PATH/Contents/Resources/SiriousAutomationHelper"
INSTALLED_AGENT_PLIST="$INSTALL_APP_PATH/Contents/Library/LaunchAgents/com.galewilliams.Sirious.AutomationHelper.plist"
INSTALLED_APP_EXECUTABLE="$INSTALL_APP_PATH/Contents/MacOS/Sirious"

remove_installed_app() {
    if [ -e "$INSTALL_APP_PATH" ]; then
        log "Removing validation app copy at $INSTALL_APP_PATH."
        rm -rf "$INSTALL_APP_PATH"
    else
        log "No validation app copy exists at $INSTALL_APP_PATH."
    fi
}

cleanup() {
    if [ "$KEEP_INSTALLED" -eq 0 ]; then
        remove_installed_app
    fi
}

install_validation_copy() {
    log "Installing validation copy at $INSTALL_APP_PATH."
    mkdir -p "$(dirname -- "$INSTALL_APP_PATH")"
    rm -rf "$INSTALL_APP_PATH"
    cp -R "$BUILT_APP_PATH" "$INSTALL_APP_PATH"
}

install_validation_package() {
    log "Staging validation package root at $PACKAGE_ROOT."
    rm -rf "$PACKAGE_ROOT"
    mkdir -p "$(dirname -- "$PACKAGE_ROOT/$PACKAGE_PAYLOAD_APP_PATH")"
    cp -R "$BUILT_APP_PATH" "$PACKAGE_ROOT/$PACKAGE_PAYLOAD_APP_PATH"

    log "Writing validation package component plist at $PACKAGE_COMPONENT_PLIST."
    mkdir -p "$(dirname -- "$PACKAGE_COMPONENT_PLIST")"
    cat > "$PACKAGE_COMPONENT_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<array>
  <dict>
    <key>RootRelativeBundlePath</key>
    <string>$PACKAGE_PAYLOAD_APP_PATH</string>
    <key>BundleIsRelocatable</key>
    <false/>
    <key>BundleIsVersionChecked</key>
    <false/>
    <key>BundleHasStrictIdentifier</key>
    <true/>
    <key>BundleOverwriteAction</key>
    <string>upgrade</string>
  </dict>
</array>
</plist>
PLIST

    log "Building validation package at $PACKAGE_PATH."
    mkdir -p "$(dirname -- "$PACKAGE_PATH")"
    rm -f "$PACKAGE_PATH"
    pkgbuild \
        --root "$PACKAGE_ROOT" \
        --component-plist "$PACKAGE_COMPONENT_PLIST" \
        --install-location "/" \
        --identifier "$PACKAGE_IDENTIFIER" \
        --version "$PACKAGE_VERSION" \
        "$PACKAGE_PATH"

    log "Installing validation package into $HOME."
    rm -rf "$INSTALL_APP_PATH"
    installer -pkg "$PACKAGE_PATH" -target CurrentUserHomeDirectory
}

if [ "$UNINSTALL_ONLY" -eq 1 ]; then
    remove_installed_app
    exit 0
fi

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

if [ "$PACKAGE_STYLE" -eq 1 ]; then
    install_validation_package
else
    install_validation_copy
fi

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
        if [ "$RUN_REGISTRATION" -eq 1 ] || [ "$REQUIRE_SERVICE_FOUND" -eq 1 ]; then
            if [ "$PACKAGE_STYLE" -eq 1 ]; then
                fail "ServiceManagement reports the automation helper as notFound from the package-installed app at $INSTALL_APP_PATH, so registration and XPC validation cannot continue. The package-style install verified the helper bundle shape, but macOS still does not recognize this app as a Service Management automation helper container."
            fi

            fail "ServiceManagement reports the automation helper as notFound from the installed app at $INSTALL_APP_PATH, so registration and XPC validation cannot continue. This usually means macOS does not recognize the copied validation app as an installed Service Management container; use --package-style to compare against the Installer-based Application Support probe before treating the helper plist or executable layout as broken."
        fi

        log "ServiceManagement reports the automation helper as notFound from the installed app at $INSTALL_APP_PATH."
        if [ "$PACKAGE_STYLE" -eq 1 ]; then
            log "Package-style install validation passed, but Service Management still does not recognize this app bundle as an automation helper container."
        else
            log "Bundle-shape validation passed, but registration remains blocked while Service Management reports notFound. Use --package-style to compare against the Installer-based Application Support probe before treating the helper plist or executable layout as broken."
        fi
        exit 0
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
