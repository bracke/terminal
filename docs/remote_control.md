# Remote control

Every running terminal instance owns an AF_UNIX control socket with mode `0600`.
The socket path is exported to child processes as `BRACKE_TERMINAL_CONTROL`, so
commands run inside the terminal can address their own window directly:

```sh
terminal_app_main --control list
terminal_app_main --control new-tab
terminal_app_main --control split vertical
terminal_app_main --control send 'printf hello'
terminal_app_main --control read-only on
terminal_app_main --control protected-input on
terminal_app_main --control get-text
```

External callers can select an instance explicitly with
`--control=/path/to/bracke-terminal-PID.sock`. Requests and responses use one
UTF-8 line. A response begins with `ok` or `error`; embedded newlines, tabs,
carriage returns, and backslashes returned by `get-text` are escaped.

Version-one commands are `ping`, `list`, `activate N`, `new-tab`, `close`,
`split horizontal`, `split vertical`, `send TEXT`, `set-title TEXT`,
`set-theme NAME`, `reload-config`, `get-text`, `read-only on|off`,
`protected-input on|off`, and `quit`.
Protected input rejects `send`, disables broadcast input, and answers terminal
OSC 52 clipboard queries with an empty value while discarding clipboard sets.
Window visibility is controlled with `show`, `hide`, and `toggle`; these are
also suitable for binding a desktop-global shortcut to a `--quick` instance.
