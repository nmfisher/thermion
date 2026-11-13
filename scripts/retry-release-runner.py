#!/usr/bin/env python3
"""Retry a failed publish run only when hosted runners never acquired its jobs."""

import argparse
import json
import re
import subprocess
import time


# Five total attempts, including manual reruns; at most 37 minutes of backoff.
BACKOFF_SECONDS = (120, 300, 600, 1200)
ACQUISITION_ERROR = (
    "The job was not acquired by Runner of type hosted even after multiple attempts"
)


def gh_api(path, method="GET"):
    output = subprocess.check_output(
        ["gh", "api", "--method", method, path], text=True
    )
    return json.loads(output) if output.strip() else None


def pages(api, path, key=None):
    result = []
    page = 1
    while True:
        data = api(f"{path}?per_page=100&page={page}")
        items = data[key] if key else data
        result.extend(items)
        if len(items) < 100:
            return result
        page += 1


def unacquired_runner(job, annotations):
    failures = [a for a in annotations if a["annotation_level"] == "failure"]
    return (
        job["conclusion"] in ("failure", "cancelled")
        and not job.get("runner_name")
        and not job.get("runner_id")
        and not job.get("steps")
        and bool(failures)
        and all(a["message"].strip() == ACQUISITION_ERROR for a in failures)
    )


def retry_publish(repository, run_id, api=gh_api, sleep=time.sleep, log=print):
    """Return True if the watcher should keep following this run, else False."""
    base = f"repos/{repository}"
    run_path = f"{base}/actions/runs/{run_id}"
    run = api(run_path)
    # A manual retry may already have started since the watcher's last poll.
    if run["status"] != "completed" or run["conclusion"] == "success":
        log("Publish state changed; continue watching.")
        return True
    attempt = run["run_attempt"]
    if not (
        run["conclusion"] == "failure"
        and run["event"] == "push"
        and run["path"].split("@", 1)[0] == ".github/workflows/publish-pub-dev.yml"
        and run["head_repository"]["full_name"] == repository
        and re.fullmatch(r"v\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?", run["head_branch"])
        and 1 <= attempt <= len(BACKOFF_SECONDS)
    ):
        log("Not an eligible publish failure, or the five-attempt limit was reached.")
        return False

    jobs = pages(api, f"{run_path}/attempts/{attempt}/jobs", "jobs")
    failed = [j for j in jobs if j["conclusion"] not in ("success", "skipped")]
    if not failed:
        log("No failed jobs found; leaving the failure for review.")
        return False
    for job in failed:
        match = re.search(r"/check-runs/(\d+)$", job.get("check_run_url", ""))
        if not match or job["status"] != "completed":
            return False
        annotations = pages(api, f"{base}/check-runs/{match[1]}/annotations")
        if not unacquired_runner(job, annotations):
            log(f"{job['name']} is not an unacquired hosted runner; no automatic retry.")
            return False

    delay = BACKOFF_SECONDS[attempt - 1]
    log(f"Hosted runner capacity failure. Retry attempt {attempt + 1}/5 in {delay // 60}m.")
    sleep(delay)
    current = api(run_path)
    if (
        current["run_attempt"] != attempt
        or current["status"] != "completed"
        or current["conclusion"] != "failure"
    ):
        log("Run changed during backoff; leave the newer state alone.")
        return True
    api(f"{run_path}/rerun-failed-jobs", method="POST")
    log("Requested rerun of failed jobs and their dependents; approvals remain required.")
    return True


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository", required=True)
    parser.add_argument("--run-id", required=True, type=int)
    args = parser.parse_args()
    raise SystemExit(0 if retry_publish(args.repository, args.run_id) else 1)
