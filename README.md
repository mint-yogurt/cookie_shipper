# cookie_shipper

Intention: ship browser cookies from the user's workstation to `~/cookie_shipper` on the ChupTV
server (`mintyogurt`), over Tailscale. yt-dlp on the server then uses them for YouTube downloads
(the viewing-list ingest in `~/chuptv_director`).

The Tailscale IP and ports go in a secrets file that isn't committed to the GitHub repo.
