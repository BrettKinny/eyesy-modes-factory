#!/usr/bin/env python3
"""Fetch the Critter & Guitari GitHub stock-mode inventory.

Enumerates every mode shipped in the critterandguitari GitHub account into
docs/research/inventory/github-stock.json.

Data source: gh api (authenticated), rate-limit safe. python3 stdlib only.
Run: python3 tools/inventory/fetch_github_stock.py
"""
import json
import os
import subprocess
import sys
import time
import urllib.parse
from datetime import date

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
OUT_JSON = os.path.join(ROOT, "docs", "research", "inventory", "github-stock.json")

ACCOUNT = "critterandguitari"
SOURCE_URL = f"https://github.com/{ACCOUNT}"

# repo -> (entry filenames, generation, kind)
REPOS = {
    "EYESY_Modes_OSv3": (["main.py"], "v3-pygame", "mode"),
    "EYESY_Modes_Pygame": (["main.py"], "v2-pygame", "mode"),
    "EYESY_oFLua_Examples": (["main.lua", "mode.lua", "main.cpp"], "v1-of-lua", "example"),
    "EYESY_OF": (["main.py", "main.lua", "mode.lua"], "v1-of-lua", "mode"),
    "EYESY_OS": (["main.py", "main.lua", "mode.lua"], "engine", "mode"),
    "EYESY_Manual": ([], None, None),
    "EYESY_Selector": (["main.py", "main.lua", "mode.lua"], "v1-of-lua", "mode"),
}

# folders whose entry file is engine/OS code, not a mode (repo -> prefixes)
EXCLUDE_FOLDERS = {
    "EYESY_OS": ["engines/python"],
}

PERMALINK = (lambda r, br, p:
    f"https://github.com/{ACCOUNT}/{r}/blob/{br}/"
    + urllib.parse.quote(p, safe="/"))


def gh(endpoint, *rest, retries=1):
    """Run gh api; returns parsed JSON. endpoint is a single path string."""
    args = [endpoint] + list(rest)
    last = None
    for attempt in range(retries + 1):
        r = subprocess.run(["gh", "api"] + args, capture_output=True, text=True)
        if r.returncode == 0 and r.stdout.strip():
            try:
                return json.loads(r.stdout)
            except json.JSONDecodeError:
                pass
        last = r
        time.sleep(0.6)
    print("gh api failed:", endpoint, file=sys.stderr)
    print("  stderr:", last.stderr.strip()[:400], file=sys.stderr)
    raise SystemExit("gh api error: " + endpoint)


def hugestring(dct, key):
    """Read a string from a contents response dict."""
    v = dct.get(key)
    return v if isinstance(v, str) else None


def repo_metadata(name):
    m = gh(f"repos/{ACCOUNT}/{name}")
    return {
        "name": m["name"],
        "default_branch": m["default_branch"],
        "archived": m["archived"],
        "stars": m["stargazers_count"],
        "forks": m["forks_count"],
        "open_issues": m["open_issues_count"],
        "created_at": m["created_at"][:10],
        "pushed_at": m["pushed_at"][:10],
        "license_spdx": (m.get("license") or {}).get("spdx_id") or None,
        "license_name": (m.get("license") or {}).get("name") or None,
        "description": m.get("description"),
        "size_kb": m.get("size"),
    }


def repo_license(rname, branch, tree):
    """Find a root LICENSE file in the tree and return its verbatim text."""
    root = {os.path.basename(e["path"]) for e in tree["tree"]
            if e["type"] == "blob" and "/" not in e["path"]}
    for fname in sorted(root):
        if fname.upper().startswith(("LICENSE", "COPYING")):
            r = gh(f"repos/{ACCOUNT}/{rname}/contents/{fname}?ref={branch}")
            if isinstance(r, list):
                continue
            b64 = hugestring(r, "content")
            if b64:
                return {"file": fname,
                        "text": __import__("base64").b64decode(b64).decode(
                            "utf-8", "replace")}
    return None


def mode_folders(tree, entry_names):
    """Return {folder: {entry, files, bytes, filelist}} for folders holding
    an entry file."""
    res = {}
    for e in tree["tree"]:
        if e["type"] != "blob":
            continue
        base = os.path.basename(e["path"])
        if base in entry_names:
            folder = os.path.dirname(e["path"])
            res.setdefault(folder, {"entry": base, "files": 0, "bytes": 0,
                                    "filelist": []})
    for e in tree["tree"]:
        if e["type"] != "blob":
            continue
        p = e["path"]
        for folder, info in res.items():
            if p == folder or p.startswith(folder + "/"):
                info["files"] += 1
                info["bytes"] += e.get("size", 0)
                info["filelist"].append(p)
    return res


def survey_branches_tags(name):
    """Return (branches, tags) with whether any differ materially."""
    try:
        branches = [b["name"] for b in gh(f"repos/{ACCOUNT}/{name}/branches?per_page=100")]
    except SystemExit:
        branches = []
    try:
        tags = [t["name"] for t in gh(f"repos/{ACCOUNT}/{name}/tags?per_page=100")]
    except SystemExit:
        tags = []
    return branches, tags


def main():
    fetch = "--cached" not in sys.argv
    repos_out = []
    items = []
    license_by_repo = {}

    for name, (entries, gen, kind) in REPOS.items():
        meta = repo_metadata(name)
        branch = meta["default_branch"]

        tree = gh(f"repos/{ACCOUNT}/{name}/git/trees/{branch}?recursive=1")

        lic = repo_license(name, branch, tree)
        license_by_repo[name] = lic

        branches, tags = survey_branches_tags(name)
        folders = mode_folders(tree, entries)
        mode_count = 0
        for folder in sorted(folders):
            if any(folder == x or folder.startswith(x + "/")
                   for x in EXCLUDE_FOLDERS.get(name, [])):
                continue
            mode_count += 1
        repos_out.append({
            "name": name,
            "metadata": meta,
            "license": ({"file": lic["file"]} if lic else None),
            "license_present": bool(lic),
            "branches": branches,
            "tags": tags,
            "mode_count": mode_count,
            "tree_entries": len(tree.get("tree", [])),
            "entry_filenames": entries,
        })

        for folder in sorted(folders):
            if any(folder == x or folder.startswith(x + "/")
                   for x in EXCLUDE_FOLDERS.get(name, [])):
                continue
            info = folders[folder]
            fname = info["entry"]
            items.append({
                "key": f"{name}/{folder}",
                "title": folder,
                "author": "Critter & Guitari",
                "generation": gen,
                "kind": kind,
                "url": PERMALINK(name, branch, f"{folder}/{fname}"),
                "repo_path": folder,
                "license": (meta["license_spdx"] or
                            (lic["file"] if lic else None)),
                "created": None,
                "metrics": {"views": None, "likes": None, "downloads": None},
                "technique": None,
                "notes": _notes(folder, gen, name, meta["license_spdx"], lic),
                "raw": {
                    "entry_file": fname,
                    "files": info["files"],
                    "bytes": info["bytes"],
                    "filelist": info["filelist"],
                },
            })

    # flag cross-repo overlaps by folder basename (matched on both sides)
    basename_items = {}
    for it in items:
        bn = os.path.basename(it["repo_path"])
        basename_items.setdefault(bn, []).append(it)
    overlap_pairs = {}
    for bn, its in basename_items.items():
        if len(its) > 1:
            for a in its:
                for b in its:
                    if a is not b and a["generation"] != b["generation"]:
                        overlap_pairs[a["key"]] = b["key"]
    for it in items:
        if it["key"] in overlap_pairs:
            other = overlap_pairs[it["key"]]
            note = f"same mode also in {other.split('/')[0]} as "
            note += "/".join(other.split("/")[1:])
            it["notes"] = ((it["notes"] + "; ") if it["notes"] else "") + note

    doc = {
        "source": "github-stock",
        "source_url": SOURCE_URL,
        "fetched_at": date.today().isoformat(),
        "method": ("gh api per-repo git/trees recursive on default branch, "
                   "mode folders identified by entry file, plus branch/tag "
                   "survey; license/licensed files read via contents API"),
        "counts": _counts(items),
        "repos": repos_out,
        "items": items,
    }

    os.makedirs(os.path.dirname(OUT_JSON), exist_ok=True)
    with open(OUT_JSON, "w") as f:
        json.dump(doc, f, indent=2)
    print("wrote", OUT_JSON)
    print("items:", len(items), "repos:", len(repos_out))


def _notes(folder, gen, name, spdx, lic):
    n = []
    if gen == "v3-pygame":
        n.append("official EYESY OS v3.1 mode set")
    elif gen == "v2-pygame":
        n.append("v2.3 pygame mode set")
    elif gen == "v1-of-lua":
        n.append("early openFrameworks/Lua example")
    if spdx == "BSD-2-Clause":
        n.append("repo licensed BSD-2-Clause (LICENSE file)")
    if lic is None and name in ("EYESY_Modes_Pygame", "EYESY_oFLua_Examples"):
        n.append("NO LICENSE FILE - porting blocker")
    return "; ".join(n) if n else None


def _counts(items):
    by_gen = {}
    by_kind = {}
    by_lic = {}
    for it in items:
        g = it["generation"] or "unknown"
        k = it["kind"] or "unknown"
        l = it["license"] or "none"
        by_gen[g] = by_gen.get(g, 0) + 1
        by_kind[k] = by_kind.get(k, 0) + 1
        by_lic[l] = by_lic.get(l, 0) + 1
    return {"total": len(items), "by_generation": by_gen, "by_kind": by_kind,
            "by_license": by_lic}


if __name__ == "__main__":
    main()
