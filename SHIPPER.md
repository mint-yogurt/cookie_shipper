# Shipper spec (Windows 10, Brave)

Ships `.youtube.com` / `.google.com` cookies from this workstation to the receiver, on a timer,
while this user is logged in. See [RECEIVER.md](RECEIVER.md) for the contract this meets.

## Why not `yt-dlp --cookies-from-browser`

Brave is Chromium, so it has the same app-bound cookie encryption as Chrome/Edge. Reading its
cookie SQLite database directly (what `--cookies-from-browser` does) fails with a DPAPI error,
closed or open, and the file is also locked while Brave is running. Firefox would work, but
cookies only exist for the browser you're actually logged into YouTube with.

## How it works

1. **`extension/`** -- an unpacked Brave extension. Its background service worker reads cookies
   through `chrome.cookies` (the browser's own decrypted cookie jar, not the on-disk DB -- app-bound
   encryption doesn't apply here), and every 10 minutes writes a raw Netscape-format export to
   `%USERPROFILE%\Downloads\cookie_shipper\youtube_cookies_raw.txt`.
2. **`ship.ps1`** -- run by Task Scheduler every 30 minutes. It re-filters that raw export to only
   `.youtube.com`/`.google.com` cookies, validates it (header line, 7 tab-separated fields per
   cookie, at least one `.youtube.com` cookie), writes `youtube_cookies.txt`, and sends it with the
   exact `ssh ... < file` command from RECEIVER.md. A validation failure or a down server just skips
   that run -- nothing is sent, and the next run tries again.

## One-time setup

1. **Install the extension.** In Brave, go to `brave://extensions`, enable "Developer mode", click
   "Load unpacked", and select the `extension/` folder in this repo.
2. **Disable the save-location prompt.** In `brave://settings/downloads`, turn off "Ask where to
   save each file before downloading". Without this, every periodic export pops a Save As dialog.
3. **Generate the SSH key** (see "Unattended sends need a key" in RECEIVER.md) -- the shipper's
   Claude Code session runs the `ssh-keygen` step; you run the `authorized_keys` step yourself,
   since it needs your server password.
4. **Create `secrets.env`** in this folder (gitignored, never commit it):
   ```
   SSH_USER=<user>
   SSH_HOST=<server-ip>
   ```
5. **Register the Task Scheduler job**: `.\install_task.ps1` (run once, by hand).

## Logs

`ship.log` in this folder records each run (sent / aborted / why). It's gitignored.
