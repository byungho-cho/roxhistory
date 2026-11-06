#!/usr/bin/env bash
# Linux/macOS cloud check; no APK export, credentials, or signing operations.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT_BIN="${GODOT_BIN:-godot}"
CHECK_LOG_DIR="${CHECK_LOG_DIR:-$PWD/game/reports/village-checks}"
mkdir -p "$CHECK_LOG_DIR"
node scripts/verify-demo-assets.mjs
python3 scripts/verify_demo_audio.py
"$GODOT_BIN" --headless --path game --editor --import --quit > "$CHECK_LOG_DIR/import.log" 2>&1
! grep -E 'SCRIPT ERROR:|ERROR:' "$CHECK_LOG_DIR/import.log"
for suite in state_tests village_rules_tests hq_world_tests hq_world_runtime_tests legacy_world_tests resident_jobs_tests resident_jobs_runtime_tests first_refactor_tests isometric_village_tests ui_review_tests village_integration_tests; do
  "$GODOT_BIN" --headless --fixed-fps 60 --audio-driver Dummy --path game --resolution 1280x720 --script "res://tests/$suite.gd" -- --test-ui > "$CHECK_LOG_DIR/$suite.log" 2>&1
  ! grep -E 'SCRIPT ERROR:|ERROR:' "$CHECK_LOG_DIR/$suite.log"
  printf '%s: PASS\n' "$suite"
done
for seed in 61106 61107 61108; do
  "$GODOT_BIN" --headless --fixed-fps 60 --audio-driver Dummy --path game --script res://tests/resident_jobs_concurrency_tests.gd -- "--seed=$seed" > "$CHECK_LOG_DIR/concurrency-$seed.log" 2>&1
  ! grep -E 'SCRIPT ERROR:|ERROR:' "$CHECK_LOG_DIR/concurrency-$seed.log"
  printf 'resident_jobs_concurrency_tests seed%s: PASS\n' "$seed"
done
printf 'Headless checks complete. Pixel rendering, device input/performance, and APK signing remain separate checks.\n'
