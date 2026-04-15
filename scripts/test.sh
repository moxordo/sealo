#!/usr/bin/env bash
#
# scripts/test.sh — canonical headless test driver for sealo.
#
# This is the load-bearing feedback loop for the builder agent.
# Every iteration runs this script; an iteration that doesn't exit 0
# here is not done. See docs/01-plan.md "TDD + agent-runnable E2E?"
# and .claude/rules/docs-sync.md.
#
# What it does, in order:
#   1. Regenerate sealo.xcodeproj from project.yml via xcodegen.
#      (We git-ignore the .xcodeproj; project.yml is the source of truth.)
#   2. Wipe any previous build/latest.xcresult so results are fresh.
#   3. Run `xcodebuild test` against an iOS simulator destination.
#   4. Leave build/latest.xcresult on disk for the agent to parse via
#      `xcrun xcresulttool`.
#
# Exit codes:
#   0   all tests passed, zero warnings
#   1   tool-environment problem (xcodegen missing, Xcode not selected,
#       no iOS simulator available, etc.)
#   2   project generation failed
#   3   build or test step failed
#
# Environment knobs (all optional):
#   SIMULATOR_NAME   device name to use, default auto-pick latest iPhone
#   SIMULATOR_OS     runtime version pin, default latest available
#   SCHEME           Xcode scheme, default "sealo"
#   PROJECT          Xcode project path, default "sealo.xcodeproj"
#   RESULT_BUNDLE    path to write xcresult, default "build/latest.xcresult"
#   XCODEGEN         path to xcodegen binary, default auto-detect
#   VERBOSE          set to 1 to stream full xcodebuild output
#
# Usage:
#   ./scripts/test.sh                    # run once, pass/fail
#   VERBOSE=1 ./scripts/test.sh          # stream full output
#   ./scripts/test.sh --loop 100         # run 100 times, fail on any flake
#                                          (used for M2 flakiness gate)

set -o pipefail
set -u

# ------------------------------------------------------------------ config

readonly REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

SCHEME="${SCHEME:-sealo}"
PROJECT="${PROJECT:-sealo.xcodeproj}"
RESULT_BUNDLE="${RESULT_BUNDLE:-build/latest.xcresult}"
VERBOSE="${VERBOSE:-0}"

# ------------------------------------------------------------------ helpers

log()   { printf '\033[36m[test.sh]\033[0m %s\n' "$*" >&2; }
warn()  { printf '\033[33m[test.sh] WARN:\033[0m %s\n' "$*" >&2; }
die()   { printf '\033[31m[test.sh] FATAL:\033[0m %s\n' "$*" >&2; exit "${2:-1}"; }

# Resolve a usable xcodegen binary. Prefer $XCODEGEN, then PATH, then the
# local install at ~/.local/bin that the repo's bootstrap path used.
resolve_xcodegen() {
    if [[ -n "${XCODEGEN:-}" && -x "${XCODEGEN}" ]]; then
        echo "$XCODEGEN"
        return
    fi
    if command -v xcodegen >/dev/null 2>&1; then
        command -v xcodegen
        return
    fi
    if [[ -x "$HOME/.local/bin/xcodegen" ]]; then
        echo "$HOME/.local/bin/xcodegen"
        return
    fi
    return 1
}

# Pick the newest iPhone simulator runtime available on this machine.
# Returns a destination string usable with `xcodebuild -destination`.
pick_destination() {
    local name="${SIMULATOR_NAME:-}"
    local os="${SIMULATOR_OS:-}"

    if [[ -n "$name" && -n "$os" ]]; then
        echo "platform=iOS Simulator,name=${name},OS=${os}"
        return
    fi

    # Find the newest available iPhone simulator using POSIX tools
    # (macOS ships BSD awk which lacks GNU match() with captures).

    # 1. Get the latest iOS runtime version from simctl.
    local os_chosen
    os_chosen=$(xcrun simctl list runtimes 2>/dev/null \
        | grep 'com.apple.CoreSimulator.SimRuntime.iOS' \
        | tail -1 \
        | sed 's/.*iOS \([0-9.]*\) .*/\1/')

    # 2. Get the last listed iPhone device name.
    #    simctl list orders by runtime, so the last iPhone line is from
    #    the newest runtime. Device name is everything before the first " (".
    local name_chosen
    name_chosen=$(xcrun simctl list devices available 2>/dev/null \
        | grep 'iPhone' \
        | tail -1 \
        | sed 's/^[[:space:]]*//' \
        | sed 's/ (.*$//')

    if [[ -z "$name_chosen" || -z "$os_chosen" ]]; then
        die "No iPhone simulators available. Install an iOS runtime via \
'xcodebuild -downloadPlatform iOS' or Xcode > Settings > Platforms." 1
    fi

    echo "platform=iOS Simulator,name=${name_chosen},OS=${os_chosen}"
}

# ------------------------------------------------------------------ preflight

preflight() {
    log "preflight: checking tools"

    if ! XCODEGEN_BIN="$(resolve_xcodegen)"; then
        die "xcodegen not found. Install via \
github.com/yonaskolb/XcodeGen releases or 'brew install xcodegen'." 1
    fi

    if ! command -v xcodebuild >/dev/null 2>&1; then
        die "xcodebuild not found on PATH." 1
    fi

    local developer_dir
    developer_dir="$(xcode-select -p 2>/dev/null || true)"
    if [[ "$developer_dir" == *CommandLineTools* || -z "$developer_dir" ]]; then
        die "xcode-select points at '$developer_dir'. Run: \
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer" 1
    fi

    if [[ ! -f "$REPO_ROOT/project.yml" ]]; then
        die "project.yml not found at repo root — nothing to generate." 1
    fi

    log "preflight: OK (xcodegen=$XCODEGEN_BIN, DEVELOPER_DIR=$developer_dir)"
}

# ------------------------------------------------------------------ steps

regenerate_project() {
    log "regenerating $PROJECT from project.yml"
    if ! "$XCODEGEN_BIN" generate --spec project.yml >/tmp/xcodegen.log 2>&1; then
        cat /tmp/xcodegen.log >&2
        die "xcodegen generate failed" 2
    fi
    if [[ "$VERBOSE" == "1" ]]; then
        cat /tmp/xcodegen.log >&2
    fi
}

run_tests() {
    log "running xcodebuild test"

    rm -rf "$RESULT_BUNDLE"
    mkdir -p "$(dirname "$RESULT_BUNDLE")"

    local destination
    destination="$(pick_destination)"
    log "destination: $destination"

    local -a args=(
        -project "$PROJECT"
        -scheme "$SCHEME"
        -destination "$destination"
        -resultBundlePath "$RESULT_BUNDLE"
        -quiet
        CODE_SIGNING_ALLOWED=NO
        CODE_SIGNING_REQUIRED=NO
        CODE_SIGN_IDENTITY=""
        test
    )

    local status
    if [[ "$VERBOSE" == "1" ]]; then
        xcodebuild "${args[@]}"
        status=$?
    else
        xcodebuild "${args[@]}" 2>&1 | tail -40
        status=${PIPESTATUS[0]}
    fi

    if [[ "$status" -ne 0 ]]; then
        warn "xcodebuild test failed (status $status)"
        warn "result bundle at: $RESULT_BUNDLE"
        warn "inspect with: xcrun xcresulttool get --format json --path $RESULT_BUNDLE"
        return 3
    fi

    log "xcodebuild test: PASS"
    log "result bundle:  $RESULT_BUNDLE"
}

# ------------------------------------------------------------------ loop mode

run_once() {
    preflight
    regenerate_project
    run_tests
}

# --loop N: run run_once N times, fail on any non-zero.
# Used for the M2 flakiness gate ("zero flakiness over 100 consecutive runs").
main() {
    if [[ "${1:-}" == "--loop" ]]; then
        local n="${2:-1}"
        local i
        for (( i = 1; i <= n; i++ )); do
            log "loop iteration $i/$n"
            if ! run_once; then
                die "flaked on iteration $i/$n" 3
            fi
        done
        log "loop: $n/$n iterations passed"
    else
        run_once
    fi
}

main "$@"
