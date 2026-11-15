# cookie_shipper

Intention: ship browser cookies from the user's workstation to `~/cookie_shipper` on the ChupTV
server (`mintyogurt`), over Tailscale. yt-dlp on the server then uses them for YouTube downloads
(the viewing-list ingest in `~/chuptv_director`: `chuptv ingest download --cookies <file>`).

The Tailscale IP and ports go in a secrets file that isn't committed to the GitHub repo.

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
