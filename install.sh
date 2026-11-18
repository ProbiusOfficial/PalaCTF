#!/usr/bin/env bash
# Install PalaCTF from a signed GitHub release bundle.
#
# The bundle and its published SHA-256 file are downloaded from a release. The
# signed manifest inside the bundle is verified with a caller-supplied release
# public key before any bundled script runs. Only the installer, verifier,
# backup script, optional Docker prerequisite helper and installer templates
# are staged, and each staged file is checked against the signed manifest. The
# bundled installer then performs its own full bundle verification, including
# the stable publish gate receipt.
#
# No release version, public key or signature is embedded here. This script
# works only after a release bundle and the matching public key exist.

set -euo pipefail
umask 077

REPO="${PALA_INSTALL_REPO:-ProbiusOfficial/PalaCTF}"
VERSION=""
TAG=""
PUBKEY=""
PUBKEY_SHA=""
STAGE_PARENT=""
KEEP=0
DOWNLOAD_ONLY=0
INSTALL_ARGS=()
WORK=""
BUNDLE=""
ASSET=""
OS=""
ARCH=""

usage() {
	cat <<'EOF'
Install PalaCTF from a signed GitHub release bundle.

Usage:
  sudo ./install.sh --pubkey FILE [--version VERSION] [--tag TAG] [options] [-- INSTALL_OPTIONS]

Options:
  --version VERSION      Release version, for example 0.2.0. When omitted, the
                         latest published release is used.
  --tag TAG              Release tag when it differs from vVERSION.
  --repo OWNER/REPO      Release repository (default ProbiusOfficial/PalaCTF).
  --pubkey FILE          Trusted release public key or X.509 certificate.
                         Required; obtain it through a channel you trust.
  --pubkey-sha256 HEX    Expected SHA-256 fingerprint of the public key DER.
                         Colons and upper case are accepted.
  --dir DIR              Parent directory for the staging directory.
  --keep                 Keep the staging directory after the install.
  --download-only        Download, verify and stage the bundle without running
                         the installer. Implies --keep.
  --                     Pass the remaining options to the bundled installer,
                         for example --dry-run, --yes, --no-admin, --upgrade,
                         --install-docker, --root DIR or --systemd-dir DIR.
                         --install-docker uses the signed bundle's Docker
                         prerequisite helper on supported hosts.

The installer requires a published release asset named
palactf-<version>-linux-<amd64|arm64>.tar.gz and its .sha256 file. It refuses
to run when no release exists, when the checksum does not match, when the
manifest signature does not verify, or when the signing key fingerprint does
not match the signed manifest.
EOF
}

die() {
	printf 'install: %s\n' "$*" >&2
	exit 1
}

note() {
	printf 'install: %s\n' "$*" >&2
}

cleanup() {
	if [ -n "$WORK" ] && [ "$KEEP" -eq 0 ]; then
		rm -rf -- "$WORK"
	fi
}
trap cleanup EXIT

while [ "$#" -gt 0 ]; do
	case "$1" in
	--version | --tag | --repo | --pubkey | --pubkey-sha256 | --dir)
		[ "$#" -ge 2 ] && [ -n "$2" ] || die "$1 requires a value"
		case "$1" in
		--version) VERSION="$2" ;;
		--tag) TAG="$2" ;;
		--repo) REPO="$2" ;;
		--pubkey) PUBKEY="$2" ;;
		--pubkey-sha256) PUBKEY_SHA="$2" ;;
		--dir) STAGE_PARENT="$2" ;;
		esac
		shift 2
		;;
	--keep)
		KEEP=1
		shift
		;;
	--download-only)
		DOWNLOAD_ONLY=1
		KEEP=1
		shift
		;;
	-h | --help)
		usage
		exit 0
		;;
	--)
		shift
		INSTALL_ARGS=("$@")
		break
		;;
	-*)
		die "unknown option: $1"
		;;
	*)
		die "unexpected argument: $1"
		;;
	esac
done

[ -n "$PUBKEY" ] || die "--pubkey is required"
[ -f "$PUBKEY" ] && [ -r "$PUBKEY" ] && [ ! -L "$PUBKEY" ] ||
	die "public key must be a readable regular file, not a symlink: $PUBKEY"

case "$REPO" in
*/*) ;;
*) die "invalid repository: $REPO (expected OWNER/REPO)" ;;
esac
printf '%s\n' "$REPO" |
	grep -Eq '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$' ||
	die "invalid repository: $REPO (expected OWNER/REPO)"

VERSION="${VERSION#v}"
if [ -n "$VERSION" ]; then
	printf '%s\n' "$VERSION" |
		grep -Eq '^[0-9A-Za-z][0-9A-Za-z._+-]*$' ||
		die "invalid version: $VERSION"
fi
if [ -n "$TAG" ]; then
	[ -n "$VERSION" ] || die "--tag requires --version"
	printf '%s\n' "$TAG" |
		grep -Eq '^[0-9A-Za-z][0-9A-Za-z._+-]*$' ||
		die "invalid tag: $TAG"
fi

if [ -n "$PUBKEY_SHA" ]; then
	PUBKEY_SHA="$(printf '%s' "$PUBKEY_SHA" | tr -d '[:space:]:' | tr 'A-F' 'a-f')"
	printf '%s\n' "$PUBKEY_SHA" | grep -Eq '^[0-9a-f]{64}$' ||
		die "--pubkey-sha256 must be a SHA-256 fingerprint"
fi

for tool in python3 openssl sha256sum stat tar gzip mktemp; do
	command -v "$tool" >/dev/null 2>&1 || die "missing required tool: $tool"
done
command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1 ||
	die "curl or wget is required"

if [ "${#INSTALL_ARGS[@]}" -gt 0 ]; then
	for arg in "${INSTALL_ARGS[@]}"; do
		case "$arg" in
		--bundle | --bundle=* | --pubkey | --pubkey=* | --binary | --binary=* | --sha256 | --sha256=* | --version | --version=* | --postgres-archive | --postgres-archive=* | --postgres-archive-sha256 | --postgres-archive-sha256=* | --docker-prereq | --docker-prereq=*)
			die "the installer option $arg is controlled by this script"
			;;
		esac
	done
fi

case "$(uname -s)/$(uname -m)" in
Linux/x86_64 | Linux/amd64)
	OS=linux
	ARCH=amd64
	;;
Linux/aarch64 | Linux/arm64)
	OS=linux
	ARCH=arm64
	;;
*)
	die "unsupported platform: $(uname -s)/$(uname -m); only Linux amd64 and arm64 are supported"
	;;
esac

if [ -n "$STAGE_PARENT" ]; then
	mkdir -p -- "$STAGE_PARENT" || die "cannot create $STAGE_PARENT"
	STAGE_PARENT="$(cd -- "$STAGE_PARENT" && pwd -P)" ||
		die "cannot resolve $STAGE_PARENT"
	WORK="$(mktemp -d "${STAGE_PARENT%/}/palactf-install.XXXXXX")" ||
		die "cannot create a staging directory under $STAGE_PARENT"
else
	WORK="$(mktemp -d "${TMPDIR:-/tmp}/palactf-install.XXXXXX")" ||
		die "cannot create a staging directory"
fi

fetch() {
	local source="$1" dest="$2" limit="$3" size
	if command -v curl >/dev/null 2>&1; then
		curl --http1.1 --fail --silent --show-error --location \
			--connect-timeout 10 --max-time 1800 \
			--retry 3 --retry-all-errors --retry-delay 2 \
			--max-filesize "$limit" --max-redirs 5 \
			--proto '=https' --proto-redir '=https' --globoff \
			--output "$dest" -- "$source" || return 1
	elif command -v wget >/dev/null 2>&1; then
		wget --quiet --https-only --max-redirect=5 --timeout=30 --tries=1 \
			--output-document="$dest" -- "$source" || return 1
	fi
	size="$(stat -c '%s' -- "$dest")" || return 1
	[ "$size" -gt 0 ] && [ "$size" -le "$limit" ]
}

resolve_latest() {
	local api="$WORK/release.json" meta
	fetch "https://api.github.com/repos/$REPO/releases/latest" "$api" 1048576 ||
		die "cannot read the latest release for $REPO; no release may be published yet or the GitHub API is unavailable"
	meta="$(python3 - "$api" "$ARCH" <<'PY'
import json
import re
import sys

path, arch = sys.argv[1:3]


def fail(message):
    raise SystemExit("install: " + message)


try:
    with open(path, encoding="utf-8") as handle:
        document = json.load(handle)
except (OSError, UnicodeError, ValueError) as exc:
    fail(f"cannot parse the release metadata: {exc}")
if not isinstance(document, dict):
    fail("release metadata is not an object")
tag = document.get("tag_name")
if not isinstance(tag, str) or not re.fullmatch(r"[0-9A-Za-z][0-9A-Za-z._+-]*", tag):
    fail("latest release has no usable tag")
assets = document.get("assets")
if not isinstance(assets, list):
    fail("latest release has no assets")
pattern = re.compile(
    r"^palactf-([0-9A-Za-z][0-9A-Za-z._+-]*)-linux-" + re.escape(arch) + r"\.tar\.gz$"
)
names = []
for asset in assets:
    if not isinstance(asset, dict):
        fail("release asset entry is malformed")
    name = asset.get("name")
    if not isinstance(name, str):
        fail("release asset name is malformed")
    names.append(name)
matches = [(name, pattern.fullmatch(name).group(1)) for name in names if pattern.fullmatch(name)]
if len(matches) != 1:
    fail(f"latest release does not contain exactly one linux/{arch} bundle")
bundle, version = matches[0]
if bundle + ".sha256" not in names:
    fail(f"latest release does not contain {bundle}.sha256")
print(tag)
print(bundle)
print(version)
PY
)" || die "latest release does not provide a usable linux/$ARCH bundle"
	TAG="$(printf '%s\n' "$meta" | sed -n '1p')"
	ASSET="$(printf '%s\n' "$meta" | sed -n '2p')"
	VERSION="$(printf '%s\n' "$meta" | sed -n '3p')"
	[ -n "$TAG" ] && [ -n "$ASSET" ] && [ -n "$VERSION" ] ||
		die "latest release metadata is incomplete"
}

PUBKEY_DIR="$(cd -- "$(dirname -- "$PUBKEY")" && pwd -P)" ||
	die "cannot resolve the public key directory"
PUBKEY="$PUBKEY_DIR/$(basename -- "$PUBKEY")"
if ! openssl pkey -pubin -in "$PUBKEY" -out "$WORK/public.pem" </dev/null >/dev/null 2>&1; then
	openssl x509 -in "$PUBKEY" -pubkey -noout >"$WORK/public.pem" 2>/dev/null ||
		die "cannot read a public key or certificate from $PUBKEY"
fi
openssl pkey -pubin -in "$WORK/public.pem" -noout </dev/null >/dev/null 2>&1 ||
	die "invalid public key: $PUBKEY"
KEY_SHA="$(openssl pkey -pubin -in "$WORK/public.pem" -outform DER 2>/dev/null |
	sha256sum | awk '{print $1}')"
printf '%s\n' "$KEY_SHA" | grep -Eq '^[0-9a-f]{64}$' ||
	die "cannot compute the public key fingerprint"
if [ -n "$PUBKEY_SHA" ]; then
	[ "$KEY_SHA" = "$PUBKEY_SHA" ] ||
		die "public key fingerprint $KEY_SHA does not match --pubkey-sha256 $PUBKEY_SHA"
fi

if [ -z "$VERSION" ]; then
	resolve_latest
else
	ASSET="palactf-${VERSION}-${OS}-${ARCH}.tar.gz"
	[ -n "$TAG" ] || TAG="v$VERSION"
fi

BUNDLE="$WORK/$ASSET"
SUM="$BUNDLE.sha256"
BASE="https://github.com/$REPO/releases/download/$TAG"

note "release: $REPO $TAG ($OS/$ARCH)"
note "public key sha256: $KEY_SHA"
note "downloading $ASSET"
fetch "$BASE/$ASSET" "$BUNDLE" 8589934592 ||
	die "cannot download $BASE/$ASSET; check the network and release assets"
fetch "$BASE/$ASSET.sha256" "$SUM" 4096 ||
	die "cannot download $BASE/$ASSET.sha256; check the network and release assets"

lines="$(awk 'NF { count++ } END { print count + 0 }' "$SUM")"
[ "$lines" -eq 1 ] || die "checksum file must contain exactly one entry"
read -r expected_sum expected_name <"$SUM" ||
	die "cannot read the checksum file"
expected_name="${expected_name#\*}"
case "$expected_sum" in
*[!0-9a-fA-F]* | "") die "checksum file has an invalid digest" ;;
esac
[ "${#expected_sum}" -eq 64 ] || die "checksum file has an invalid digest"
[ "$expected_name" = "$ASSET" ] ||
	die "checksum file names $expected_name, expected $ASSET"
actual_sum="$(sha256sum -- "$BUNDLE" | awk '{print $1}')"
[ "$actual_sum" = "$(printf '%s' "$expected_sum" | tr 'A-F' 'a-f')" ] ||
	die "release bundle checksum does not match $ASSET.sha256"
note "bundle checksum: $actual_sum"

STAGE="$WORK/manifest"
mkdir -p -- "$STAGE"
python3 - "$BUNDLE" "$STAGE" <<'PY' || die "release bundle is not a safe archive"
import os
import stat
import sys
import tarfile

bundle, stage = sys.argv[1:3]
wanted = {"manifest.json": 1048576, "manifest.json.sig": 65536}
found = {}
top = None
count = 0
total = 0


def fail(message):
    raise SystemExit("install: " + message)


try:
    with tarfile.open(bundle, "r:gz") as archive:
        for member in archive:
            count += 1
            if count > 20000:
                fail("release bundle has too many members")
            name = member.name
            if not name or "\\" in name or any(ord(ch) < 32 for ch in name):
                fail(f"unsafe archive path: {name!r}")
            if name.startswith("/"):
                fail(f"absolute archive path: {name}")
            parts = name.rstrip("/").split("/")
            if any(part in ("", ".", "..") for part in parts):
                fail(f"unsafe archive path: {name!r}")
            if top is None:
                top = parts[0]
            elif parts[0] != top:
                fail("release bundle does not use a single top-level directory")
            if member.mode & 0o7000:
                fail(f"setuid, setgid or sticky bit on {name}")
            if len(parts) == 1:
                if not member.isdir():
                    fail("release bundle top-level entry is not a directory")
                continue
            if member.isdir():
                continue
            if not member.isreg():
                fail(f"link or special file in release bundle: {name}")
            if member.mode & 0o777 not in (0o644, 0o755):
                fail(f"unexpected file mode on {name}")
            total += member.size
            if total > 8589934592:
                fail("release bundle exceeds the size limit")
            if len(parts) == 2 and parts[1] in wanted:
                base = parts[1]
                if base in found:
                    fail(f"duplicate {base} in release bundle")
                if member.size < 1 or member.size > wanted[base]:
                    fail(f"release bundle {base} has an invalid size")
                handle = archive.extractfile(member)
                if handle is None:
                    fail(f"cannot read {base} from the release bundle")
                blob = handle.read(wanted[base] + 1)
                if len(blob) != member.size:
                    fail(f"cannot read {base} from the release bundle")
                destination = os.path.join(stage, base)
                with open(destination, "wb") as output:
                    output.write(blob)
                os.chmod(destination, 0o644)
                found[base] = True
except (OSError, tarfile.TarError) as exc:
    fail(f"cannot read the release bundle: {exc}")

if top is None:
    fail("release bundle is empty")
if set(found) != set(wanted):
    fail("release bundle has no top-level signed manifest")
PY

openssl dgst -sha256 -verify "$WORK/public.pem" \
	-signature "$STAGE/manifest.json.sig" "$STAGE/manifest.json" \
	</dev/null >/dev/null 2>&1 ||
	die "release manifest signature verification failed"

HELPERS="$WORK/helpers"
mkdir -p -- "$HELPERS"
python3 - "$BUNDLE" "$STAGE/manifest.json" "$HELPERS" "$KEY_SHA" \
	"$VERSION" "$ASSET" "$OS" "$ARCH" <<'PY' || die "signed manifest does not authenticate the installer scripts"
import hashlib
import json
import os
import re
import stat
import sys
import tarfile

bundle, manifest_path, stage, key_sha, expect_version, asset, target_os, target_arch = sys.argv[1:9]
wanted = {
    "installer": ("install.sh", "0755"),
    "verifier": ("verify.sh", "0755"),
    "backup-script": ("backup.sh", "0755"),
    "docker-prereq": ("docker-prereq.sh", "0755"),
    "template-pala-env": ("templates/pala.env.tmpl", "0644"),
    "template-postgres-env": ("templates/postgres.env.tmpl", "0644"),
    "template-palactf-service": ("templates/palactf.service", "0644"),
    "template-postgres-service": ("templates/palactf-postgres.service", "0644"),
}
DIGEST = re.compile(r"[0-9a-f]{64}")


def fail(message):
    raise SystemExit("install: " + message)


def unique(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            fail("signed manifest has a duplicate field")
        result[key] = value
    return result


try:
    with open(manifest_path, encoding="utf-8") as handle:
        document = json.load(handle, object_pairs_hook=unique)
except (OSError, UnicodeError, ValueError) as exc:
    fail(f"cannot parse the signed manifest: {exc}")
if not isinstance(document, dict):
    fail("signed manifest is not a JSON object")

required = {
    "schemaVersion", "product", "version", "channel", "createdAt",
    "os", "arch", "archive", "signingKeySha256", "artifacts",
}
if not required <= set(document):
    fail("signed manifest is missing required fields")
if type(document["schemaVersion"]) is not int or document["schemaVersion"] != 1:
    fail("unsupported signed manifest schemaVersion")
if document["product"] != "PalaCTF":
    fail("signed manifest product is not PalaCTF")
version = document["version"]
if not isinstance(version, str) or not re.fullmatch(r"[0-9A-Za-z][0-9A-Za-z._+-]*", version):
    fail("signed manifest version is invalid")
if expect_version and version != expect_version:
    fail(f"signed manifest version is {version}, expected {expect_version}")
if not isinstance(document["channel"], str) or not re.fullmatch(
        r"[a-z0-9][a-z0-9._-]*", document["channel"]):
    fail("signed manifest channel is invalid")
if document["os"] != target_os or document["arch"] != target_arch:
    fail("signed manifest target does not match this host")
if document["archive"] != asset:
    fail("signed manifest archive does not match the downloaded bundle")
if document["signingKeySha256"] != key_sha:
    fail("signed manifest signingKeySha256 does not match the public key")

artifacts = document["artifacts"]
if not isinstance(artifacts, list) or not artifacts:
    fail("signed manifest has no artifacts")
selected = {}
paths = set()
for entry in artifacts:
    if not isinstance(entry, dict) or set(entry) != {"name", "path", "size", "sha256", "mode"}:
        fail("signed manifest artifact is malformed")
    name = entry["name"]
    path = entry["path"]
    if not isinstance(name, str) or not name or name in selected:
        fail("signed manifest artifact name is invalid or duplicated")
    if not isinstance(path, str) or os.path.isabs(path):
        fail(f"artifact path is invalid: {path!r}")
    parts = path.split("/")
    if any(part in ("", ".", "..") for part in parts):
        fail(f"artifact path is unsafe: {path!r}")
    if path in paths:
        fail(f"artifact path is duplicated: {path}")
    paths.add(path)
    if entry["mode"] not in ("0644", "0755"):
        fail(f"artifact mode is invalid: {path}")
    if type(entry["size"]) is not int or entry["size"] < 1:
        fail(f"artifact size is invalid: {path}")
    if not isinstance(entry["sha256"], str) or not DIGEST.fullmatch(entry["sha256"]):
        fail(f"artifact digest is invalid: {path}")
    if name in wanted:
        expected_path, expected_mode = wanted[name]
        if path != expected_path or entry["mode"] != expected_mode:
            fail(f"signed manifest has an unexpected {name} artifact")
        selected[name] = entry

for name, (path, mode) in wanted.items():
    if name != "docker-prereq" and name not in selected:
        fail(f"signed manifest does not list the {name} artifact")

by_path = {entry["path"]: (name, entry) for name, entry in selected.items()}
for entry in by_path.values():
    if entry[1]["size"] > 16777216:
        fail(f"installer artifact is too large: {entry[1]['path']}")
written = set()
top = None
count = 0


try:
    with tarfile.open(bundle, "r:gz") as archive:
        for member in archive:
            count += 1
            if count > 20000:
                fail("release bundle has too many members")
            name = member.name
            if not name or "\\" in name or any(ord(ch) < 32 for ch in name):
                fail(f"unsafe archive path: {name!r}")
            if name.startswith("/"):
                fail(f"absolute archive path: {name}")
            parts = name.rstrip("/").split("/")
            if any(part in ("", ".", "..") for part in parts):
                fail(f"unsafe archive path: {name!r}")
            if top is None:
                top = parts[0]
            elif parts[0] != top:
                fail("release bundle does not use a single top-level directory")
            if member.mode & 0o7000:
                fail(f"setuid, setgid or sticky bit on {name}")
            if len(parts) < 2:
                continue
            relative = "/".join(parts[1:])
            if relative not in by_path:
                continue
            entry = by_path[relative][1]
            if relative in written:
                fail(f"duplicate {relative} in release bundle")
            if not member.isreg():
                fail(f"{relative} is not a regular file in the release bundle")
            if stat.S_IMODE(member.mode) != int(entry["mode"], 8):
                fail(f"{relative} has the wrong mode in the release bundle")
            if member.size != entry["size"]:
                fail(f"{relative} has the wrong size in the release bundle")
            handle = archive.extractfile(member)
            if handle is None:
                fail(f"cannot read {relative} from the release bundle")
            try:
                blob = handle.read(entry["size"] + 1)
            finally:
                handle.close()
            if len(blob) != entry["size"]:
                fail(f"cannot read {relative} from the release bundle")
            if hashlib.sha256(blob).hexdigest() != entry["sha256"]:
                fail(f"{relative} does not match the signed manifest")
            destination = os.path.join(stage, relative)
            parent = os.path.dirname(destination)
            os.makedirs(parent, mode=0o755, exist_ok=True)
            os.chmod(parent, 0o755)
            with open(destination, "wb") as output:
                output.write(blob)
            os.chmod(destination, int(entry["mode"], 8))
            written.add(relative)
except (OSError, tarfile.TarError) as exc:
    fail(f"cannot read the release bundle: {exc}")

if top is None:
    fail("release bundle is empty")
if written != set(by_path):
    fail("release bundle is missing signed installer scripts")
PY

note "signed manifest and installer scripts verified"

if [ "$DOWNLOAD_ONLY" -eq 1 ]; then
	note "staged bundle: $BUNDLE"
	note "staged installer: $HELPERS/install.sh"
	note "staged verifier: $HELPERS/verify.sh"
	note "release version: $VERSION"
	exit 0
fi

PREREQ_ARGS=()
for arg in "${INSTALL_ARGS[@]}"; do
	if [ "$arg" = --install-docker ]; then
		[ -f "$HELPERS/docker-prereq.sh" ] ||
			die "--install-docker requires a docker-prereq.sh authenticated by the signed manifest"
		PREREQ_ARGS=(--docker-prereq "$HELPERS/docker-prereq.sh")
		break
	fi
done

note "running the verified bundled installer"
env -u PALACTF_BINARY -u PALACTF_SHA256 -u PALACTF_BUNDLE -u PALACTF_PUBKEY -u PALACTF_VERSION \
	"$HELPERS/install.sh" --bundle "$BUNDLE" --pubkey "$PUBKEY" \
	"${PREREQ_ARGS[@]}" "${INSTALL_ARGS[@]}"
