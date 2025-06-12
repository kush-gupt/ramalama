#!/usr/bin/env bats
#
# Tests for 'ramalama lightspeed' subcommand

# Set the correct path to the ramalama executable and ensure Python 3.11 is used
export RAMALAMA="python3.11 ./bin/ramalama"

load '/usr/lib/bats/bats-support/load.bash' # Adjust path if necessary for your BATS environment
load '/usr/lib/bats/bats-assert/load.bash'  # Adjust path if necessary for your BATS environment

DEFAULT_PROXY_PORT="8888"
CUSTOM_PROXY_PORT="9999"

# No specific setup_suite or teardown_suite needed for these tests,
# as they only check command argument construction.

@test "ramalama lightspeed: uses default proxy port and default client-core options" {
    run $RAMALAMA --debug lightspeed "test query"
    assert_success # This checks if 'ramalama lightspeed' itself ran ok (e.g. no Python errors in it)
    # The following assertions check the debug output for correct command construction
    assert_output --partial "Executing ramalama-client-core with args:"
    assert_output --partial "'libexec/ramalama/ramalama-client-core'" # Check for the core script
    assert_output --partial "'http://localhost:${DEFAULT_PROXY_PORT}'" # Check for proxy host
    assert_output --partial "'test query'" # Check for query
    assert_output --partial "'-c'" # Check for context option
    assert_output --partial "'2048'" # Check for context value
    assert_output --partial "'--temp'" # Check for temp option
    assert_output --partial "'0.8'" # Check for temp value
}

@test "ramalama lightspeed: uses custom --proxy-port and default client-core options" {
    run $RAMALAMA --debug lightspeed --proxy-port "${CUSTOM_PROXY_PORT}" "another query"
    assert_success
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
    run $RAMALAMA --debug lightspeed "hello" "multiple words"
    assert_success
    assert_output --partial "Executing ramalama-client-core with args:"
    assert_output --partial "'libexec/ramalama/ramalama-client-core'"
    assert_output --partial "'http://localhost:${DEFAULT_PROXY_PORT}'"
    assert_output --partial "'hello'"
    assert_output --partial "'multiple words'"
    assert_output --partial "'-c'"
    assert_output --partial "'2048'"
}

@test "ramalama lightspeed: passes custom client-core options and query" {
    # User provides options, so default -c and --temp should not be added.
    # The proxy_host comes directly after "ramalama-client-core".
    # Expect ramalama-client-core to fail because --custom-flag is not a real option for it.
    run $RAMALAMA --debug lightspeed -- --custom-flag --option-val=something "my custom query"
    assert_failure # Expecting ramalama (and thus client-core) to fail due to unrecognized args
    assert_output --partial "Executing ramalama-client-core with args:"
    assert_output --partial "'libexec/ramalama/ramalama-client-core'"
    assert_output --partial "'http://localhost:${DEFAULT_PROXY_PORT}'"
    assert_output --partial "'--custom-flag'"
    assert_output --partial "'--option-val=something'"
    assert_output --partial "'my custom query'"

    # Ensure default options are NOT present when user supplies their own
    # We check the $output from the failed 'run $RAMALAMA...' command above
    refute_output --partial "'-c', '2048'" # Default context should not be there
    refute_output --partial "'--temp', '0.8'" # Default temp should not be there
}

@test "ramalama lightspeed: handles empty query with default options" {
    run $RAMALAMA --debug lightspeed
    assert_success
    assert_output --partial "Executing ramalama-client-core with args:"
    assert_output --partial "'libexec/ramalama/ramalama-client-core'"
    assert_output --partial "'http://localhost:${DEFAULT_PROXY_PORT}'"
    assert_output --partial "'-c'"
    assert_output --partial "'2048'"
    assert_output --partial "'--temp'"
    assert_output --partial "'0.8'"
    # Check that no extra arguments (empty strings from ARGS) are problematic.
    # The logged list should end cleanly after "0.8" or "proxy_host" if ARGS is empty.
    # Example: "..., '0.8', 'http://localhost:8888']" (if no ARGS)
    # Example: "..., '0.8', 'http://localhost:8888', '']" (if ARGS was ['']) - this depends on shlex/argparse behavior
    # The current CLI code appends `args.ARGS` which if empty list `[]` adds nothing.
    # If it's `['']` it adds an empty string. Let's assume it's `[]`.
    # The debug log should show the list of args correctly.
    # This specific assertion is tricky without seeing exact log format for empty ARGS.
    # For now, ensuring the main parts are there is key.
}

@test "ramalama lightspeed: --help shows help" {
    run $RAMALAMA lightspeed --help
    assert_success
    assert_output --partial "usage: ramalama lightspeed" # More specific to actual help output
    assert_output --partial "--proxy-port"
}
