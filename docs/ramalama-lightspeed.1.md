% ramalama-lightspeed 1

## NAME
ramalama-lightspeed - interact with RHEL Lightspeed API via a proxy

## SYNOPSIS
**ramalama lightspeed** [*options*] [_query_...]

## DESCRIPTION
The **ramalama lightspeed** command provides a convenient way to interact with the Red Hat Enterprise Linux (RHEL) Lightspeed API. It achieves this by automatically routing requests through a locally running RHEL Lightspeed Proxy container, which handles the necessary client certificate authentication.

Before using this command, ensure the RHEL Lightspeed Proxy container is built and running. For detailed instructions on setting up the proxy container, see the "CONNECTING TO RHEL LIGHTSPEED VIA PROXY" section in **[ramalama-client(1)](ramalama-client.1.md)**.

The command internally calls `ramalama-client-core` with the appropriate proxy address (defaulting to `http://localhost:8888`) and default parameters.

## OPTIONS

#### **--proxy-port**=*port*
Specify the local port where the RHEL Lightspeed Proxy container is listening.
(Default: 8888)

#### **--help**, **-h**
Show this help message and exit.

## ARGUMENTS

#### _query_...
The prompt or query to send to RHEL Lightspeed. If the query contains spaces, it should be enclosed in quotes. If providing specific options for `ramalama-client-core` directly, these can also be included here; in such cases, default options like context size and temperature are not automatically added by the `lightspeed` command.

## EXAMPLES

### Send a query to RHEL Lightspeed using the default proxy port (8888)
```
$ ramalama lightspeed "How do I install a package group in RHEL?"
```

### Send a query using a custom proxy port mapped on the host
```
$ ramalama lightspeed --proxy-port 8889 "What is the command to check disk usage?"
```

### Send a query with specific arguments for `ramalama-client-core`
(This example assumes `ramalama-client-core` has such options; replace with actual valid options if different. The `-c` and `--temp` are illustrative.)
```
$ ramalama lightspeed -- -c 1024 --temp 0.5 "Explain SELinux contexts"
```
Note: When providing arguments for `ramalama-client-core` directly in the query string, ensure they are correctly formatted and understood by `ramalama-client-core`. The `lightspeed` command will place the proxy host address before these arguments if it detects custom options.

## SEE ALSO
**[ramalama(1)](ramalama.1.md)**, **[ramalama-client(1)](ramalama-client.1.md)**
