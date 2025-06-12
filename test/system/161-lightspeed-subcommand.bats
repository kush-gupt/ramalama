#!/usr/bin/env bats
#
# Tests for 'ramalama lightspeed' subcommand

# Set the correct path to the ramalama executable and ensure Python 3.11 is used
export RAMALAMA="python3.11 ./bin/ramalama"

load '/usr/lib/bats/bats-support/load.bash'
load '/usr/lib/bats/bats-assert/load.bash'
# Note: helpers.bash is not explicitly loaded here as these tests focus on cli arg construction
# and mock podman. If it were loaded, PODMAN="sudo" might need to be set for its internal calls,
# but here we mock 'sudo' itself as a script that calls our mock 'podman'.

DEFAULT_PROXY_PORT="8888"
CUSTOM_PROXY_PORT="9999"

# --- Mocking setup ---
SUDO_PODMAN_MOCK_DIR="${BATS_TMPDIR}/mock_bin" # BATS_TMPDIR is unique per test file run
# BATS_TEST_DIRNAME is the directory of the current .bats file
SUDO_PODMAN_MOCK_SCRIPT_PATH="${BATS_TEST_DIRNAME}/sudo_podman_mock.sh"

COMMAND_LOG="/tmp/sudo_podman_mock_commands.log" # Consistent with mock script
MOCK_OUTPUT_FILE="/tmp/sudo_podman_mock_output.txt"
MOCK_STDERR_FILE="/tmp/sudo_podman_mock_stderr.txt"
MOCK_EXIT_CODE_FILE="/tmp/sudo_podman_mock_exit_code.txt"

setup() {
    # Runs before each test
    mkdir -p "${SUDO_PODMAN_MOCK_DIR}"
    # Create a mock 'sudo' script that will call our 'sudo_podman_mock.sh'
    # The arguments to this mock 'sudo' script will be "podman", "ps", "-a", etc.
    # The mock 'sudo' script will then execute 'sudo_podman_mock.sh podman ps -a ...'
    echo "DEBUG: SUDO_PODMAN_MOCK_SCRIPT_PATH is ${SUDO_PODMAN_MOCK_SCRIPT_PATH}" >&3
    ls -l "${SUDO_PODMAN_MOCK_SCRIPT_PATH}" >&3

    cat <<EOF > "${SUDO_PODMAN_MOCK_DIR}/sudo"
#!/bin/bash
# This mock 'sudo' executes the SUDO_PODMAN_MOCK_SCRIPT_PATH with all arguments it receives.
# If called as "sudo podman ps", then SUDO_PODMAN_MOCK_SCRIPT_PATH gets "podman ps" as its arguments.
exec "${SUDO_PODMAN_MOCK_SCRIPT_PATH}" "\$@"
EOF
    chmod +x "${SUDO_PODMAN_MOCK_DIR}/sudo"
    echo "DEBUG: Mock sudo script at ${SUDO_PODMAN_MOCK_DIR}/sudo" >&3
    ls -l "${SUDO_PODMAN_MOCK_DIR}/sudo" >&3
    echo "DEBUG: Content of mock sudo script:" >&3
    cat "${SUDO_PODMAN_MOCK_DIR}/sudo" >&3

    export PATH="${SUDO_PODMAN_MOCK_DIR}:${PATH}" # Prepend mock to PATH
    echo "DEBUG: PATH is now ${PATH}" >&3

    # Clean up mock control files before each test
    rm -f "${COMMAND_LOG}" "${MOCK_OUTPUT_FILE}" "${MOCK_STDERR_FILE}" "${MOCK_EXIT_CODE_FILE}"
    touch "${COMMAND_LOG}" # Ensure it exists
}

teardown() {
    # Runs after each test
    # Crucial: remove mock from PATH to not interfere with other BATS files if run in same session
    export PATH=$(echo $PATH | sed -e "s|${SUDO_PODMAN_MOCK_DIR}:||" -e "s|:${SUDO_PODMAN_MOCK_DIR}||" -e "s|${SUDO_PODMAN_MOCK_DIR}||")
    rm -rf "${SUDO_PODMAN_MOCK_DIR}"
    rm -f "${COMMAND_LOG}" "${MOCK_OUTPUT_FILE}" "${MOCK_STDERR_FILE}" "${MOCK_EXIT_CODE_FILE}"
}
# --- End Mocking setup ---


@test "ramalama lightspeed: uses default proxy port and default client-core options" {
    # Mock 'sudo podman ps' to indicate container is ALREADY running for this baseline test
    echo "Up SomeTime" > "${MOCK_OUTPUT_FILE}"
    echo "0" > "${MOCK_EXIT_CODE_FILE}"

    run $RAMALAMA --debug lightspeed "test query" 2>&1
    assert_success # ramalama itself should succeed, client-core will fail to connect to mock
    assert_output --partial "Executing ramalama-client-core with args:"
    assert_output --partial "'libexec/ramalama/ramalama-client-core'"
    assert_output --partial "'http://localhost:${DEFAULT_PROXY_PORT}'"
    assert_output --partial "'test query'"
    assert_output --partial "'-c'"
    assert_output --partial "'2048'"
    assert_output --partial "'--temp'"
    assert_output --partial "'0.8'"
}

@test "ramalama lightspeed: uses custom --proxy-port and default client-core options" {
    # Mock 'sudo podman ps' to indicate container is ALREADY running
    echo "Up SomeTime" > "${MOCK_OUTPUT_FILE}"
    echo "0" > "${MOCK_EXIT_CODE_FILE}"

    run $RAMALAMA --debug lightspeed --proxy-port "${CUSTOM_PROXY_PORT}" "another query" 2>&1
    assert_success # ramalama itself should succeed
    assert_output --partial "Executing ramalama-client-core with args:"
    assert_output --partial "'libexec/ramalama/ramalama-client-core'"
    assert_output --partial "'http://localhost:${CUSTOM_PROXY_PORT}'"
    assert_output --partial "'another query'"
    assert_output --partial "'-c'"
    assert_output --partial "'2048'"
    assert_output --partial "'--temp'"
    assert_output --partial "'0.8'"
}

@test "ramalama lightspeed: passes multiple query arguments correctly with defaults" {
    # Mock 'sudo podman ps' to indicate container is ALREADY running
    echo "Up SomeTime" > "${MOCK_OUTPUT_FILE}"
    echo "0" > "${MOCK_EXIT_CODE_FILE}"

    run $RAMALAMA --debug lightspeed "hello" "multiple words" 2>&1
    assert_success # ramalama itself should succeed
    assert_output --partial "Executing ramalama-client-core with args:"
    assert_output --partial "'libexec/ramalama/ramalama-client-core'"
    assert_output --partial "'http://localhost:${DEFAULT_PROXY_PORT}'"
    assert_output --partial "'hello'"
    assert_output --partial "'multiple words'"
    assert_output --partial "'-c'"
    assert_output --partial "'2048'"
}

@test "ramalama lightspeed: passes custom client-core options and query" {
    # Mock 'sudo podman ps' to indicate container is ALREADY running
    echo "Up SomeTime" > "${MOCK_OUTPUT_FILE}"
    echo "0" > "${MOCK_EXIT_CODE_FILE}"

    run $RAMALAMA --debug lightspeed -- --custom-flag --option-val=something "my custom query" 2>&1
    assert_failure # Expecting ramalama (and thus client-core) to fail due to unrecognized args for client-core
    assert_output --partial "Executing ramalama-client-core with args:"
    assert_output --partial "'libexec/ramalama/ramalama-client-core'"
    assert_output --partial "'http://localhost:${DEFAULT_PROXY_PORT}'"
    assert_output --partial "'--custom-flag'"
    assert_output --partial "'--option-val=something'"
    assert_output --partial "'my custom query'"

    refute_output --partial "'-c', '2048'"
    refute_output --partial "'--temp', '0.8'"
}

@test "ramalama lightspeed: handles empty query with default options" {
    # Mock 'sudo podman ps' to indicate container is ALREADY running
    echo "Up SomeTime" > "${MOCK_OUTPUT_FILE}"
    echo "0" > "${MOCK_EXIT_CODE_FILE}"

    run $RAMALAMA --debug lightspeed 2>&1
    assert_success # ramalama itself should succeed
    assert_output --partial "Executing ramalama-client-core with args:"
    assert_output --partial "'libexec/ramalama/ramalama-client-core'"
    assert_output --partial "'http://localhost:${DEFAULT_PROXY_PORT}'"
    assert_output --partial "'-c'"
    assert_output --partial "'2048'"
    assert_output --partial "'--temp'"
    assert_output --partial "'0.8'"
}

@test "ramalama lightspeed: --help shows help" {
    # This test should not involve podman calls, so mock setup is less critical
    run $RAMALAMA lightspeed --help
    assert_success
    assert_output --partial "usage: ramalama lightspeed"
    assert_output --partial "--proxy-port"
}

# --- New tests for proxy management ---

DEFAULT_CONTAINER_NAME="ramalama-rhel-lightspeed-proxy-active"
DEFAULT_IMAGE_NAME="rhel-lightspeed-proxy:latest"

@test "ramalama lightspeed: attempts to start proxy if not running" {
    # Mock 'podman ps' to return nothing (not running, not exited) for the first call
    echo "" > "${MOCK_OUTPUT_FILE}"
    echo "0" > "${MOCK_EXIT_CODE_FILE}" # podman ps success

    # Mock 'podman run' to succeed for the second call by the mock
    # It will be called after 'ps' fails to find container.
    # The mock will then need to simulate 'ps' again for the *next* check if lightspeed_cli calls it.
    # For this test, we'll just check that 'run' was attempted.
    # The python code calls _is_proxy_container_running, then _start_proxy_container.
    # _start_proxy_container runs 'podman run' and then sleeps.

    run $RAMALAMA --debug lightspeed "query" 2>&1
    # Ramalama command itself should succeed if podman run mock succeeds (mock returns 0 for run)
    # and client-core then fails to connect (as no real server is started by mock)
    # $output from the above 'run' will contain debug from ramalama.
    # $status from the above 'run' is what assert_success checks.
    assert_success
    local ramalama_debug_output="$output" # Store ramalama's debug output
    echo "Stored ramalama_debug_output for test 'attempts to start proxy if not running':" >&3
    echo "-------------------------------------" >&3
    echo "$ramalama_debug_output" >&3
    echo "-------------------------------------" >&3

    run cat "${COMMAND_LOG}" # This overwrites $output with the command log
    assert_output --partial "podman ps -a --filter name=^/${DEFAULT_CONTAINER_NAME}$ --format {{.Status}}"
    assert_output --partial "podman run -d --rm --name ${DEFAULT_CONTAINER_NAME} -p ${DEFAULT_PROXY_PORT}:8888 --security-opt seccomp=unconfined ${DEFAULT_IMAGE_NAME}"

    # Check that ramalama-client-core execution is then attempted (from the stored ramalama_debug_output)
    run bash -c "echo \"${ramalama_debug_output}\" | grep -q -- \"Executing ramalama-client-core with args:\""
    assert_success
    run bash -c "echo \"${ramalama_debug_output}\" | grep -q -- \"http://localhost:${DEFAULT_PROXY_PORT}\""
    assert_success
}

@test "ramalama lightspeed: uses existing running proxy" {
    echo "Up SomeTime" > "${MOCK_OUTPUT_FILE}" # podman ps returns "Up"
    echo "0" > "${MOCK_EXIT_CODE_FILE}"

    run $RAMALAMA --debug lightspeed "query" 2>&1
    assert_success # ramalama itself succeeds, client-core will fail to connect
    local ramalama_debug_output="$output" # Store ramalama's debug output
    echo "Stored ramalama_debug_output for test 'uses existing running proxy':" >&3
    echo "-------------------------------------" >&3
    echo "$ramalama_debug_output" >&3
    echo "-------------------------------------" >&3

    run cat "${COMMAND_LOG}" # This overwrites $output
    assert_output --partial "podman ps -a --filter name=^/${DEFAULT_CONTAINER_NAME}$ --format {{.Status}}" # ps was called
    refute_output --partial "podman run" # run should NOT be called

    run bash -c "echo \"${ramalama_debug_output}\" | grep -q -- \"Executing ramalama-client-core with args:\""
    assert_success
}

@test "ramalama lightspeed: removes exited proxy and attempts restart" {
    # Sequence of mock interactions:
    # 1. podman ps (is_running) -> returns "Exited", exit 0
    # 2. podman rm (is_running) -> returns success (no output), exit 0
    # 3. podman run (start_proxy) -> returns success (container id), exit 0

    # Setup for first 'ps' call
    echo "Exited (0) 1 minute ago" > "${MOCK_OUTPUT_FILE}"
    echo "0" > "${MOCK_EXIT_CODE_FILE}"

    run $RAMALAMA --debug lightspeed "query" 2>&1
    assert_success # ramalama itself succeeds
    local ramalama_debug_output_for_log_check="$output" # Capture output before it's overwritten by cat

    run cat "${COMMAND_LOG}"
    assert_output --partial "podman ps -a --filter name=^/${DEFAULT_CONTAINER_NAME}$ --format {{.Status}}"
    assert_output --partial "podman rm ${DEFAULT_CONTAINER_NAME}"
    assert_output --partial "podman run -d --rm --name ${DEFAULT_CONTAINER_NAME}"
}

@test "ramalama lightspeed: handles proxy image not found" {
    # 1. podman ps -> returns not running
    echo "" > "${MOCK_OUTPUT_FILE}"
    echo "0" > "${MOCK_EXIT_CODE_FILE}"

    # Setup for 'podman run' to fail with image not found
    # This requires the mock to be configured *before* $RAMALAMA is called.
    # The mock script reads these files when 'sudo podman run' is invoked by ramalama.
    # So, we need a way for the mock to change behavior *between* calls if ramalama makes multiple podman calls.
    # The current mock is simple and uses one set of files per test.
    # For this test, the first 'ps' says "not found". The 'run' then fails.
    # We need to set MOCK_STDERR_FILE and MOCK_EXIT_CODE_FILE for the 'run' command part of the mock.

    # This run will call 'sudo podman ps' (mocked by setup to return "" and 0)
    # then 'sudo podman run' (mocked by files below to fail)
    (
      echo "" > "${MOCK_OUTPUT_FILE}";
      echo "Error: unable to find image '${DEFAULT_IMAGE_NAME}'" > "${MOCK_STDERR_FILE}";
      echo "125" > "${MOCK_EXIT_CODE_FILE}"; # This exit code will be for the 'podman run'
    )

    run $RAMALAMA lightspeed "query" # No --debug, check perror output
    assert_failure # Ramalama command should fail and print to stderr via perror
    assert_output --partial "Error: Proxy image '${DEFAULT_IMAGE_NAME}' not found."
}

@test "ramalama lightspeed: handles port conflict on proxy start" {
    local test_port="7777"
    # 1. podman ps -> not running
    echo "" > "${MOCK_OUTPUT_FILE}"
    echo "0" > "${MOCK_EXIT_CODE_FILE}" # ps success

    # 2. podman run -> port conflict error
    # This setup is for the 'podman run' call
    (
      echo "Error: some_other_stuff... port is already allocated: ..." > "${MOCK_STDERR_FILE}";
      echo "125" > "${MOCK_EXIT_CODE_FILE}"; # podman run exit code for failure
    )

    run $RAMALAMA lightspeed --proxy-port "${test_port}" "query"
    assert_failure
    assert_output --partial "Error: Host port ${test_port} is already in use."
}

@test "ramalama lightspeed: handles 'sudo podman' command not found" {
    # This test is tricky because PATH is manipulated by setup/teardown.
    # To truly test "sudo podman" not found, "sudo" (the mock) would need to exist,
    # but "podman" (which the mock 'sudo' calls via SUDO_PODMAN_MOCK_SCRIPT_PATH) would not.
    # The current python code looks for FileNotFoundError on the "sudo" call.
    # A more direct way: make the mock 'sudo' script itself exit as if 'podman' was not found by it.
    # This means `SUDO_PODMAN_MOCK_SCRIPT_PATH` would point to a non-existent file *for this test only*.
    # This is too complex for the current mock setup.

    # Alternative: Test the Python code's FileNotFoundError for "sudo" itself.
    # Temporarily remove the mock 'sudo' from PATH for this test.
    local original_path="${PATH}"
    export PATH=$(echo $PATH | sed -e "s|${SUDO_PODMAN_MOCK_DIR}:||" -e "s|:${SUDO_PODMAN_MOCK_DIR}||" -e "s|${SUDO_PODMAN_MOCK_DIR}||")
    # And ensure our mock script isn't accidentally called if 'sudo' is actually present and passwordless
    # by making the script it would call non-executable temporarily or invalid.
    # However, if actual 'sudo podman' exists and works passwordlessly, this test might pass for wrong reasons or hang.

    # Given the complexity and potential flakiness of manipulating PATH this way mid-test for BATS,
    # and that the Python code directly catches FileNotFoundError for "sudo",
    # this specific scenario (sudo itself not found) is better for unit tests.
    # The current Python code raises RuntimeError("Podman not found, cannot manage proxy.")
    # if "sudo podman" FileNotFoundError happens.

    # Forcing the mock 'sudo' to simulate 'command not found' for 'podman'
    # This means our mock 'sudo' script would try to exec "$SUDO_PODMAN_MOCK_SCRIPT_PATH" "podman" ...
    # and if $SUDO_PODMAN_MOCK_SCRIPT_PATH was invalid, it would fail.
    # This is not what the python code is testing for "sudo podman not found". It's "sudo" not found.

    # Make the mock 'sudo' script itself non-executable to trigger FileNotFoundError in Python
    chmod -x "${SUDO_PODMAN_MOCK_DIR}/sudo"

    run $RAMALAMA lightspeed "query" 2>&1 # Capture stderr for perror message
    assert_failure
    assert_output --partial "sudo podman command not found. Cannot manage proxy container."

    # Restore for other tests if any (though teardown should handle it)
    # Teardown will recreate the mock dir and script anyway, but good practice if not.
    chmod +x "${SUDO_PODMAN_MOCK_DIR}/sudo"
    export PATH="${original_path}" # Restore original PATH
}
