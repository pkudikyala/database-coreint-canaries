#!/usr/bin/env python3
"""Rotate the newrelic/infrastructure-bundle digest pins on the nri-* agent-based canaries.

The nri-* canaries (nri-mysql, nri-mssql, nri-postgresql, nri-oracle,
nri-mongodb, nri-couchbase) don't pin an integration version directly --
they pin a Docker image DIGEST for the shared newrelic/infrastructure-bundle
image (the Infrastructure agent plus every nri- integration, bundled
together), via two floating tags:

    values-stable.yaml    -> newrelic/infrastructure-bundle:latest@sha256:...
    values-candidate.yaml -> newrelic/infrastructure-bundle:a2q-candidate@sha256:...

.github/renovate.json5 has regexManagers/packageRules configured to keep
these current, but Renovate isn't actually installed on this repo (zero
renovate-authored commits, ever) -- so nothing has ever bumped these
digests automatically. That's the exact mechanism that let nri-mssql's
stable (2.34.0) and candidate (2.35.1) drift apart: two floating tags,
each pinned to a stale snapshot, nobody keeping either one in sync.

Unlike scripts/bump_nrdot_collector.py, this does NOT need a "promote
candidate's current version into stable" step. NRDOT publishes one
sequential version stream where stable/candidate are two positions in the
same sequence; `latest` and `a2q-candidate` are different -- two
independently published, permanently distinct tags (current GA release vs.
a purpose-built RC channel), not two positions in one sequence. So each
role's digest is resolved and rewritten independently; there's no
cross-file ordering logic.

Usage:
    python3 scripts/bump_infra_bundle_digest.py [--dry-run] [--repo-root PATH]

Exit code 0 either way. Prints a GITHUB_OUTPUT-compatible line
(`changed=true` / `changed=false`) and, when changed, a markdown summary
suitable for a PR body -- written to stdout between `-----PR-BODY-----`
markers, same convention as bump_nrdot_collector.py.

Does not commit or push anything itself -- that's the calling workflow's
job (or run manually and review the diff before committing). Deliberately
does NOT auto-merge anything downstream either: a bare digest bump can
carry a real behavioral change (confirmed firsthand -- the 2.35.0
`DatabaseName` field addition to MSSQLQueryExecutionPlans, bundled inside
one of these digest updates, caused a real +40% ingestion increase that
broke multiple a2q-test-suites thresholds). Always worth a human skim
before it deploys.
"""
import argparse
import json
import re
import sys
import urllib.request
from pathlib import Path

DOCKER_REPO = "newrelic/infrastructure-bundle"
TAG_API_URL_TEMPLATE = f"https://hub.docker.com/v2/repositories/{DOCKER_REPO}/tags/{{tag}}"

# role -> (docker tag it tracks, files pinning that role's digest).
# Verified to exist and share byte-for-byte identical digests across all
# six canaries as of 2026-08-25.
#
# nri-oracle EXCLUDED: the infrastructure-bundle image in its chart only runs
# the K8s-metrics DaemonSet (kubelet/ksm) -- the actual Oracle integration
# (nri-oracledb) runs as a separate standalone agent
# (canaries/nri-oracle/templates/oracle-agent.yaml), versioned independently
# via values.yaml's oracleAgent.nriOracledbVersion, and isn't touched by this
# script at all either way. Re-adding oracle's DaemonSet piece to ROLES
# hasn't been attempted; it would need the same initContainer chmod fix
# below applied to its chart first.
KNOWN_BAD_DIGESTS = {
    # Both digests are agent v1.80.0, which crashed on startup on this
    # cluster: Kubernetes emptyDir volumes are world-writable by default,
    # and v1.80.0 treats a world-writable /var/db/newrelic-infra/data as
    # "unsafe" and fails instead of using it -- confirmed not specific to
    # any one canary (hit nri-mssql and nri-postgresql identically).
    #
    # RESOLVED 2026-08-26 (commits 4728895, 11026ed): fixed at the Helm
    # chart level with an initContainer that chmods the emptyDir to 0750
    # before the agent container starts, deployed and verified live on all
    # five canaries (stable + candidate) with 0 restarts. These two digests
    # are not currently dangerous -- all five stable files are pinned to the
    # first one below right now, running fine. This set stays purely as a
    # historical guard against ever silently re-proposing this *exact*
    # digest without the chmod fix in place; it says nothing about any
    # other build, and does not need to be cleared out.
    "sha256:dbb100ca28efa52d3e74a48be6d42fd12e4f74e96adc225dec61c7296e4184e4",  # latest
    "sha256:454a3b839668e86cd05465e2349a5158d55f960bf5f59e5c82f7c98c7485cd77",  # a2q-candidate
}
ROLES = {
    "stable": {
        "tag": "latest",
        "files": [
            "canaries/nri-mysql/values-stable.yaml",
            "canaries/nri-mssql/values-stable.yaml",
            "canaries/nri-postgresql/values-stable.yaml",
            "canaries/nri-mongodb/values-stable.yaml",
            "canaries/nri-couchbase/values-stable.yaml",
        ],
    },
    "candidate": {
        "tag": "a2q-candidate",
        "files": [
            "canaries/nri-mysql/values-candidate.yaml",
            "canaries/nri-mssql/values-candidate.yaml",
            "canaries/nri-postgresql/values-candidate.yaml",
            "canaries/nri-mongodb/values-candidate.yaml",
            "canaries/nri-couchbase/values-candidate.yaml",
        ],
    },
}

# Matches `tag: latest@sha256:...` or `tag: a2q-candidate@sha256:...`,
# capturing the prefix (group 1) and the digest itself (group 2) separately
# so the tag name and every other line in the file is left byte-for-byte
# untouched -- not a YAML round-trip, a single targeted regex substitution,
# same approach as bump_nrdot_collector.py's TAG_LINE_RE.
DIGEST_RE_TEMPLATE = r"(tag:\s*{tag}@)(sha256:[a-f0-9]+)"


def fetch_json(url):
    req = urllib.request.Request(url, headers={"Accept": "application/json"})
    with urllib.request.urlopen(req, timeout=15) as resp:
        return json.load(resp)


def resolve_digest(tag: str):
    """Returns (digest, last_updated) for a Docker Hub tag on DOCKER_REPO."""
    data = fetch_json(TAG_API_URL_TEMPLATE.format(tag=tag))
    digest = data.get("digest")
    if not digest:
        raise RuntimeError(f"no 'digest' field in Docker Hub response for tag {tag!r}: {data}")
    return digest, data.get("last_updated", "unknown date")


def get_current_digest(path: Path, tag: str) -> str:
    text = path.read_text()
    pattern = re.compile(DIGEST_RE_TEMPLATE.format(tag=re.escape(tag)))
    m = pattern.search(text)
    if not m:
        raise RuntimeError(f"could not find a 'tag: {tag}@sha256:...' line in {path}")
    return m.group(2)


def set_digest(path: Path, tag: str, new_digest: str) -> None:
    text = path.read_text()
    pattern = re.compile(DIGEST_RE_TEMPLATE.format(tag=re.escape(tag)))

    def repl(m: re.Match) -> str:
        return f"{m.group(1)}{new_digest}"

    new_text, count = pattern.subn(repl, text, count=1)
    if count != 1:
        raise RuntimeError(f"expected exactly one 'tag: {tag}@sha256:...' line in {path}, got {count}")
    path.write_text(new_text)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true", help="don't write files, just report")
    parser.add_argument("--repo-root", default=".", help="repo root (default: cwd)")
    args = parser.parse_args()

    root = Path(args.repo_root).resolve()

    changes = []  # list of (role, tag, old_digest, new_digest, last_updated)
    for role, cfg in ROLES.items():
        tag = cfg["tag"]
        files = cfg["files"]

        # All files for a role are verified to share one digest -- read the
        # first as the "current" value; if any of the others disagree
        # that's itself worth surfacing rather than silently overwriting.
        first_path = root / files[0]
        current_digest = get_current_digest(first_path, tag)
        mismatched = [
            f for f in files[1:]
            if get_current_digest(root / f, tag) != current_digest
        ]
        if mismatched:
            print(
                f"WARNING: {role} files disagree on the pinned digest for tag "
                f"{tag!r} -- {files[0]} has {current_digest}, but {mismatched} "
                f"differ. Proceeding using {files[0]}'s value as current; this "
                f"mismatch itself may need manual attention."
            )

        new_digest, last_updated = resolve_digest(tag)

        if new_digest == current_digest:
            print(f"{role} ({tag}): already up to date at {current_digest}.")
            continue

        if new_digest in KNOWN_BAD_DIGESTS:
            print(
                f"{role} ({tag}): Docker Hub's current tag resolves to {new_digest}, "
                f"which is on KNOWN_BAD_DIGESTS (confirmed crash-on-startup). "
                f"Skipping -- staying on {current_digest} until a newer digest is "
                f"published. Remove this entry from KNOWN_BAD_DIGESTS once a fixed "
                f"build is confirmed."
            )
            continue

        changes.append((role, tag, current_digest, new_digest, last_updated))
        print(
            f"{role} ({tag}): {current_digest} -> {new_digest} "
            f"(tag last updated {last_updated})."
        )

        if not args.dry_run:
            for rel_path in files:
                set_digest(root / rel_path, tag, new_digest)
            print(f"  Updated {len(files)} files for {role}.")
        else:
            print(f"  Dry run -- would update {len(files)} files for {role}.")

    if not changes:
        print("changed=false")
        return 0

    print("changed=true")
    print("-----PR-BODY-----")
    print("## Rotate infrastructure-bundle digest\n")
    for role, tag, old_digest, new_digest, last_updated in changes:
        print(f"**{role}** (`{tag}`): `{old_digest}` -> `{new_digest}` (tag last updated {last_updated})")
    print()
    print(
        "**Before merging:** a bare digest bump can carry a real behavioral "
        "change -- this bundle carries every nri- integration's binary, and "
        "a past bump silently added a new field to MSSQLQueryExecutionPlans "
        "that increased candidate's ingestion by 40% and broke several "
        "a2q-test-suites thresholds before anyone noticed. Check what "
        "actually shipped in the new digest (e.g. pull the image and diff "
        "`/var/db/newrelic-infra/newrelic-integrations/bin/nri-*` version "
        "output against the previous digest, or check "
        "https://github.com/newrelic/infrastructure-bundle for what's "
        "included at this build) before merging, and re-verify any "
        "already-tuned NRQL thresholds in a2q-test-suites if an integration "
        "version moved."
    )
    print("-----PR-BODY-----")
    return 0


if __name__ == "__main__":
    sys.exit(main())
