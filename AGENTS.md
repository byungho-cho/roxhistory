# RoxHistory development and releases

- Preserve existing local work, Git commit history, branches, tags, and release records.
- Every distribution must include Android and Windows from the same source commit and version. Do not publish just one platform.
- The only local distribution directory is the repository's `build/` directory (`D:\workspace\roxhistory\build` on MY-NUROX). Do not place distribution copies in other folders.
- Name the files exactly `Roxhistory_<version>.apk` and `Roxhistory_<version>.exe`. Do not append dates, machine names, or other suffixes.
- Build with `scripts/build-release.ps1`; publish both files with `scripts/publish-release.ps1`.
- After both new files have uploaded and their hashes have been verified, keep only that latest pair of APK/EXE assets on GitHub Releases. Delete older APK/EXE attachments, not release records, tags, source archives, or commit history. Never remove the previous usable pair before the new pair is available.
- Reuse the existing signing key. Never generate, replace, print, or commit signing keys/passwords. Keep signing material outside the repository. Do not treat a newly generated debug key as the previous distribution key.
- Report build success separately from gameplay verification. Do not describe known failing legacy regression tests as passing.
- Do not modify game functionality as part of environment or release maintenance.
