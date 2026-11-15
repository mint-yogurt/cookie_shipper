# Receiver spec

The receiver puts the shipped cookie file at `~/cookie_shipper/youtube_cookies.txt` on the server
where yt-dlp reads it.

**The receiver has no code, no service and no setup.** The shipper logs in over SSH as
`<user>@<server-ip>` over Tailscale, with its own key. sshd is already running.

## How it works

The workstation (Windows 10) sends the file with the OpenSSH client built into Windows, in a single
command run from cmd:

```
ssh -i <key> <user>@<server-ip> "cat > ~/cookie_shipper/.incoming_cookies.txt && mv ~/cookie_shipper/.incoming_cookies.txt ~/cookie_shipper/youtube_cookies.txt" < youtube_cookies.txt
```

- The file is written under a temp name first, then `mv` puts it in place. A running yt-dlp never
  reads a half-written file. If the transfer drops partway, `mv` never runs and the old file stays.
- Both names match the `*cookies*.txt` gitignore rule.
- The server only uses compute while a transfer is running.
- From PowerShell 5.1, wrap the command in `cmd /c "..."`. That shell has no `<` redirect, and
  piping text with `|` there can change the encoding and line endings.

## Contract with the shipper

| Field | Value |
|---|---|
| Target | `<user>@<server-ip>`, from the gitignored secrets file |
| Format | Netscape cookie file (what yt-dlp `--cookies` reads). The first line is `# Netscape HTTP Cookie File`, and each line after it has 7 tab-separated fields. Write LF line endings. |
| Contents | Only `.youtube.com` and `.google.com` cookies. Don't send the whole browser cookie jar. |
| Validation | **The shipper's job.** The server stores whatever arrives, so the shipper checks the file before sending. |
| When | Only while the workstation is on, so the server never tries to fetch. Shipping on a timer while logged in (Task Scheduler, every 30–60 min) keeps the cookies fresh. A failed send, e.g. when the server is down, is skipped until the next run. |

## Unattended sends need a key

A Task Scheduler job can't type a password, so the shipper gets its own SSH key, used only for this.
This is done once, in PowerShell on the workstation. The server needs nothing else.

```
ssh-keygen -t ed25519 -f $env:USERPROFILE\.ssh\cookie_shipper -N '""'
type $env:USERPROFILE\.ssh\cookie_shipper.pub | ssh <user>@<server-ip> "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
ssh -i $env:USERPROFILE\.ssh\cookie_shipper <user>@<server-ip> echo ok
```

- The first command makes the key with no passphrase.
- The second command asks for the password one last time. A person has to type it, so run it by
  hand, not from Claude.
- The third command should print `ok` without a password prompt.

Every send then uses `ssh -i $env:USERPROFILE\.ssh\cookie_shipper ...`.

## Notes for the shipper (Windows 10)

- Getting cookies out of Chrome on Windows is hard. Newer Chrome encrypts cookies with app-bound
  encryption, and it locks the cookie database while the browser is open. Because of that,
  `yt-dlp --cookies-from-browser chrome` usually fails on Windows now. Firefox works, even while
  it's running. A browser extension that exports cookies.txt works too.
- YouTube rotates session cookies while you keep using the browser. Each export is fresh, but older
  exports go stale. Shipping on a timer covers that.

## Notes for the consumer (`~/chuptv_director`)

- `chuptv ingest download --cookies ~/cookie_shipper/youtube_cookies.txt`
- yt-dlp **writes the cookie file back** when it exits. Suppose a download is running while a new
  file arrives: when the download exits, yt-dlp writes back the cookies it loaded at the start, over
  the fresh file. To avoid that, chuptv should copy the file to a temp path for each run and pass
  the copy.
