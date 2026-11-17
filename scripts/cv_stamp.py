# /// script
# requires-python = ">=3.11"
# dependencies = ["tzdata"]
# ///
"""Date stamp for the PDF CVs, the same way src/blog/timestamps.json dates posts.

    cv_stamp.py SOURCE STAMP           refresh STAMP from SOURCE
    cv_stamp.py SOURCE STAMP --epoch   also print the stamp as SOURCE_DATE_EPOCH

STAMP is a committed JSON file, {"date": "YYYY-MM-DD", "hash": "<sha256>"}.
When SOURCE's hash differs from the stored one, the date becomes today in
SITE_TZ; an unchanged source keeps its date, so rebuilding (even after `make
clean`) reproduces the PDFs byte for byte. Edit "date" by hand to correct it;
leave "hash" alone and the value sticks.

The epoch is noon UTC on that date. pdfTeX, given SOURCE_DATE_EPOCH and
FORCE_SOURCE_DATE=1, takes both the PDF's own dates and the header's \\today
from it, in UTC, so noon keeps \\today on the stamped day.
"""

import hashlib
import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from zoneinfo import ZoneInfo

SITE_TZ = ZoneInfo("America/Los_Angeles")


def main() -> None:
    source, stamp = Path(sys.argv[1]), Path(sys.argv[2])
    digest = hashlib.sha256(source.read_bytes()).hexdigest()
    try:
        data = json.loads(stamp.read_text())
    except FileNotFoundError:
        data = {}
    if data.get("hash") != digest:
        data = {"date": datetime.now(SITE_TZ).date().isoformat(), "hash": digest}
        stamp.parent.mkdir(parents=True, exist_ok=True)
        stamp.write_text(json.dumps(data, indent=2) + "\n")
        print(f"cv_stamp: {source} changed; PDF dated {data['date']}", file=sys.stderr)
    else:
        # Unchanged content, but mark the stamp up to date for Make.
        stamp.touch()
    if "--epoch" in sys.argv[3:]:
        day = datetime.fromisoformat(data["date"]).replace(hour=12, tzinfo=timezone.utc)
        print(int(day.timestamp()))


if __name__ == "__main__":
    main()
