#!/usr/bin/env python3
"""Download the latest PlantMetWiki RDF data from Zenodo and GitHub releases.

NOTE: This script downloads from Zenodo, which may lag behind the latest
local pipeline run. If you have a more recent local build in
gpml-to-rdf/output/bundles/, use those instead — they will be larger
and include fixes not yet uploaded to Zenodo.

Downloads two datasets:
  1. Pathway RDF (gpml-to-rdf) from Zenodo 10.5281/zenodo.17967619
       all-*.ttl.gz                          → core pathway + reactions RDF
       all_gpml_taxonomy_extra-*.ttl.gz      → species/organism annotations
       all_gpml_properties_extra-*.ttl.gz    → PlantCyc property extra RDF
       void-*.ttl                             → VoID metadata
       ncbi_iri_mappings-*.ttl               → NCBI IRI crosslinks

  2. BGC crosslink RDF (map-to-rdf) from Zenodo 10.5281/zenodo.20345133
       output_ttl/plantismash.ttl            → plantiSMASH BGC RDF
       output_ttl/mibig.ttl                  → MIBiG BGC RDF
       output_ttl/void-bgc.ttl              → BGC VoID metadata

Files are written to db/data/ and decompressed if gzipped.
Run scripts/load-plantmetwiki-data.sh afterwards to load into Virtuoso.

Usage
-----
    python scripts/download-plantmetwiki-data.py
    python scripts/download-plantmetwiki-data.py --out-dir db/data
    python scripts/download-plantmetwiki-data.py --skip-pathways   # BGC only
    python scripts/download-plantmetwiki-data.py --skip-bgc        # pathways only
    python scripts/download-plantmetwiki-data.py --bgc-tag bgc-v1.1  # pin a specific
                                                                       # map-to-rdf release
                                                                       # (default: auto-detect
                                                                       # latest bgc-vX.Y tag)
"""

from __future__ import annotations

import argparse
import gzip
import re
import shutil
import sys
from pathlib import Path
from urllib.parse import urlparse

import requests

# ── Zenodo records ────────────────────────────────────────────────────────────
ZENODO_PATHWAYS_DOI = "10.5281/zenodo.17967619"   # gpml-to-rdf
ZENODO_BGC_DOI      = "10.5281/zenodo.20345133"   # map-to-rdf (concept DOI, always latest)
ZENODO_API          = "https://zenodo.org/api/records"
GITHUB_API          = "https://api.github.com"

# Files to download from each Zenodo record (matched by prefix)
PATHWAY_FILE_PREFIXES = (
    "all-",
    "all_gpml_taxonomy_extra-",
    "all_gpml_properties_extra-",
    "void-",
    "ncbi_iri_mappings-",
)

# BGC files: inside the repo zip under output_ttl/ — use GitHub raw URL instead
# (Zenodo releases the whole repo as a zip; raw GitHub is simpler for small files)
#
# The release tag is auto-detected from GitHub (latest "bgc-vX.Y" tag, see
# get_latest_bgc_tag()). BGC_GITHUB_TAG_FALLBACK is only used if that API call
# fails (offline / rate-limited) — bump it whenever map-to-rdf cuts a new
# bgc-vX.Y release so an offline run still gets a sensible default.
# To pin a specific version, pass --bgc-tag bgc-vX.Y.
BGC_GITHUB_OWNER        = "pathway-lod"
BGC_GITHUB_REPO         = "map-to-rdf"
BGC_GITHUB_TAG_FALLBACK = "bgc-v1.1"
BGC_FILES        = [
    "output_ttl/plantismash.ttl",
    "output_ttl/mibig.ttl",
    "output_ttl/void-bgc.ttl",
]


# ── Helpers ───────────────────────────────────────────────────────────────────

def zenodo_record(concept_doi: str) -> dict:
    record_id = concept_doi.split("zenodo.")[-1]
    r = requests.get(f"{ZENODO_API}/{record_id}", timeout=30)
    r.raise_for_status()
    return r.json()


def download_file(url: str, dest: Path, chunk_size: int = 1 << 20) -> None:
    with requests.get(url, stream=True, timeout=120) as r:
        r.raise_for_status()
        total = int(r.headers.get("content-length", 0))
        done  = 0
        with dest.open("wb") as fh:
            for chunk in r.iter_content(chunk_size):
                fh.write(chunk)
                done += len(chunk)
                if total:
                    print(f"\r    {done/1e6:.1f} / {total/1e6:.1f} MB", end="")
    print()


def get_latest_bgc_tag() -> str:
    """Return the latest 'bgc-vX.Y' release tag for map-to-rdf from GitHub.

    Falls back to BGC_GITHUB_TAG_FALLBACK if the GitHub API is unreachable
    or rate-limited (e.g. CI without auth).
    """
    url = f"{GITHUB_API}/repos/{BGC_GITHUB_OWNER}/{BGC_GITHUB_REPO}/tags"
    try:
        r = requests.get(url, timeout=10)
        r.raise_for_status()
        tags = [t["name"] for t in r.json() if re.fullmatch(r"bgc-v\d+\.\d+", t["name"])]
        if tags:
            tags.sort(key=lambda t: tuple(int(x) for x in t[len("bgc-v"):].split(".")))
            return tags[-1]
    except Exception as e:
        print(f"  [WARN] Could not fetch latest bgc- tag from GitHub ({e})")
    print(f"  Falling back to {BGC_GITHUB_TAG_FALLBACK}")
    return BGC_GITHUB_TAG_FALLBACK


def decompress_gz(gz_path: Path) -> Path:
    """Decompress a .gz file in-place; return the decompressed path."""
    out_path = gz_path.with_suffix("")   # strip .gz
    print(f"    Decompressing → {out_path.name} ...", end=" ")
    with gzip.open(gz_path, "rb") as src, out_path.open("wb") as dst:
        shutil.copyfileobj(src, dst)
    gz_path.unlink()
    print(f"{out_path.stat().st_size / 1e6:.1f} MB")
    return out_path


# ── Download functions ────────────────────────────────────────────────────────

def download_pathways(out_dir: Path) -> list[Path]:
    """Download pathway RDF files from Zenodo."""
    print(f"\n── Pathway RDF (Zenodo {ZENODO_PATHWAYS_DOI}) ──────────────────")
    record  = zenodo_record(ZENODO_PATHWAYS_DOI)
    version = record.get("metadata", {}).get("version", "unknown")
    print(f"   Version: {version}")

    files = record.get("files", [])
    print(f"   Available files:")
    for f in files:
        print(f"     {f['key']}  ({f['size']/1e6:.1f} MB)")

    to_download = [f for f in files
                   if any(f["key"].startswith(p) for p in PATHWAY_FILE_PREFIXES)]

    downloaded: list[Path] = []
    for f in to_download:
        key  = f["key"]
        dest = out_dir / key

        if dest.exists() or (dest.with_suffix("") if key.endswith(".gz") else dest).exists():
            already = dest if dest.exists() else dest.with_suffix("")
            print(f"  [SKIP] {key} (already exists)")
            downloaded.append(already)
            continue

        print(f"  ↓ {key}  ({f['size']/1e6:.1f} MB)")
        download_file(f["links"]["self"], dest)

        if key.endswith(".gz"):
            dest = decompress_gz(dest)
        downloaded.append(dest)

    return downloaded


def download_bgc(out_dir: Path, tag: str) -> list[Path]:
    """Download BGC RDF files from a map-to-rdf GitHub release tag (raw URLs).

    Always re-downloads and overwrites any existing copies in out_dir — these
    files are small (<500 KB combined), and re-running this after a new
    bgc-vX.Y release is the intended way to refresh db/data/.
    """
    print(f"\n── BGC crosslink RDF (map-to-rdf {tag}) ─────────────")
    base = (f"https://raw.githubusercontent.com/{BGC_GITHUB_OWNER}/"
            f"{BGC_GITHUB_REPO}/{tag}")

    downloaded: list[Path] = []
    for rel_path in BGC_FILES:
        fname = Path(rel_path).name
        dest  = out_dir / fname
        url   = f"{base}/{rel_path}"

        print(f"  ↓ {fname}")
        download_file(url, dest)
        downloaded.append(dest)

    return downloaded


# ── Main ──────────────────────────────────────────────────────────────────────

def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--out-dir",       type=Path, default=Path("db/data"),
                   help="Directory to write downloaded TTL files (default: db/data)")
    p.add_argument("--skip-pathways", action="store_true",
                   help="Skip pathway RDF download")
    p.add_argument("--skip-bgc",      action="store_true",
                   help="Skip BGC crosslink download")
    p.add_argument("--bgc-tag",       type=str, default=None,
                   help="Pin map-to-rdf release tag for BGC files, e.g. bgc-v1.1 "
                        "(default: auto-detect latest bgc-vX.Y tag from GitHub)")
    return p.parse_args()


def main() -> int:
    args = parse_args()
    args.out_dir.mkdir(parents=True, exist_ok=True)

    all_files: list[Path] = []

    if not args.skip_pathways:
        all_files.extend(download_pathways(args.out_dir))

    if not args.skip_bgc:
        bgc_tag = args.bgc_tag or get_latest_bgc_tag()
        all_files.extend(download_bgc(args.out_dir, bgc_tag))

    print(f"\n── Downloaded files in {args.out_dir}/ ───────────────────────────")
    for f in sorted(args.out_dir.glob("*.ttl")):
        print(f"  {f.name}  ({f.stat().st_size/1e6:.1f} MB)")

    print(f"\n✔ Done.  Next: load into Virtuoso with:")
    print(f"  bash scripts/load-plantmetwiki-data.sh")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
