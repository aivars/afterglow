#!/usr/bin/env python3
"""Fetch 5-star App Store reviews from Apple's public customer-reviews RSS feed.

Usage: python3 -I fetch_reviews.py <appId> <cc> [<cc> ...]

Prints one JSON object per line on stdout, newest app version first:
  {"storefront","version","author","title","content","length"}
Prints one summary line per storefront on stderr. Empty or invalid feeds are
normal (the feed is flaky); they are reported and skipped, never fatal.
Standard library only.
"""
import json
import re
import sys
import urllib.error
import urllib.request

URL = "https://itunes.apple.com/{cc}/rss/customerreviews/id={app}/sortBy=mostRecent/json"
TIMEOUT = 10


def fetch(app_id, cc):
    """Return (entries, note). entries is a list of raw feed entries."""
    req = urllib.request.Request(
        URL.format(cc=cc, app=app_id), headers={"User-Agent": "afterglow-integrate/1.0"}
    )
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
            raw = resp.read()
    except (urllib.error.URLError, TimeoutError, OSError) as exc:
        return [], f"request failed ({exc})"
    if not raw.strip():
        return [], "empty response"
    try:
        data = json.loads(raw)
    except ValueError:
        return [], "invalid JSON"
    entries = data.get("feed", {}).get("entry") if isinstance(data, dict) else None
    if entries is None:
        return [], "no entries"
    if isinstance(entries, dict):  # a single entry is returned as an object
        entries = [entries]
    return entries, ""


def label(entry, key):
    value = entry.get(key)
    if isinstance(value, dict):
        value = value.get("label")
    return value if isinstance(value, str) else ""


def version_key(version):
    parts = [int(p) for p in re.findall(r"\d+", version)]
    return parts or [-1]


def main(argv):
    if len(argv) < 3:
        print(__doc__.strip().splitlines()[2], file=sys.stderr)
        return 2
    app_id = re.sub(r"^id", "", argv[1])
    if not app_id.isdigit():
        print(f"error: appId must be numeric, got {argv[1]!r}", file=sys.stderr)
        return 2

    seen, results = set(), []
    for cc in (c.lower() for c in argv[2:]):
        entries, note = fetch(app_id, cc)
        found = kept = 0
        for entry in entries:
            if not isinstance(entry, dict) or "im:rating" not in entry:
                continue  # the first entry is often the app itself
            found += 1
            review_id = label(entry, "id")
            if review_id in seen:
                continue
            seen.add(review_id)
            if label(entry, "im:rating") != "5":
                continue
            content = label(entry, "content").strip()
            results.append({
                "storefront": cc,
                "version": label(entry, "im:version"),
                "author": label(entry.get("author", {}), "name") if isinstance(entry.get("author"), dict) else "",
                "title": label(entry, "title").strip(),
                "content": content,
                "length": len(content),
            })
            kept += 1
        suffix = f" ({note})" if note else ""
        print(f"{cc}: {found} reviews found, {kept} five-star kept{suffix}", file=sys.stderr)

    results.sort(key=lambda r: version_key(r["version"]), reverse=True)
    for item in results:
        print(json.dumps(item, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
