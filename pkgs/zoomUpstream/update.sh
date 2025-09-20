#!/usr/bin/env bash
set -euo pipefail

TMP=$(mktemp -d)
DEB="$TMP/zoom_amd64.deb"

# Download the latest .deb
curl -L -o "$DEB" https://zoom.us/client/latest/zoom_amd64.deb

# Extract version.txt from the .deb
dpkg-deb -x "$DEB" "$TMP/extract"
VERSION=$(cat "$TMP/extract/opt/zoom/version.txt")

# Compute SHA256 for Nix
SHA256=$(nix hash file "$DEB" --type sha256)

# Write version.nix
VERSION_FILE="pkgs/zoomUpstream/version.nix"
cat > "$VERSION_FILE" <<EOF
{ fetchurl }:
{
  version = "$VERSION";
  src = fetchurl {
    url = "https://zoom.us/client/latest/zoom_amd64.deb";
    sha256 = "$SHA256";
  };
}
EOF

# Stage the file in git
#git add "$VERSION_FILE"
#git commit -m "Generated and staged $VERSION_FILE -> version $VERSION"
echo "Generated and staged $VERSION_FILE -> version $VERSION"

