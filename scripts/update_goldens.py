"""Publish selected, reviewed render captures from a GitHub Actions run."""

import argparse
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys
import tempfile
import zipfile


WORKFLOW = Path(".github/workflows/run-dart-tests.yml")
R2_PREFIX = "thermion/render-baselines"
# Match the three adjacent fields in each rendering matrix entry. Preserve
# the surrounding YAML, comments and expressions when changing the pins.
ROW = re.compile(
    r"^(?P<fields> +artifact: (?P<artifact>[^\n]+)\n"
    r" +baseline_asset: (?P<asset>[\w.-]+\.zip)\n +baseline_sha256: )(?P<digest>[a-f0-9]{64})$",
    re.MULTILINE,
)


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def json_bytes(data):
    return (json.dumps(data, indent=2, sort_keys=True) + "\n").encode()


def fetch(url):
    return subprocess.check_output(["curl", "-fsSL", "--retry", "3", url])


def reviewed_png(value):
    path = PurePosixPath(value)
    if (path.is_absolute() or ".." in path.parts or "\\" in value
            or str(path) != value or path.suffix != ".png"):
        raise argparse.ArgumentTypeError(f"expected a relative PNG path, got {value!r}")
    return value


def update_archive(base_bytes, candidate_bytes, approved):
    """Copy only approved additions/replacements into the pinned baseline."""
    changes = {}
    found = set()
    with zipfile.ZipFile(io.BytesIO(base_bytes)) as base, zipfile.ZipFile(io.BytesIO(candidate_bytes)) as candidate:
        existing = set(base.namelist())
        captured = set(candidate.namelist())
        for name in approved:
            if name not in captured:
                if name in existing:
                    raise ValueError(f"CI artifact is missing existing approved image {name}")
                continue  # Some test suites only run on a subset of platforms.
            found.add(name)
            data = candidate.read(name)
            if not data.startswith(b"\x89PNG\r\n\x1a\n"):
                raise ValueError(f"CI artifact contains an invalid PNG at {name}")
            if name not in existing or data != base.read(name):
                changes[name] = data
        if not changes:
            return base_bytes, found, []
        output = io.BytesIO()
        with zipfile.ZipFile(output, "w") as new:
            for info in base.infolist():
                data = changes.get(info.filename)
                new.writestr(info, base.read(info) if data is None else data)
            for name in sorted(changes.keys() - existing):
                # Fixed ZIP timestamps keep retries byte-identical.
                new.writestr(zipfile.ZipInfo(name), changes[name], compress_type=zipfile.ZIP_DEFLATED)
    return output.getvalue(), found, sorted(changes)


def refresh(args, directory):
    workflow = WORKFLOW.read_text()
    rows = list(ROW.finditer(workflow))
    if not rows or len(rows) != workflow.count("baseline_asset:"):
        raise ValueError(f"could not read the render baseline matrix in {WORKFLOW}")
    base_url = re.search(r"^ +BASELINE_BASE_URL: (\S+)$", workflow, re.M)[1]
    base_id = re.search(r"^ +BASELINE_ID: (\S+)$", workflow, re.M)[1]

    repo = subprocess.check_output(
        ["gh", "repo", "view", "--json", "nameWithOwner", "-q", ".nameWithOwner"], text=True,
    ).strip()
    run_path = f"repos/{repo}/actions/runs/{args.run}"
    run = json.loads(subprocess.check_output(["gh", "api", run_path]))
    artifacts = subprocess.check_output(
        ["gh", "api", run_path + "/artifacts?per_page=100", "--paginate", "--jq",
         ".artifacts[] | select(.expired == false) | [.name, .id] | @tsv"], text=True,
    )
    artifact_ids = dict(line.split("\t") for line in artifacts.splitlines())
    approved = sorted(set(args.png))
    found = set()
    assets = {}
    for row in rows:
        artifact, asset, digest = row["artifact"], row["asset"], row["digest"]
        base = fetch(f"{base_url}/{base_id}/{asset}")
        if sha256(base) != digest:
            raise ValueError(f"{base_id}/{asset} does not match its workflow SHA-256 pin {digest}")
        if artifact not in artifact_ids:
            raise ValueError(f"run {args.run} has no available artifact named {artifact!r}")
        artifact_id = artifact_ids[artifact]
        candidate = subprocess.check_output(["gh", "api", f"repos/{repo}/actions/artifacts/{artifact_id}/zip"])
        archive, present, changed = update_archive(base, candidate, approved)
        found.update(present)
        (directory / asset).write_bytes(archive)
        assets[asset] = {"artifact": artifact, "artifact_id": int(artifact_id), "base_sha256": digest,
                        "sha256": sha256(archive), "updated_paths": changed}
        print(f"{artifact}: {len(changed)} changed", flush=True)
    if missing := set(approved) - found:
        raise ValueError(f"approved paths absent from every CI artifact: {', '.join(sorted(missing))}")
    if not any(a["updated_paths"] for a in assets.values()):
        print("All approved images already match the pinned baselines.")
        return

    review = {"base_baseline_id": base_id, "source_run": run["html_url"], "source_commit": run["head_sha"],
              "approved_paths": approved, "assets": assets}
    if args.review_note:
        review["review_note"] = args.review_note
    if args.review_sheet:
        sheet = args.review_sheet.read_bytes()
        (directory / "review.png").write_bytes(sheet)
        review["review_sheet"] = {"file": "review.png", "sha256": sha256(sheet)}

    # The content-derived prefix lets an interrupted publication be retried
    # without overwriting a different review of the same run.
    version = f"run-{args.run}-{sha256(json_bytes(review))[:20]}"
    review["baseline_id"] = version
    (directory / "baseline-review.json").write_bytes(json_bytes(review))
    (directory / "SHA256SUMS").write_text("".join(
        f"{assets[name]['sha256']}  {name}\n" for name in sorted(assets)
    ))
    print(f"{base_id} -> {version}", flush=True)
    if not args.publish:
        print("Dry run complete. Pass --publish to upload and update the workflow.")
        return

    for file in sorted(directory.iterdir()):
        print(f"Publishing and verifying {file.name}", flush=True)
        subprocess.run(["wrangler", "r2", "object", "put", f"{R2_PREFIX}/{version}/{file.name}",
                        "--remote", "--file", str(file)], check=True)
        if fetch(f"{base_url}/{version}/{file.name}") != file.read_bytes():
            raise ValueError(f"published bytes differ for {file.name}")

    updated = ROW.sub(lambda m: m["fields"] + assets[m["asset"]]["sha256"], workflow)
    updated = updated.replace(f"BASELINE_ID: {base_id}\n", f"BASELINE_ID: {version}\n")
    if WORKFLOW.read_text() != workflow:
        raise ValueError(f"{WORKFLOW} changed during publication; rerun against the current pins")
    with tempfile.NamedTemporaryFile(mode="w", dir=WORKFLOW.parent, delete=False) as temp:
        temp.write(updated)
    os.chmod(temp.name, WORKFLOW.stat().st_mode)
    os.replace(temp.name, WORKFLOW)
    print(f"Updated {WORKFLOW}. Review record: {base_url}/{version}/baseline-review.json")


def main():
    parser = argparse.ArgumentParser(description=__doc__, prog="scripts/update_goldens.sh")
    parser.add_argument("--run", type=int, required=True, help="GitHub Actions run containing the candidate images")
    parser.add_argument("--publish", action="store_true", help="upload to R2, verify the public objects and advance the pins")
    parser.add_argument("--review-note", help="record why these images were accepted")
    parser.add_argument("--review-sheet", type=Path, help="include a PNG contact sheet in the review record")
    parser.add_argument("png", nargs="+", type=reviewed_png, help="exact approved PNG paths relative to test output")
    args = parser.parse_args()
    if args.review_sheet:
        args.review_sheet = args.review_sheet.resolve()
    os.chdir(subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True).strip())
    with tempfile.TemporaryDirectory(prefix="thermion-goldens-") as temp:
        refresh(args, Path(temp))


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError, zipfile.BadZipFile) as error:
        sys.exit(str(error))
