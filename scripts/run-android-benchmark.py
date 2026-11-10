#!/usr/bin/env python3
"""Explicit opt-in, serial-scoped Android benchmark runner (stdlib only)."""
import argparse
import csv
import json
import math
import shutil
import re
import subprocess
import time
from datetime import datetime, timezone
from pathlib import Path

PACKAGE = "com.roxhistory.benchmark"
MODES = ("T0", "T1", "T2", "T3")
PHASES = ("idle", "working_village")


def safe_id(value):
    if not re.fullmatch(r"[A-Za-z0-9_-]{1,80}", value):
        raise ValueError("run IDs must contain 1..80 letters, digits, underscores or hyphens")
    return value


def plan(args):
    if args.package != PACKAGE:
        raise ValueError("only the isolated benchmark package is allowed")
    if not args.serial or args.serial.startswith("-") or any(c.isspace() for c in args.serial):
        raise ValueError("an explicit, valid device serial is required")
    safe_id(args.run_id)
    if args.repeats < 1 or not all(math.isfinite(x) and 0.1 <= x <= 600 for x in (args.warmup_seconds, args.sample_seconds)):
        raise ValueError("invalid repeat count or phase duration")
    if not all(math.isfinite(x) for x in (args.cooldown_seconds, args.timeout, args.poll_seconds)) or args.cooldown_seconds < 0 or args.timeout <= 0 or args.poll_seconds <= 0:
        raise ValueError("invalid cooldown, polling interval or timeout")
    runs = []
    # Rotate a balanced Latin-square order; reverse is available for paired sessions.
    orders = ((0, 1, 3, 2), (1, 2, 0, 3), (2, 3, 1, 0), (3, 0, 2, 1))
    for repeat in range(args.repeats):
        order = orders[repeat % 4] if args.order == "balanced" else ((3, 2, 1, 0) if repeat % 2 == 0 else (0, 1, 2, 3))
        for index in order:
            mode = MODES[index]
            if mode not in args.modes:
                continue
            runs.append(dict(schema_version=1, mode=mode,
                             run_id=safe_id(f"{args.run_id}_r{repeat + 1}_{mode}"),
                             warmup_seconds=args.warmup_seconds,
                             sample_seconds=args.sample_seconds, repeat=repeat + 1,
                             sequence=len(runs) + 1))
    return runs


def validate_result(value, request):
    if not isinstance(value, dict):
        raise ValueError("result must be an object")
    for key, expected in (("schema_version", 1), ("status", "complete"),
                          ("run_id", request["run_id"]), ("mode", request["mode"])):
        if value.get(key) != expected:
            raise ValueError(f"result {key} mismatch: {value.get(key)!r}")
    phases = value.get("phases")
    if not isinstance(phases, list) or not all(isinstance(p, dict) for p in phases) or tuple(p.get("phase") for p in phases) != PHASES:
        raise ValueError("result phases differ from the prescribed scenario")
    if value.get("platform") != "Android" or value.get("headless") is not False:
        raise ValueError("result is not an Android graphics run")
    if not re.fullmatch(r"[0-9a-f]{40}", str(value.get("build_commit", ""))):
        raise ValueError("benchmark build commit is missing")
    return value


def comparison_notes(value, previous):
    notes = []
    if not previous:
        return notes
    start = value["phases"][0].get("native_start", {})
    reference = previous["phases"][0].get("native_start", {})
    current_temp = start.get("battery_temperature_c")
    reference_temp = reference.get("battery_temperature_c")
    if isinstance(current_temp, (int, float)) and isinstance(reference_temp, (int, float)):
        if abs(current_temp - reference_temp) >= 2:
            notes.append("Starting battery temperature differs from the session's first valid run by at least 2 C")
    for key in ("thermal_status", "battery_plugged", "system_brightness_setting"):
        if key in start and key in reference and start[key] != reference[key]:
            notes.append(f"Starting {key} differs from the session's first valid run")
    if value.get("viewport_px") != previous.get("viewport_px"):
        notes.append("Viewport dimensions differ from the session's first valid run")
    return notes


class Runner:
    def __init__(self, args, invoke=subprocess.run, sleep=time.sleep, clock=time.monotonic):
        self.args, self.invoke, self.sleep, self.clock = args, invoke, sleep, clock

    def adb(self, *parts, input=None, required=True):
        command = [self.args.adb, "-s", self.args.serial, *parts]
        result = self.invoke(command, input=input, stdout=subprocess.PIPE,
                             stderr=subprocess.PIPE, timeout=60, check=False)
        if required and result.returncode:
            raise RuntimeError(f"ADB failed ({result.returncode}): {' '.join(parts)}: "
                               + result.stderr.decode("utf-8", "replace")[:1000])
        return result

    def private(self, *parts, **kwargs):
        return self.adb("shell", "run-as", PACKAGE, *parts, **kwargs)

    def snapshot(self, directory, label):
        for name, command in (("display", ("dumpsys", "power")),
                              ("memory", ("dumpsys", "meminfo", PACKAGE)),
                              ("battery", ("dumpsys", "battery")),
                              ("thermal", ("dumpsys", "thermalservice"))):
            try:
                result = self.adb("shell", *command, required=False)
                (directory / f"{label}-{name}.txt").write_bytes(result.stdout)
                (directory / f"{label}-{name}-status.json").write_text(json.dumps(
                    dict(returncode=result.returncode,
                         stderr=result.stderr.decode("utf-8", "replace"))), encoding="utf-8")
            except (OSError, subprocess.TimeoutExpired) as exc:
                (directory / f"{label}-{name}-status.json").write_text(
                    json.dumps(dict(error=str(exc))), encoding="utf-8")

    def poll(self, request):
        deadline = self.clock() + self.args.timeout
        path = f"files/benchmark/{request['run_id']}/result.json"
        while self.clock() < deadline:
            result = self.private("cat", path, required=False)
            if result.returncode == 0 and result.stdout.strip():
                try:
                    value = json.loads(result.stdout)
                except (ValueError, UnicodeError):
                    # Writer may still be finishing its last write.
                    self.sleep(self.args.poll_seconds)
                    continue
                return value
            self.sleep(self.args.poll_seconds)
        raise TimeoutError(f"no completed result for {request['run_id']} within {self.args.timeout}s")

    def install(self):
        if not self.args.install:
            return
        if not self.args.aapt:
            raise ValueError("--install requires --aapt to verify APK package before installation")
        apk = Path(self.args.install).resolve(strict=True)
        result = self.invoke([self.args.aapt, "dump", "badging", str(apk)],
                             stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=60, check=False)
        match = re.search(rb"^package: name='([^']+)'", result.stdout, re.MULTILINE)
        if result.returncode or not match or match.group(1).decode() != PACKAGE:
            raise ValueError("APK identity verification failed; nothing installed")
        self.adb("install", "-r", str(apk))

    def execute(self):
        runs = plan(self.args)
        if not self.args.execute:
            return dict(executed=False, package=PACKAGE, serial=self.args.serial, runs=runs)
        root = Path(self.args.output) / self.args.run_id
        root.mkdir(parents=True, exist_ok=False)
        (root / "plan.json").write_text(json.dumps(runs, indent=2), encoding="utf-8")
        self.install()
        config = {}
        for prop in ("ro.product.manufacturer", "ro.product.model", "ro.build.version.release",
                     "ro.build.version.sdk", "ro.product.cpu.abi", "ro.build.fingerprint"):
            config[prop] = self.adb("shell", "getprop", prop).stdout.decode().strip()
        config["adb_version"] = self.adb("version").stdout.decode("utf-8", "replace")
        (root / "device.json").write_text(json.dumps(config, indent=2), encoding="utf-8")
        resolved = self.adb("shell", "cmd", "package", "resolve-activity", "--brief", PACKAGE)
        activity = resolved.stdout.decode().strip().splitlines()[-1]
        if not activity.startswith(PACKAGE + "/") or not re.fullmatch(r"[A-Za-z0-9_.$/]+", activity):
            raise RuntimeError("could not resolve benchmark launcher activity")
        observed = []
        completed = 0
        for index, request in enumerate(runs):
            directory = root / request["run_id"]
            directory.mkdir()
            pid = None
            try:
                self.adb("shell", "am", "force-stop", PACKAGE)
                if self.adb("shell", "pidof", PACKAGE, required=False).stdout.strip():
                    raise RuntimeError("benchmark process remained active after force-stop")
                self.private("mkdir", "-p", "files/benchmark")
                # Reject stale device artifacts rather than overwrite or erase them.
                existing = self.private("test", "-e", f"files/benchmark/{request['run_id']}", required=False)
                if existing.returncode == 0:
                    raise RuntimeError("device run ID already exists; choose a new --run-id")
                self.private("sh", "-c", "'cat > files/benchmark/request.json'",
                             input=json.dumps(request).encode())
                self.snapshot(directory, "before")
                start = self.adb("shell", "am", "start", "-W", "-n", activity)
                (directory / "launch.txt").write_bytes(start.stdout + start.stderr)
                if b"Error:" in start.stdout or b"Error:" in start.stderr:
                    raise RuntimeError("Android reported activity launch failure")
                pid_text = self.adb("shell", "pidof", PACKAGE, required=False).stdout.decode().strip()
                if re.fullmatch(r"[0-9]+", pid_text):
                    pid = pid_text
                value = self.poll(request)
                (directory / "result.json").write_text(json.dumps(value, indent=2), encoding="utf-8")
                for filename in ("frames.csv", "samples.jsonl", "diagnostics.jsonl"):
                    data = self.adb("exec-out", "run-as", PACKAGE, "cat",
                                    f"files/benchmark/{request['run_id']}/{filename}", required=False)
                    if data.returncode == 0:
                        (directory / filename).write_bytes(data.stdout)
                    elif filename != "diagnostics.jsonl" and value.get("status") == "complete":
                        raise RuntimeError(f"Missing required artifact: {filename}")
                validate_result(value, request)
                if observed and value["build_commit"] != observed[0]["build_commit"]:
                    raise ValueError("benchmark APK changed during the session")
                completed += 1
                value["comparison_eligible"] = request["sample_seconds"] >= 90
                value["comparison_notes"] = comparison_notes(value, observed[0] if observed else None)
                (directory / "result.json").write_text(json.dumps(value, indent=2), encoding="utf-8")
                if value["comparison_eligible"]:
                    observed.append(value)
            except (Exception, KeyboardInterrupt) as exc:
                (directory / "failure.json").write_text(json.dumps(dict(
                    run_id=request["run_id"], requested_mode=request["mode"], error=str(exc))), encoding="utf-8")
                raise
            finally:
                if pid:
                    try:
                        logs = self.adb("logcat", "-d", "-v", "threadtime", "--pid", pid, required=False)
                        (directory / "logcat.txt").write_bytes(logs.stdout)
                        (directory / "logcat-status.json").write_text(json.dumps(dict(
                            returncode=logs.returncode, stderr=logs.stderr.decode("utf-8", "replace"))), encoding="utf-8")
                    except (OSError, subprocess.TimeoutExpired) as exc:
                        (directory / "logcat-status.json").write_text(json.dumps(dict(error=str(exc))), encoding="utf-8")
                self.snapshot(directory, "after")
                self.adb("shell", "am", "force-stop", PACKAGE, required=False)
                write_aggregate(root, observed)
                shutil.make_archive(str(directory), "zip", directory)
                shutil.make_archive(str(root), "zip", root)
            if index + 1 < len(runs):
                self.sleep(self.args.cooldown_seconds)
        return dict(executed=True, output=str(root), completed=completed, comparison_runs=len(observed))


def write_aggregate(root, results):
    (root / "aggregate.json").write_text(json.dumps(results, indent=2), encoding="utf-8")
    with (root / "aggregate.csv").open("w", newline="", encoding="utf-8") as stream:
        writer = csv.writer(stream)
        writer.writerow(("run_id", "observed_mode", "phase_index", "phase_json"))
        for result in results:
            for index, phase in enumerate(result["phases"]):
                writer.writerow((result["run_id"], result["mode"], index, json.dumps(phase)))


def parser():
    result = argparse.ArgumentParser(description=__doc__)
    result.add_argument("--serial", required=True)
    result.add_argument("--execute", action="store_true", help="actually use ADB (otherwise zero device calls)")
    result.add_argument("--adb", default="adb")
    result.add_argument("--package", default=PACKAGE)
    result.add_argument("--install", metavar="APK")
    result.add_argument("--aapt", help="aapt executable required for --install")
    result.add_argument("--output", default="build/benchmark-results")
    result.add_argument("--run-id", default=datetime.now(timezone.utc).strftime("bench_%Y%m%dT%H%M%S_%fZ"))
    result.add_argument("--repeats", type=int, default=4)
    result.add_argument("--modes", nargs="+", choices=MODES, default=MODES)
    result.add_argument("--order", choices=("balanced", "reverse"), default="balanced")
    result.add_argument("--warmup-seconds", type=float, default=10)
    result.add_argument("--sample-seconds", type=float, default=120)
    result.add_argument("--cooldown-seconds", type=float, default=60)
    result.add_argument("--timeout", type=float, default=420)
    result.add_argument("--poll-seconds", type=float, default=2)
    return result


if __name__ == "__main__":
    try:
        print(json.dumps(Runner(parser().parse_args()).execute(), indent=2))
    except (ValueError, RuntimeError, TimeoutError, OSError, subprocess.SubprocessError) as error:
        raise SystemExit(str(error))
