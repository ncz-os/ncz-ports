# ncz-ports — FreeBSD ports overlay (zeroclaw)

A minimal FreeBSD ports **overlay** carrying `misc/zeroclaw` for the fleet.
The port itself is a normal, fully-pinned, checksummed FreeBSD port; an
auto-updater keeps the pin current with upstream zeroclaw releases.

## Layout

```
misc/zeroclaw/         pinned port (Makefile, distinfo, pkg-descr)
tools/update-zeroclaw.sh   auto-bumper (run on a FreeBSD host)
```

## Consuming the overlay on a FreeBSD host

The port lives at `misc/zeroclaw`. Build it either by copying into the base
ports tree, or as an overlay:

```sh
# option A: drop-in
cp -R misc/zeroclaw /usr/ports/misc/zeroclaw
cd /usr/ports/misc/zeroclaw && make install clean

# option B: poudriere overlay (clean-room, recommended for fleet pkg builds)
poudriere ports -c -p ncz -m null -M /path/to/this/checkout
poudriere bulk -p ncz -j <jail> misc/zeroclaw
```

A built package installs `bin/zeroclaw` (the `zeroclaw` daemon/CLI).

## Version policy (operator decision, 2026-06-03)

The port tracks the **latest tag including pre-releases** (the active beta
line) until a **stable** release whose version is `>=` the current pin exists.
Once stable catches up, the updater prefers stable and stops following betas.

- current pin: `v0.8.0-beta-2` (matches the fleet's installed runtime)
- when `v0.8.0` final ships, the next update jumps to it (clean upgrade —
  `0.8.0.b.2 < 0.8.0` in pkg version ordering, no `PORTEPOCH` needed)

## Auto-update

`tools/update-zeroclaw.sh` polls upstream, applies the policy above, and on a
new applicable release: bumps `DISTVERSION`, regenerates `distinfo` +
`CARGO_CRATES`, runs `portlint -AC`. If it lints clean it commits and pushes
(ARGONAS → GitLab → GitHub); otherwise it pushes a review branch and does not
auto-merge. It is driven by a daily `cron` job on the fleet FreeBSD host
(the ports framework + `cargo` toolchain must run there, not on a Linux CI
runner).

```
# /etc/cron.d or crontab on the FreeBSD ports host, daily at 04:17
17 4 * * *  cd /path/to/ncz-ports && sh tools/update-zeroclaw.sh >> /var/log/zeroclaw-portbump.log 2>&1
```
