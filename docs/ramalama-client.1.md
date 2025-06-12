% ramalama-client 1

## NAME
ramalama\-client - interact with the AI Model server (experimental)

## SYNOPSIS
**ramalama client** [*options*] _host_

## OPTIONS

#### **--help**, **-h**
show this help message and exit

## DESCRIPTION
Interact with a AI Model server. The client can send queries to the AI Model server and retrieve responses.

## EXAMPLES

### Connect to the AI Model server.
```
$ ramalama client http://127.0.0.1:8080
```

## CONNECTING TO RHEL LIGHTSPEED VIA PROXY

**Note:** While the steps below detail setting up the proxy and using `ramalama client` to connect through it, the recommended way to interact with RHEL Lightspeed is now via the dedicated **[ramalama-lightspeed(1)](ramalama-lightspeed.1.md)** command. This command simplifies the invocation by managing the proxy URL and port internally. The information below is still relevant for understanding the proxy setup required by both methods.

### Prerequisites

1.  **Subscribed RHEL Host:** You must be running Podman on a RHEL host that is properly registered and subscribed, so that RHSM certificates are available.
2.  **Podman:** Podman is required to build and run the proxy container. `sudo` may be needed for Podman commands depending on your setup.
3.  **Certificates Availability:** The proxy container expects the client certificates (`/etc/pki/consumer/cert.pem` and `/etc/pki/consumer/key.pem`) to be made available inside the container. On a correctly configured subscribed RHEL host, Podman typically handles mounting these from the host (e.g., from `/usr/share/rhel/secrets` on the host to `/run/secrets` in the container, with the UBI base image often linking these to standard locations like `/etc/pki/consumer/`).

### 1. Build the Proxy Container Image

The proxy container definition is located in the `ramalama/proxy/rhel-lightspeed/` directory within the Ramalama project.

First, navigate to this directory from the root of the Ramalama project:
```bash
$ cd ramalama/proxy/rhel-lightspeed/
```

Then, build the image using Podman:
```bash
$ sudo podman build -f Containerfile.rhel-lightspeed-proxy -t rhel-lightspeed-proxy:latest .
```
Note: Depending on your system's SELinux and seccomp configuration, you might need to add options like `--security-opt seccomp=unconfined` to the `podman build` and `podman run` commands if you encounter permission-related issues.

### 2. Run the Proxy Container

Run the proxy container, mapping a host port to the container's proxy port (the default listen port inside the container is 8888).

```bash
$ sudo podman run -d --rm --name lightspeed-proxy-instance \
    -p 8888:8888 \
    rhel-lightspeed-proxy:latest
```
*   `-d`: Run in detached mode.
*   `--rm`: Automatically remove the container when it stops.
*   `--name lightspeed-proxy-instance`: Assign a memorable name to the container.
*   `-p 8888:8888`: Map port 8888 on your host to port 8888 in the container. If port 8888 is already in use on your host, choose a different host port (e.g., `-p <your_host_port>:8888`).

The proxy container is configured to connect to `cert.console.redhat.com:443` by default and listens on port `8888` internally. These defaults can be overridden using environment variables (`LIGHTSPEED_ENDPOINT_HOST`, `LIGHTSPEED_ENDPOINT_PORT`, `PROXY_LISTEN_PORT`) during the `podman run` command if customization is needed.

### 3. Use `ramalama lightspeed` (Recommended) or `ramalama client` with the Proxy

Once the proxy container is running, the recommended way to send queries to RHEL Lightspeed is:
```bash
$ ramalama lightspeed "Your query for RHEL Lightspeed"
```
This command defaults to using proxy port 8888, which corresponds to the default listening port of the proxy container when mapped to your host. If you mapped a different host port to the container's 8888 port, or if the proxy container itself is configured to listen on a different port (via the `PROXY_LISTEN_PORT` environment variable), use the `--proxy-port` option:
```bash
$ ramalama lightspeed --proxy-port <your_host_port_or_container_config_port> "How do I check for listening ports on RHEL?"
```
Refer to **[ramalama-lightspeed(1)](ramalama-lightspeed.1.md)** for more details on this command.

Alternatively, you can still use `ramalama client` by manually specifying the full proxy URL:
```bash
$ ramalama client http://localhost:<your_host_port> "Your query for RHEL Lightspeed"
```
For example, if you mapped host port 8888 to the container's default port 8888:
```bash
$ ramalama client http://localhost:8888 "How do I check for listening ports on RHEL?"
```

### Troubleshooting

*   **Check Proxy Container Logs:** If you encounter issues, the first step is to check the logs of the proxy container:
    ```bash
    $ sudo podman logs lightspeed-proxy-instance
    ```
    Look for any error messages from Nginx. If Nginx reports it "cannot load certificate /etc/pki/consumer/cert.pem", it indicates that the necessary RHSM client certificates were not properly made available from the RHEL host to the container. Ensure your host is correctly subscribed and that Podman's secret mounting mechanism is functional.

*   **Port Conflicts:** If the `podman run` command fails due to port conflicts, ensure the host port you've chosen (e.g., 8888) is not already in use by another application. Choose a different host port if necessary.

## SEE ALSO
**[ramalama(1)](ramalama.1.md)**, **[ramalama-serve(1)](ramalama-serve.1.md)**

## HISTORY
Apr 2025, Originally compiled by Eric Curtin <ecurtin@redhat.com>
