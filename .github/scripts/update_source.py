#!/usr/bin/env python3
"""
Update docs/source.json with a new Bulk AI version.

Called from the build-ipa workflow after a successful build. Reads the existing
manifest, prepends a new entry to apps[0].versions[], and writes back. Newer
entries first is the convention AltStore expects.

Inputs come from environment variables set by the workflow:
  VERSION  - the version string we just built, e.g. "1.0.42"
  DATE     - ISO-8601 timestamp of the build
  SIZE     - size in bytes of the BulkAI.ipa we uploaded to the Release
  REPO     - "owner/repo" e.g. "edrickchang13/food"
  OWNER    - "owner" e.g. "edrickchang13"
  SHA      - the commit SHA we built from
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
SOURCE_PATH = REPO_ROOT / "docs" / "source.json"


def env(name: str) -> str:
    value = os.environ.get(name)
    if not value:
        sys.exit(f"missing required env var {name}")
    return value


def main() -> None:
    version = env("VERSION")
    date = env("DATE")
    size = int(env("SIZE"))
    repo = env("REPO")
    sha = env("SHA")

    download_url = f"https://github.com/{repo}/releases/download/v{version}/BulkAI.ipa"

    if not SOURCE_PATH.exists():
        sys.exit(f"source.json not found at {SOURCE_PATH}; commit a template first")

    manifest = json.loads(SOURCE_PATH.read_text())
    if not manifest.get("apps"):
        sys.exit("manifest has no apps[]")

    app = manifest["apps"][0]
    versions = app.setdefault("versions", [])

    new_entry = {
        "version": version,
        "date": date,
        "localizedDescription": (
            "Latest build from main."
            f"\n\nCommit {sha[:7]}."
        ),
        "downloadURL": download_url,
        "size": size,
    }

    # If a build for this version already exists (re-running workflow_dispatch),
    # replace it in place. Otherwise prepend so newest is first.
    existing_idx = next(
        (i for i, v in enumerate(versions) if v.get("version") == version),
        None,
    )
    if existing_idx is not None:
        versions[existing_idx] = new_entry
    else:
        versions.insert(0, new_entry)

    # Keep the most recent 25 versions so the file doesn't grow forever.
    app["versions"] = versions[:25]

    SOURCE_PATH.write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"Updated {SOURCE_PATH} with version {version}")


if __name__ == "__main__":
    main()
