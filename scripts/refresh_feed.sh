#!/usr/bin/env bash
# Weekly refresh of the live AHDB feed ingredient prices.
#
# Usage: scripts/refresh_feed.sh ~/Downloads/<exported file>.xlsx
#
# AHDB publishes on Mondays (Friday spot prices). Export the file from
# https://ahdb.org.uk/cereals-oilseeds/feed-ingredient-prices, then run this.
# It checks the file loads exactly as the API will load it, shows what will
# change, and only then commits and pushes. Render deploys on push.

set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
LIVE="$REPO/backend/data/live/UK_feed_ingredient_prices.xlsx"
NEW="${1:-}"

if [[ -z "$NEW" || ! -f "$NEW" ]]; then
  echo "Usage: $0 path/to/UK_feed_ingredient_prices.xlsx" >&2
  exit 1
fi

PY="$REPO/backend/.venv/bin/python"
[[ -x "$PY" ]] || PY="python3"

# Validate with the same loader and calculation the API uses. Exits non-zero
# if the file doesn't parse or isn't newer than the one already live.
"$PY" - "$LIVE" "$NEW" <<'EOF'
import sys
sys.path.insert(0, sys.argv[1].rsplit("/data/", 1)[0])
from engines.feed_cost_pressure import load_feed_series, current_feed_pressure

live_path, new_path = sys.argv[1], sys.argv[2]
# Load explicitly: current_feed_pressure(None) falls back to the live file,
# which would make a broken export look valid.
new_series = load_feed_series(new_path)
new = current_feed_pressure(new_series, "pork") if new_series is not None else None
if new is None:
    sys.exit("✗ New file did not load. The export format may have changed; "
             "nothing was replaced.")
old = current_feed_pressure(load_feed_series(live_path), "pork")

def line(r):
    return (f"as of {r['as_of']}  £{r['price_now']:.0f}/t  "
            f"{r['pct_change_13w']:+.1f}% over 13 wks  pressure {r['pressure']}")

print(f"  current: {line(old) if old else '(none)'}")
print(f"  new:     {line(new)}")
if old and new["as_of"] <= old["as_of"]:
    sys.exit("✗ New file is not newer than the live one; nothing was replaced.")
if new["stale"]:
    print(f"  ! Still {new['days_old']} days old. AHDB may not have published "
          "this week yet.")
EOF

AS_OF="$("$PY" - "$NEW" "$LIVE" <<'EOF'
import sys
sys.path.insert(0, sys.argv[2].rsplit("/data/", 1)[0])
from engines.feed_cost_pressure import load_feed_series
print(load_feed_series(sys.argv[1]).index[-1].date().isoformat())
EOF
)"

read -r -p "Replace the live file and push to deploy? [y/N] " ok
[[ "$ok" == [yY] ]] || { echo "Cancelled; nothing changed."; exit 0; }

cp "$NEW" "$LIVE"
cd "$REPO"
git add "$LIVE"
git commit -q -m "Refresh UK feed ingredient prices (AHDB, through $AS_OF)"
git push -q origin HEAD
echo "✓ Pushed. Render will redeploy in a few minutes; then check"
echo "  https://agriesg-api.onrender.com/feed-cost-pressure shows as_of near $AS_OF."
