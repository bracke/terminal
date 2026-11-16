# Signed updates and package feeds

Release archives are reproducible, and update metadata is deliberately separate
from installation. `scripts/sign_release.sh ARCHIVE CHANNEL BASE_URL` writes a
bounded `bracke-update-v1` manifest for `stable`, `beta`, or `nightly`, records
the exact SHA-256 and byte length, and gives both the archive and manifest
detached minisign signatures. The signing key is read only from
`BRACKE_UPDATE_SECRET_KEY`.

Consumers verify both signatures and the manifest's digest/length with
`scripts/verify_update.sh MANIFEST ARCHIVE PUBLIC_KEY`. No unsigned fallback is
accepted.

`scripts/generate_package_feeds.sh` substitutes a release's immutable URL,
version, SHA-256, and size into Homebrew and WinGet manifests. Debian's deb822
source requires an archive keyring through `Signed-By`. MSIX and macOS bundle
metadata live under `packaging/`; platform stores perform their own package
signature verification in addition to the detached update-channel signature.
