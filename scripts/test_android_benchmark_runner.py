"""Host-only unit tests. Never executes ADB or touches a device."""
import importlib.util
import json
import subprocess
import tempfile
import unittest
from pathlib import Path

SPEC = importlib.util.spec_from_file_location("benchmark_runner", Path(__file__).with_name("run-android-benchmark.py"))
runner = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(runner)


def options(*extra):
    return runner.parser().parse_args(["--serial", "FAKE_SERIAL", "--run-id", "unit", *extra])


def completed(request):
    return dict(request, status="complete", platform="Android", headless=False,
                build_commit="a" * 40, phases=[{"phase": phase} for phase in runner.PHASES])


class RunnerTests(unittest.TestCase):
    def test_dry_run_has_zero_external_calls_even_with_install(self):
        calls = []
        result = runner.Runner(options("--install", "does-not-exist.apk"),
                               invoke=lambda *a, **kw: calls.append(a)).execute()
        self.assertFalse(result["executed"])
        self.assertEqual(calls, [])
        self.assertEqual(len(result["runs"]), 16)

    def test_balanced_order_and_independent_ids(self):
        runs = runner.plan(options())
        self.assertEqual(len({r["run_id"] for r in runs}), 16)
        for position in range(4):
            self.assertEqual({runs[i * 4 + position]["mode"] for i in range(4)}, set(runner.MODES))

    def test_rejects_unsafe_ids_packages_and_serials(self):
        for flag, value in (("--run-id", "../bad"), ("--run-id", "x;echo"),
                            ("--package", "com.roxhistory.demo"), ("--serial", "a b")):
            with self.subTest(flag=flag, value=value), self.assertRaises(ValueError):
                runner.plan(options(flag, value))

    def test_result_identity_and_failure_are_strict(self):
        request = runner.plan(options())[0]
        complete = completed(request)
        self.assertEqual(runner.validate_result(complete, request), complete)
        for key, wrong in (("run_id", "old"), ("mode", "T3"), ("status", "failed"),
                           ("schema_version", 2), ("phases", [])):
            with self.subTest(key=key), self.assertRaises(ValueError):
                runner.validate_result(dict(complete, **{key: wrong}), request)

    def test_poll_timeout_and_adb_failure(self):
        clock = [0]
        def sleep(seconds):
            clock[0] += seconds
        def missing(command, **kwargs):
            return subprocess.CompletedProcess(command, 1, b"", b"No such file")
        test = runner.Runner(options("--timeout", "3", "--poll-seconds", "1"),
                             invoke=missing, sleep=sleep, clock=lambda: clock[0])
        with self.assertRaises(TimeoutError):
            test.poll(runner.plan(test.args)[0])
        with self.assertRaises(RuntimeError):
            test.adb("shell", "false")

    def test_wrong_apk_rejected_before_adb(self):
        calls = []
        def fake(command, **kwargs):
            calls.append(command)
            return subprocess.CompletedProcess(command, 0, b"package: name='com.roxhistory.demo'", b"")
        with tempfile.TemporaryDirectory() as temp:
            apk = Path(temp) / "fake.apk"
            apk.write_bytes(b"fake")
            instance = runner.Runner(options("--install", str(apk), "--aapt", "fake-aapt"), invoke=fake)
            with self.assertRaises(ValueError):
                instance.install()
        self.assertEqual(len(calls), 1)
        self.assertEqual(calls[0][0], "fake-aapt")

    def test_execute_uses_independent_processes_and_captures_actual_results(self):
        calls, requests = [], []
        def fake(command, **kwargs):
            calls.append(command)
            self.assertEqual(command[:3], ["adb", "-s", "FAKE_SERIAL"])
            tail, output, code = command[3:], b"", 0
            if "test" in tail:
                code = 1
            elif "resolve-activity" in tail:
                output = (runner.PACKAGE + "/org.godotengine.godot.GodotApp\n").encode()
            elif "pidof" in tail:
                output = b"12345\n" if len(requests) > sum("start" in call for call in calls) - 1 and "start" in calls[-2] else b""
            elif kwargs.get("input"):
                requests.append(json.loads(kwargs["input"]))
            elif tail[-1].endswith("/result.json"):
                output = json.dumps(completed(requests[-1])).encode()
            return subprocess.CompletedProcess(command, code, output, b"")
        with tempfile.TemporaryDirectory() as temp:
            args = options("--execute", "--repeats", "1", "--output", temp, "--cooldown-seconds", "0")
            result = runner.Runner(args, invoke=fake, sleep=lambda _: None).execute()
            self.assertEqual(result["completed"], 4)
            aggregate = json.loads((Path(temp) / "unit/aggregate.json").read_text())
            self.assertEqual([r["mode"] for r in aggregate], [r["mode"] for r in requests])
            self.assertTrue((Path(temp) / "unit/aggregate.csv").is_file())
            self.assertTrue((Path(temp) / "unit.zip").is_file())
            self.assertTrue((Path(temp) / "unit/unit_r1_T0.zip").is_file())
        self.assertEqual(sum("start" in c for c in calls), 4)
        self.assertEqual(sum("force-stop" in c for c in calls), 8)
        self.assertTrue(all("clear" not in c for c in calls))
        self.assertTrue(all("--pid" in c for c in calls if "logcat" in c))

    def test_failed_run_is_recorded_and_stopped(self):
        calls = []
        def fake(command, **kwargs):
            calls.append(command)
            output, code = b"", 0
            if "resolve-activity" in command:
                output = (runner.PACKAGE + "/Main").encode()
            elif "test" in command:
                code = 1
            elif command[-1].endswith("/result.json"):
                output = json.dumps(dict(schema_version=1, status="failed")).encode()
            return subprocess.CompletedProcess(command, code, output, b"")
        with tempfile.TemporaryDirectory() as temp:
            args = options("--execute", "--repeats", "1", "--output", temp)
            with self.assertRaises(ValueError):
                runner.Runner(args, invoke=fake).execute()
            self.assertTrue((Path(temp) / "unit/unit_r1_T0/failure.json").is_file())
            self.assertEqual(json.loads((Path(temp) / "unit/aggregate.json").read_text()), [])
        self.assertIn("force-stop", calls[-1])


if __name__ == "__main__":
    unittest.main()
