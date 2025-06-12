#!/usr/bin/env bats
#
# tests for RHEL Lightspeed Proxy Container

# Ensure helpers.podman.bash (loaded via helpers.bash) uses sudo podman.
# This must be set BEFORE helpers.bash is loaded.
export PODMAN="sudo podman"

load '/usr/lib/bats/bats-support/load.bash'
load '/usr/lib/bats/bats-assert/load.bash'
load helpers.bash

IMAGE_NAME="rhel-lightspeed-proxy:latest"
CONTAINER_NAME="lightspeed-proxy-bats-test"
PROXY_DIR="ramalama/proxy/rhel-lightspeed"
HOST_PORT="8889" # Use a different port for testing to avoid conflicts

function setup_suite() {
    # PODMAN is now set globally for helpers.bash to pick up.

    if ! command -v podman &> /dev/null; then
        skip "podman command not found, skipping suite."
    fi

    # Ensure we are in the repository root for relative paths
    if [ ! -d ".git" ]; then
        # Attempt to navigate to repo root if possible, otherwise skip
        if [ -d "../../../.git" ]; then # Heuristic, might need adjustment
            cd ../../../
        elif [ -d "../../.git" ]; then
            cd ../../
        elif [ -d "../.git" ]; then
            cd ../
        else
            skip "Could not determine repository root. Please run tests from the repo root."
        fi
    fi

    echo "Current working directory: $(pwd)"
    echo "Checking for proxy directory: ${PROXY_DIR}"
    if [ ! -d "${PROXY_DIR}" ]; then
        skip "Proxy directory ${PROXY_DIR} not found. Skipping suite."
    fi
    if [ ! -f "${PROXY_DIR}/Containerfile.rhel-lightspeed-proxy" ]; then
        skip "Containerfile for proxy not found in ${PROXY_DIR}. Skipping suite."
    fi

    echo "Building RHEL Lightspeed Proxy image..."
    # Use sudo and seccomp unconfined as identified in previous steps
    # Pipe to /dev/null to keep logs clean unless there's an error
    $PODMAN build --security-opt seccomp=unconfined -f "${PROXY_DIR}/Containerfile.rhel-lightspeed-proxy" -t "${IMAGE_NAME}" "${PROXY_DIR}" > /dev/null || {
        echo "Failed to build proxy image. Podman build output:"
        $PODMAN build --security-opt seccomp=unconfined -f "${PROXY_DIR}/Containerfile.rhel-lightspeed-proxy" -t "${IMAGE_NAME}" "${PROXY_DIR}"
        skip "Failed to build proxy image ${IMAGE_NAME}. Skipping suite."
    }

    # Clean up any old container instance
    $PODMAN rm -f "${CONTAINER_NAME}" 2>/dev/null || true
}

function teardown_suite() {
    $PODMAN rm -f "${CONTAINER_NAME}" 2>/dev/null || true
    # Optionally, remove the image:
    # $PODMAN rmi -f "${IMAGE_NAME}" 2>/dev/null || true
}

function teardown() {
    # Ensure container is stopped and removed after each test
    $PODMAN stop "${CONTAINER_NAME}" 2>/dev/null || true
    $PODMAN rm -f "${CONTAINER_NAME}" 2>/dev/null || true
}

@test "RHEL Lightspeed Proxy: Nginx fails to start without client certificates" {
    run $PODMAN run -d --name "${CONTAINER_NAME}" --security-opt seccomp=unconfined -p "${HOST_PORT}:8888" "${IMAGE_NAME}"
    assert_success "Should be able to start the container detached"

    # Give Nginx time to attempt startup and potentially fail
    sleep 10

    # Check container status - it might have exited
    container_status_output=$($PODMAN ps -a --filter name="^/${CONTAINER_NAME}$" --format "{{.Status}}")
    echo "Container status: ${container_status_output}"
    # Example status: "Exited (1) 5 seconds ago" or "Up 10 seconds" (if it somehow stayed up)
    # We expect it to have exited or be unhealthy if Nginx failed.

    # Fetch logs to check for the specific Nginx error
    logs_output=$($PODMAN logs "${CONTAINER_NAME}" 2>&1) # Capture both stdout and stderr
    echo "Container logs:"
    echo "${logs_output}"
    # Use 'run echo' to set $output for assert_output, making input explicit
    run echo "${logs_output}"
    assert_output --partial "cannot load certificate \"/etc/pki/consumer/cert.pem\""

    # Verify that Nginx is not listening on the port
    # Expect curl to fail to connect
    # Note: `run` is a BATS command that sets $status and $output.
    # We are testing the `curl` command here.
    run curl --max-time 5 http://localhost:${HOST_PORT}
    assert_failure "Curl should fail to connect as Nginx should not be listening"
    # Check for common curl connection failure messages
    assert_output --partial "Failed to connect" # Generic
    # Could also check for "Connection refused" or other specific messages if needed,
    # but "Failed to connect" is a common substring.
}
