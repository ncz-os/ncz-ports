# ⚠️ This is a mirror — the canonical repo lives on GitLab

### 👉 https://gitlab.com/ncz-os/ncz-ports

**Source, releases, issues, merge requests, and CI all live on GitLab.** This GitHub copy is a read-only mirror and may lag. Please file issues and get releases there.

---

> # 📍 Moved to GitLab
> **The canonical, authoritative home of this project is GitLab — always:**
> ## 👉 https://gitlab.com/ncz-os/ncz-ports
>
> This GitHub repository is a **frozen, read-only mirror**. All development, issues, and releases happen on GitLab. Please open issues and merge requests there. The full history of this stub is preserved on GitLab.

---

# zeroclaw — FreeBSD port

A FreeBSD `USES=cargo` port for [ZeroClaw](https://github.com/zeroclaw-labs/zeroclaw),
a fast, small Rust AI assistant / agent CLI. This repo is a ports **overlay**
carrying `misc/zeroclaw`, plus a small script that keeps the pin current with
upstream releases.

## Layout

```
misc/zeroclaw/             the port (Makefile, distinfo, pkg-descr)
tools/update-zeroclaw.sh   optional auto-bumper (run on a FreeBSD host)
```

## Building

```sh
# drop into a ports tree:
cp -R misc/zeroclaw /usr/ports/misc/zeroclaw
cd /usr/ports/misc/zeroclaw && make install clean

# or use it as a poudriere overlay (-M /path/to/this/checkout)
```

Installs `bin/zeroclaw` (daemon/CLI) and `bin/zeroclaw-acp-bridge`.

**Build requirements** (declared as BUILD_DEPENDS): `lang/rust` >= 1.95,
`devel/cmake-core`, `devel/pkgconf`. On FreeBSD 15.0 the quarterly pkg branch
may still carry rust 1.94 — install 1.95+ from the `latest` branch if so.

## Features / WhatsApp

The port builds the default feature set plus `channel-whatsapp-cloud` and
`whatsapp-web`. `whatsapp-web` pulls a **git workspace**
(`oxidezap/whatsapp-rust`, with member crates in subdirectories). FreeBSD's
`cargo.mk` vendors this correctly through the `@git+` entry in `CARGO_CRATES`:
`cargo-crates-git-configure.awk` locates each member crate's subdir by package
name, so no hand-written `[patch]` is required.

## Versioning

ZeroClaw's current active line is a pre-release (`v0.8.0-beta-*`); the WhatsApp
Web support lives there, not in the last stable (`v0.7.5`). The port pins the
**latest tag including pre-releases** until a **stable** release whose version
is `>=` the current pin exists, then prefers stable. `0.8.0` final is a clean
upgrade from the beta pin (`0.8.0.b.2 < 0.8.0` in pkg ordering; no `PORTEPOCH`).

## Auto-update (optional)

`tools/update-zeroclaw.sh` polls upstream, applies the versioning policy above,
and on a new applicable release bumps `DISTVERSION`, regenerates `distinfo` +
`CARGO_CRATES` (keeping the `@git+` entry), then runs `portfmt -i` +
`portlint -AC`. If clean it commits and pushes; otherwise it pushes a review
branch instead of auto-merging. Because the bump needs the ports framework +
the `cargo` toolchain, run it on a FreeBSD host (e.g. via `cron`), not a Linux
CI runner:

```
17 4 * * *  cd /path/to/this/checkout && sh tools/update-zeroclaw.sh >> /var/log/zeroclaw-portbump.log 2>&1
```

## License

The port follows ZeroClaw's dual MIT / Apache-2.0 license.