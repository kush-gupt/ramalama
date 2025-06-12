#!/bin/bash
# Mock for 'sudo podman' commands for BATS testing

COMMAND_LOG="/tmp/sudo_podman_mock_commands.log"
MOCK_OUTPUT_FILE="/tmp/sudo_podman_mock_output.txt"
MOCK_STDERR_FILE="/tmp/sudo_podman_mock_stderr.txt"
MOCK_EXIT_CODE_FILE="/tmp/sudo_podman_mock_exit_code.txt"

# Log the command and its arguments as received by this script
# If this script is called by a mock 'sudo' as: sudo_mock_script.sh podman ps -a
# then "$@" here will be "podman ps -a"
echo "$@" >> "${COMMAND_LOG}"

# Default exit code is success
exit_code=0
if [ -f "${MOCK_EXIT_CODE_FILE}" ]; then
    exit_code=$(cat "${MOCK_EXIT_CODE_FILE}")
fi

# Output predefined stdout if MOCK_OUTPUT_FILE exists
if [ -f "${MOCK_OUTPUT_FILE}" ]; then
    cat "${MOCK_OUTPUT_FILE}"
fi

# Output predefined stderr if MOCK_STDERR_FILE exists
if [ -f "${MOCK_STDERR_FILE}" ]; then
    cat "${MOCK_STDERR_FILE}" >&2
fi

exit "${exit_code}"
