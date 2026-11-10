# Android performance benchmark

The benchmark is built separately from the normal game. Connect or authorize the Galaxy Fold only after 20:00 KST with the owner present. Host-only checks do not call ADB.

## Build and installation

- Package `com.roxhistory.benchmark`, app label **RoxHistory Benchmark**, version 0.2.91. It uses separate app storage from `com.roxhistory.demo`. Each controlled run also has its own save folder.
- Use the signed debuggable APK in `D:/workspace/roxhistory/build/benchmark/Roxhistory_0.2.91.apk`. The runner uses Android `run-as` to communicate with it and refuses to install a different package. Normal game installation and saves are outside the protocol.
- The benchmark build includes the original T0–T3 renderer modes and 2D atlases so ADB-controlled runs work offline. Ordinary patch and manual trial loading stay available outside an ADB-controlled run. A controlled run deliberately skips both patch streams to pin the source and assets.

## Host-only checks

```powershell
python scripts/test_android_benchmark_runner.py
python scripts/run-android-benchmark.py --serial DEVICE_SERIAL --run-id preview
```

The preview makes zero subprocess calls and writes no output files. Python 3.9+ is required.

## After the Galaxy Fold is authorized

```powershell
. D:/devtools/roxhistory-env.ps1
python scripts/run-android-benchmark.py --serial DEVICE_SERIAL --execute --install D:/workspace/roxhistory/build/benchmark/Roxhistory_0.2.91.apk --aapt D:/devtools/android-sdk/build-tools/35.0.0/aapt.exe
```

Omit the install arguments when the benchmark app is already installed. Use the intended serial explicitly. The runner force-stops only the benchmark package, checks that it stopped, writes a new request, launches it, and verifies each result's mode, run ID, source build and scene phases.

Default is four balanced repetitions of T0–T3. Each run has 10 seconds of warmup per scene, 120 seconds in an idle village and 120 seconds in a working village. The second scene uses one farmer, three woodcutters, three stone gatherers, fixed farm and depots, and a repeating scripted camera route at zoom 0.8. The game uses normal live simulation. Small timing differences between machines and render modes can change the exact work moment reached. A comparison run requires that farming, gathering and hauling were observed. The default session takes about 85 minutes plus startup and transfer.

For a setup check use `--modes T0 --repeats 1 --sample-seconds 2 --cooldown-seconds 0`. A short setup check stays out of the comparison aggregate. For a retry use a fresh `--run-id` and `--modes T2` or repeat the complete matrix. Use `--order reverse` for alternating reverse/forward order. Increase `--timeout` if longer phases exceed the default 420-second wait.

Keep brightness, display posture, refresh rate, charger and background workload fixed. Turn off auto brightness for controlled comparisons if practical. The app requests that the screen stay on and invalidates interrupted runs. Reports include power snapshots and flag changes in starting charge, brightness, thermal status, viewport and battery temperature where available. Use separate sessions for USB and wireless ADB without charging.

## Outputs

Host default is `build/benchmark-results/<session>/`. Each run contains raw frames, native samples, scoped logcat, device snapshots, and result or failure JSON. The host exports a ZIP per run and a session ZIP next to the session folder. A failed or interrupted run stops the session and preserves prior results and partial artifacts. Use a fresh session ID to retry.

Whole-run p95 is computed from the combined raw frame intervals. Long frames exceed 33.333 ms. CPU is Android process CPU time in milliseconds and is also reported as a percentage of one logical core, which can exceed 100%. Native memory is process PSS in KiB. Battery temperature is in Celsius. Android thermal status is the platform status code. Unsupported fields are marked explicitly. Device metadata may identify the device model and OS build.
