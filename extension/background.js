// Exports .youtube.com / .google.com cookies as a Netscape cookie file, on a
// timer, via chrome.cookies (reads the browser's own decrypted cookie jar --
// no DPAPI / app-bound-encryption issue, unlike reading the SQLite DB directly).

const ALARM_NAME = "cookie_export";
const PERIOD_MINUTES = 10;
const EXPORT_PATH = "cookie_shipper/youtube_cookies_raw.txt"; // relative to Downloads

function toNetscapeLine(cookie) {
  const includeSubdomains = cookie.hostOnly ? "FALSE" : "TRUE";
  const secure = cookie.secure ? "TRUE" : "FALSE";
  const expiry = cookie.session ? "0" : String(Math.round(cookie.expirationDate));
  return [cookie.domain, includeSubdomains, cookie.path, secure, expiry, cookie.name, cookie.value].join("\t");
}

async function exportCookies() {
  const domains = ["youtube.com", "google.com"];
  const seen = new Set();
  const lines = ["# Netscape HTTP Cookie File"];

  for (const domain of domains) {
    const cookies = await chrome.cookies.getAll({ domain });
    for (const cookie of cookies) {
      const bareDomain = cookie.domain.replace(/^\./, "").toLowerCase();
      if (bareDomain !== "youtube.com" && !bareDomain.endsWith(".youtube.com") &&
          bareDomain !== "google.com" && !bareDomain.endsWith(".google.com")) {
        continue;
      }
      const key = `${cookie.domain}|${cookie.name}|${cookie.path}`;
      if (seen.has(key)) continue;
      seen.add(key);
      lines.push(toNetscapeLine(cookie));
    }
  }

  const content = lines.join("\n") + "\n";
  const dataUrl = "data:text/plain;charset=utf-8;base64," + btoa(unescape(encodeURIComponent(content)));

  chrome.downloads.download(
    { url: dataUrl, filename: EXPORT_PATH, conflictAction: "overwrite", saveAs: false },
    (downloadId) => {
      if (chrome.runtime.lastError || downloadId === undefined) {
        console.error("cookie export download failed", chrome.runtime.lastError);
        return;
      }
      // Clean up the download-history entry (not the file) so this doesn't
      // pile up in the downloads list every 10 minutes.
      const listener = (delta) => {
        if (delta.id === downloadId && delta.state && delta.state.current === "complete") {
          chrome.downloads.onChanged.removeListener(listener);
          chrome.downloads.erase({ id: downloadId });
        }
      };
      chrome.downloads.onChanged.addListener(listener);
    }
  );
}

function ensureAlarm() {
  chrome.alarms.create(ALARM_NAME, { periodInMinutes: PERIOD_MINUTES });
  exportCookies();
}

chrome.runtime.onInstalled.addListener(ensureAlarm);
chrome.runtime.onStartup.addListener(ensureAlarm);
chrome.alarms.onAlarm.addListener((alarm) => {
  if (alarm.name === ALARM_NAME) exportCookies();
});
