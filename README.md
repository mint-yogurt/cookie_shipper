# cookie_shipper

Keeps a yt-dlp server supplied with fresh YouTube cookies from a Windows workstation's browser.
The cookies go over SSH on a private Tailscale network.

- **Shipper** (workstation): a Brave extension exports the YouTube/Google cookies, and a
  scheduled PowerShell script validates them and sends them every 30 minutes, only while you're
  logged in. See [SHIPPER.md](SHIPPER.md).
- **Receiver** (server): no code. The file lands at `~/cookie_shipper/youtube_cookies.txt`, and
  yt-dlp reads it with `--cookies`. See [RECEIVER.md](RECEIVER.md) for the contract.

If the workstation is off, nothing ships and nothing retries. The server just keeps the last
file it got.

## Secrets

The server address, SSH login and cookies are kept only in gitignored files (`secrets.*`,
`.env`/`*.env`, `*cookies*.txt`) and never in this repo.

## Design notes

- **Brave, Chrome and Edge can't use `yt-dlp --cookies-from-browser` on Windows**, because
  app-bound encryption blocks it. That's why the shipper uses a small extension that reads
  cookies through the `chrome.cookies` API.
- **The cookies come from your own Google account.** There's no throwaway account. To protect
  it, the downloader should space out downloads with random pauses and a daily cap.
- **The downloader should pass yt-dlp a temp copy of the cookie file**, because yt-dlp writes
  cookies back on exit (see RECEIVER.md).
