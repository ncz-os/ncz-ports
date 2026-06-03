#!/bin/sh
# update-zeroclaw.sh — bump misc/zeroclaw to the newest applicable zeroclaw
# release, lint it, and push (clean) or open a review branch (lint fails).
#
# Version policy (operator decision 2026-06-03):
#   Track the latest tag INCLUDING pre-releases (the beta line) until a STABLE
#   release whose version is >= the current pin exists; once stable catches up,
#   prefer stable and stop following betas.
#
# Run on a FreeBSD host with the ports framework, gh (authed), portlint, git.
set -eu

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
PORTDIR="$REPO_ROOT/misc/zeroclaw"
UPSTREAM="zeroclaw-labs/zeroclaw"
: "${DISTDIR:=$HOME/distfiles}"
: "${WRKDIRPREFIX:=$HOME/portwork}"
export DISTDIR WRKDIRPREFIX

mk() { make -C "$PORTDIR" DISTDIR="$DISTDIR" WRKDIRPREFIX="$WRKDIRPREFIX" "$@"; }

cur=$(mk -V DISTVERSION)
stable=$(gh release view -R "$UPSTREAM" --json tagName -q .tagName | sed 's/^v//')
latest=$(gh release list -R "$UPSTREAM" --limit 1 --json tagName -q '.[0].tagName' | sed 's/^v//')

# pick target: stable once it has caught up to the pin, else the latest (beta) tag
if [ "$stable" = "$cur" ] || [ "$(pkg version -t "$stable" "$cur")" = ">" ]; then
	target=$stable
else
	target=$latest
fi

if [ "$target" = "$cur" ]; then
	echo "misc/zeroclaw: up to date ($cur)"
	exit 0
fi
echo "misc/zeroclaw: $cur -> $target"

# repin DISTVERSION and drop the stale CARGO_CRATES block
sed -i '' "s/^DISTVERSION=.*/DISTVERSION=	$target/" "$PORTDIR/Makefile"
perl -0777 -i -pe 's/\nCARGO_CRATES=.*?(?=\n(post-extract:|\.include))/\n/s' "$PORTDIR/Makefile"

# regenerate distinfo + crate list for the new version
mk clean
mk makesum                       # main distfile
mk cargo-crates > "/tmp/cc.$$" 2>/dev/null
# Insert CARGO_CRATES, dropping any @git+ entry (the whatsapp-rust git workspace
# is cut by files/strip-whatsapp.awk via post-extract — FreeBSD cargo.mk cannot
# vendor a git workspace with subdir member crates).
python3 - "$PORTDIR/Makefile" "/tmp/cc.$$" <<'PY'
import sys
mk, cc = sys.argv[1], sys.argv[2]
raw = open(cc, encoding="utf-8").read()
block = raw[raw.find("CARGO_CRATES="):].rstrip("\n").split("\n")
block = [ln for ln in block if "@git+" not in ln]           # drop git crate line(s)
if block:
    block[-1] = block[-1].rstrip()                          # last entry: no trailing backslash
    if block[-1].endswith("\\"):
        block[-1] = block[-1][:-1].rstrip()
text = "\n".join(block) + "\n"
s = open(mk, encoding="utf-8").read()
anchor = "post-extract:" if "post-extract:" in s else ".include <bsd.port.mk>"
j = s.index(anchor)
open(mk, "w", encoding="utf-8").write(s[:j] + text + "\n" + s[j:])
PY
rm -f "/tmp/cc.$$"
mk makesum                       # all crate distfiles + checksums
mk clean

git -C "$REPO_ROOT" add misc/zeroclaw/Makefile misc/zeroclaw/distinfo

if portlint -AC "$PORTDIR"; then
	git -C "$REPO_ROOT" commit -m "misc/zeroclaw: update to $target"
	# fleet three-remote push order: ARGONAS first, then GitLab (CI), then GitHub
	for r in argonas origin github; do
		git -C "$REPO_ROOT" push "$r" HEAD 2>/dev/null && echo "pushed -> $r" || echo "push skip: $r"
	done
	echo "misc/zeroclaw updated to $target"
else
	echo "portlint FAILED for $target — not auto-pushing; opening review branch"
	br="auto/zeroclaw-$target"
	git -C "$REPO_ROOT" checkout -b "$br"
	git -C "$REPO_ROOT" commit -m "WIP misc/zeroclaw $target (portlint failed — needs review)"
	git -C "$REPO_ROOT" push origin "$br" 2>/dev/null || true
	echo "review branch pushed: $br"
	exit 1
fi
