% ramalama-lightspeed 1

## NAME
ramalama-lightspeed - interact with RHEL Lightspeed API via a managed proxy

## SYNOPSIS
**ramalama lightspeed** [*options*] [_query_...]

## DESCRIPTION
The **ramalama lightspeed** command provides a convenient way to interact with the Red Hat Enterprise Linux (RHEL) Lightspeed API. It simplifies the process by attempting to automatically start and manage a local RHEL Lightspeed Proxy container if one is not already running. This proxy container handles the necessary client certificate authentication using RHSM certificates.

When invoked, `ramalama lightspeed` checks for an active proxy container named `ramalama-rhel-lightspeed-proxy-active`. If not found or not running, it will attempt to start one using `sudo podman run`. This requires that `sudo` access for Podman is available to the user running `ramalama`, potentially without a password prompt for seamless operation.

The proxy image (`rhel-lightspeed-proxy:latest`) must be built prior to first use. For detailed instructions on building the proxy image and understanding its certificate requirements, see the "CONNECTING TO RHEL LIGHTSPEED VIA PROXY" section in **[ramalama-client(1)](ramalama-client.1.md)**.

The `ramalama lightspeed` command internally calls `ramalama-client-core` with the appropriate proxy address (defaulting to `http://localhost:8888`) and default parameters for the query.

## PREREQUISITES FOR AUTOMATIC PROXY MANAGEMENT

1.  **`sudo podman` Access:** The user running `ramalama lightspeed` must have `sudo` privileges to execute `podman` commands for starting and checking the proxy container. Passwordless `sudo` for `podman` may be required for a non-interactive experience.
2.  **Proxy Image Built:** The `rhel-lightspeed-proxy:latest` image must be built beforehand. Refer to **[ramalama-client(1)](ramalama-client.1.md)** for build instructions.
3.  **Subscribed RHEL Host (for proxy functionality):** For the proxy to successfully authenticate with RHEL Lightspeed, it must run on a RHEL host with valid RHSM subscriptions and properly configured certificate access for containers.

## OPTIONS

#### **--proxy-port**=*port*
Specify the local host port that `ramalama lightspeed` should connect to. If `ramalama lightspeed` starts the proxy container, this port will also be the host port mapped to the proxy container's internal listening port (8888).
(Default: 8888)

#### **--help**, **-h**
Show this help message and exit.

## ARGUMENTS

#### _query_...
The prompt or query to send to RHEL Lightspeed. If the query contains spaces, it should be enclosed in quotes. If providing specific options for `ramalama-client-core` directly (e.g., custom temperature or context size), these can also be included here; in such cases, default options are not automatically added by the `lightspeed` command.

## EXAMPLES

### Send a query to RHEL Lightspeed (proxy started automatically if needed)
```
$ ramalama lightspeed "How do I install a package group in RHEL?"
```
(This uses the default proxy port 8888.)

### Send a query using a custom host port for the proxy
```
$ ramalama lightspeed --proxy-port 8889 "What is the command to check disk usage?"
```
(If the proxy container needs to be started, it will be mapped to host port 8889.)

### Send a query with specific arguments for `ramalama-client-core`
(This example assumes `ramalama-client-core` has such options. The `-c` and `--temp` are illustrative.)
```
$ ramalama lightspeed -- -c 1024 --temp 0.5 "Explain SELinux contexts"
```
Note: When providing arguments for `ramalama-client-core` directly, ensure they are correctly formatted. The `lightspeed` command will place the proxy host address before these arguments if it detects custom options.

## MANAGING THE PROXY CONTAINER

The `ramalama lightspeed` command attempts to start the proxy container if it's not running, using the name `ramalama-rhel-lightspeed-proxy-active`.

*   **Automatic Start:** The container is started with `sudo podman run -d --rm --name ramalama-rhel-lightspeed-proxy-active ...`. The `--rm` flag ensures the container is removed when it is stopped.
*   **No Automatic Stop:** `ramalama lightspeed` does **not** automatically stop the proxy container after the command finishes. This allows the proxy to be reused for subsequent commands without the delay of restarting it.
*   **Manual Management:** You can manage the proxy container directly using `podman` commands:
    *   To stop the proxy:
        ```bash
        $ sudo podman stop ramalama-rhel-lightspeed-proxy-active
        ```
    *   To view its logs:
        ```bash
        $ sudo podman logs ramalama-rhel-lightspeed-proxy-active
        ```
    *   To check if it's running:
        ```bash
        $ sudo podman ps -a --filter name=ramalama-rhel-lightspeed-proxy-active
        ```
*   **Building the Image:** Remember, the image `rhel-lightspeed-proxy:latest` must be built manually before first use. See **[ramalama-client(1)](ramalama-client.1.md)**.

## SEE ALSO
**[ramalama(1)](ramalama.1.md)**, **[ramalama-client(1)](ramalama-client.1.md)**
