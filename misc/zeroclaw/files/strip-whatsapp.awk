# Strip the optional whatsapp-rust git-workspace dependency from
# zeroclaw-channels so the port builds offline against crates.io-only vendored
# sources. The `whatsapp-web` channel is not part of the default feature set;
# FreeBSD's cargo.mk cannot vendor a git workspace whose member crates live in
# subdirectories, so we drop the dependency rather than ship a fragile,
# per-release git-patch. Pattern-based (not line-numbered) so it survives
# version bumps. After this runs, `cargo update` removes the now-unreferenced
# git packages from Cargo.lock.
BEGIN { skip = 0 }

# inside a multi-line git dependency block: drop lines until the closing brace
skip { if ($0 ~ /\}/) skip = 0; next }

# a dependency whose source is the oxidezap/whatsapp-rust git repo
/oxidezap\/whatsapp-rust/ {
	if ($0 !~ /\}/) skip = 1   # block spans multiple lines (features = [ ... ])
	next
}

# feature-array elements that enable those optional git crates
/"dep:(whatsapp-rust|wacore|waproto)/ { next }

{ print }
