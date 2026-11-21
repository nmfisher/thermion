import copy
import importlib.util
from pathlib import Path
import unittest


spec = importlib.util.spec_from_file_location(
    "retry_release_runner", Path(__file__).with_name("retry-release-runner.py")
)
retry = importlib.util.module_from_spec(spec)
spec.loader.exec_module(retry)

REPO = "nmfisher/thermion"
BASE = f"repos/{REPO}"
RUN = f"{BASE}/actions/runs/42"


class RetryTests(unittest.TestCase):
    def setUp(self):
        self.run = dict(status="completed", conclusion="failure", run_attempt=1,
                        event="push", path=".github/workflows/publish-pub-dev.yml",
                        head_repository={"full_name": REPO}, head_branch="v0.6.1")
        self.job = dict(id=7, name="Flutter macOS", status="completed",
                        conclusion="cancelled", runner_name="", runner_id=0,
                        steps=[], check_run_url=f"https://api.github.com/{BASE}/check-runs/7")
        self.annotations = [dict(annotation_level="notice", message="Capacity constrained"),
                            dict(annotation_level="failure", message=retry.ACQUISITION_ERROR)]
        self.calls = []
        self.delays = []
        self.after_wait = None

    def api(self, path, method="GET"):
        self.calls.append((method, path))
        if method == "POST":
            return None
        if path == RUN:
            return copy.deepcopy(self.after_wait if self.delays and self.after_wait else self.run)
        if "/jobs?" in path:
            return {"jobs": [self.job]}
        if "/annotations?" in path:
            return self.annotations
        self.fail(f"Unexpected API request: {path}")

    def invoke(self):
        return retry.retry_publish(REPO, 42, self.api, self.delays.append, lambda _: None)

    def posts(self):
        return [path for method, path in self.calls if method == "POST"]

    def test_retries_unacquired_cancelled_job_and_dependents(self):
        self.assertTrue(self.invoke())
        self.assertEqual(self.delays, [120])
        self.assertEqual(self.posts(), [f"{RUN}/rerun-failed-jobs"])
        self.assertIn(("GET", f"{RUN}/attempts/1/jobs?per_page=100&page=1"), self.calls)

    def test_backoff_and_attempt_limit(self):
        for attempt, delay in enumerate([120, 300, 600, 1200], 1):
            with self.subTest(attempt=attempt):
                self.setUp()
                self.run["run_attempt"] = attempt
                self.assertTrue(self.invoke())
                self.assertEqual(self.delays, [delay])
        self.setUp()
        self.run["run_attempt"] = 5
        self.assertFalse(self.invoke())
        self.assertEqual(self.posts(), [])
        self.assertEqual(self.delays, [])

    def test_actual_test_failure_is_not_retried(self):
        self.job.update(conclusion="failure", runner_name="GitHub Actions 1", runner_id=1,
                        steps=[{"name": "Run tests", "conclusion": "failure"}])
        self.assertFalse(self.invoke())
        self.assertEqual(self.posts(), [])
        self.assertEqual(self.delays, [])

    def test_capacity_notice_without_acquisition_error_is_not_enough(self):
        self.annotations = self.annotations[:1]
        self.assertFalse(self.invoke())
        self.assertEqual(self.posts(), [])

    def test_unrelated_failure_annotation_stops_retry(self):
        self.annotations.append(dict(annotation_level="failure", message="Invalid workflow"))
        self.assertFalse(self.invoke())
        self.assertEqual(self.posts(), [])

    def test_job_that_ran_steps_is_not_retried(self):
        self.job["steps"] = [{"name": "Set up job", "conclusion": "success"}]
        self.assertFalse(self.invoke())
        self.assertEqual(self.posts(), [])

    def test_manual_cancellation_is_respected(self):
        self.run["conclusion"] = "cancelled"
        self.assertFalse(self.invoke())
        self.assertEqual(self.posts(), [])

    def test_non_release_runs_are_not_retried(self):
        for key, value in [("event", "pull_request"), ("event", "workflow_dispatch"),
                           ("path", ".github/workflows/deploy.yml"), ("head_branch", "develop"),
                           ("head_repository", {"full_name": "someone/thermion"})]:
            with self.subTest(key=key, value=value):
                self.setUp()
                self.run[key] = value
                self.assertFalse(self.invoke())
                self.assertEqual(self.posts(), [])

    def test_manual_retry_during_backoff_is_respected(self):
        self.after_wait = dict(self.run, run_attempt=2, status="in_progress", conclusion=None)
        self.assertTrue(self.invoke())
        self.assertEqual(self.posts(), [])

    def test_workflow_path_with_ref_suffix(self):
        self.run["path"] += "@refs/tags/v0.6.1"
        self.assertTrue(self.invoke())

    def test_run_already_retried_is_only_observed(self):
        self.run.update(status="in_progress", conclusion=None)
        self.assertTrue(self.invoke())
        self.assertEqual(self.posts(), [])
        self.assertEqual(self.delays, [])

    def test_mixed_test_and_capacity_failures_do_not_retry(self):
        original = self.api
        bad = dict(self.job, id=8, conclusion="failure", name="Dart tests", steps=[{}])
        def api(path, method="GET"):
            if "/jobs?" in path:
                return {"jobs": [self.job, bad]}
            return original(path, method)
        self.api = api
        self.assertFalse(self.invoke())
        self.assertEqual(self.posts(), [])

    def test_annotation_pagination_includes_later_failure(self):
        original = self.api
        def api(path, method="GET"):
            if "/annotations?" in path:
                if "page=2" in path:
                    return [dict(annotation_level="failure", message="Another failure")]
                return self.annotations * 50
            return original(path, method)
        self.api = api
        self.assertFalse(self.invoke())
        self.assertEqual(self.posts(), [])


if __name__ == "__main__":
    unittest.main()
