#!/bin/bash
# Run Android AI Agent Tests with arbigent
# This script ensures the emulator is running, sets orientation, and runs tests

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
EMULATOR_PATH="${HOME}/Library/Android/sdk/emulator/emulator"
ADB_PATH="${HOME}/Library/Android/sdk/platform-tools/adb"
AVD_NAME="${AVD_NAME:-Medium_Phone_API_36.1}"

# Arbigent configuration
AI_TYPE="${AI_TYPE:-gemini}"
GEMINI_MODEL="${GEMINI_MODEL:-gemini-2.0-flash}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if GEMINI_API_KEY is set
check_api_key() {
    if [ -z "$GEMINI_API_KEY" ]; then
        log_error "GEMINI_API_KEY environment variable is not set"
        exit 1
    fi
}

# Check if emulator is running
is_emulator_running() {
    "$ADB_PATH" devices | grep -q "emulator"
}

# Start emulator if not running
start_emulator() {
    if is_emulator_running; then
        log_info "Emulator is already running"
    else
        log_info "Starting emulator: $AVD_NAME"
        "$EMULATOR_PATH" -avd "$AVD_NAME" -no-snapshot-load &
        
        log_info "Waiting for emulator to boot..."
        "$ADB_PATH" wait-for-device
        
        # Wait for boot to complete
        while [ "$("$ADB_PATH" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" != "1" ]; do
            sleep 2
        done
        
        log_info "Emulator booted successfully"
        sleep 3  # Extra wait for UI to stabilize
    fi
}

# Rotate the emulator 90° clockwise
rotate() {
    "$ADB_PATH" emu rotate
}

# Run arbigent test
run_arbigent_test() {
    local project_file=$1
    local test_name=$2
    
    log_info "Running arbigent test: $test_name"
    log_info "Project file: $project_file"
    
    arbigent run \
        --project-file="$project_file" \
        --ai-type="$AI_TYPE" \
        --gemini-model-name="$GEMINI_MODEL" \
        --gemini-api-key="$GEMINI_API_KEY"
    
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        log_info "✅ Test passed: $test_name"
    else
        log_error "❌ Test failed: $test_name (exit code: $exit_code)"
    fi
    
    return $exit_code
}

# Main execution
main() {
    log_info "Starting Android AI Agent Test Suite"
    log_info "======================================"
    
    check_api_key
    start_emulator
    
    local test_results=()
    
    # Test 1: Upright (Portrait)
    log_info ""
    log_info "=== Test 1: Upright (Portrait) ==="
    "$ADB_PATH" shell settings put system accelerometer_rotation 0
    "$ADB_PATH" shell settings put system user_rotation 0
    sleep 2
    
    if run_arbigent_test "$SCRIPT_DIR/android-portrait.yaml" "Portrait Test"; then
        test_results+=("Portrait: PASS")
    else
        test_results+=("Portrait: FAIL")
    fi
    
    # Test 2: Landscape-Left (rotate 3x clockwise = 270°)
    log_info ""
    log_info "=== Test 2: Landscape-Left (3x rotate) ==="
    log_info "Rotating 3x clockwise..."
    rotate
    rotate
    rotate
    "$ADB_PATH" shell settings put system user_rotation 3
    sleep 2
    
    if run_arbigent_test "$SCRIPT_DIR/android-landscape.yaml" "Landscape Test"; then
        test_results+=("Landscape: PASS")
    else
        test_results+=("Landscape: FAIL")
    fi
    
    # Cleanup: rotate 1 more time to get back to upright
    log_info ""
    log_info "Cleanup: rotating 1x to return to upright..."
    rotate
    "$ADB_PATH" shell settings put system user_rotation 0
    
    # Summary
    log_info ""
    log_info "======================================"
    log_info "Test Summary:"
    for result in "${test_results[@]}"; do
        if [[ "$result" == *"PASS"* ]]; then
            echo -e "  ${GREEN}✅ $result${NC}"
        else
            echo -e "  ${RED}❌ $result${NC}"
        fi
    done
    
    # Return failure if any test failed
    for result in "${test_results[@]}"; do
        if [[ "$result" == *"FAIL"* ]]; then
            exit 1
        fi
    done
    
    log_info "All tests passed!"
}

main "$@"

