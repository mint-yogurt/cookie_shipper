# cookie_shipper

Ships browser cookies from the user's Windows workstation to `~/cookie_shipper` on the ChupTV
server, over Tailscale. yt-dlp on the server then uses them for YouTube downloads (the
viewing-list ingest in `~/chuptv_director`: `chuptv ingest download --cookies <file>`).

The Tailscale IP, SSH login, and the cookies themselves only ever live in gitignored files
(`secrets.*`, `.env`/`*.env`, `*cookies*.txt`) -- never in this repo or its history.

## Status

Both sides are built and running:

- **Receiver** (server side): no code, see [RECEIVER.md](RECEIVER.md) for the contract.
- **Shipper** (workstation side): a Brave extension + a scheduled PowerShell script, see
  [SHIPPER.md](SHIPPER.md).

## Decisions (2026-11-15)

- **No throwaway Google account.** It's too much trouble. The cookies come from the user's own
  browser session.
- **Downloads are staggered** to protect that account. YouTube gets no burst of hundreds of
  downloads: the downloader spaces them out with random pauses and a daily cap. That work lives in
  `~/chuptv_director`, not here.
- **Build order:**
  1. The **receiver**, on the server, in this repo (a separate Claude Code session).
  2. The **shipper**, on the workstation (Claude Code there).
- **The cookie file** lands in `~/cookie_shipper/` on the server. It is gitignored (`*cookies*.txt`),
  like the secrets file.
- **Brave can't use `yt-dlp --cookies-from-browser`** (app-bound encryption blocks it, same as
  Chrome/Edge), so the shipper reads cookies through a small browser extension instead. See
  SHIPPER.md for why.
