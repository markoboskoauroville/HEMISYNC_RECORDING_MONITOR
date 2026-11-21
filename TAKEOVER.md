# TAKEOVER: Hemi-Sync Recording Monitor (Mantra)

Native Mac Swift app (v1, 21.11.2026), one dashboard window for the long Hemi-Sync recording job.
Reads `~/Music/HemiSync/progress.json` every 2 s (written atomically by the recording worker). Env `HEMISYNC_PROGRESS=<path>` overrides the path (tests only; never write a fake file into ~/Music/HemiSync).
Shows phase and state, Clips and Albums bars, current album and track with progress, Time left, Finishes about, elapsed, item list with marks, "Last update N s ago" (amber and "Recorder silent?" after 2 min), one button "Open folder". Window X quits the app. No ON/OFF.

- Bundle id `community.auroville.hemisyncrecordingmonitor`, installed as `/Applications/Hemi-Sync Recording Monitor (Mantra).app`, signed "Mantra Apps".
- Compiled only by GitHub Actions (`.github/workflows/build.yml`, copy of MANTRA_MANIFEST/workflows/mac-swift.yml); release vN Latest, asset app.zip. Never build on the Mac.
- Install: `gh release download --repo markoboskoauroville/HEMISYNC_RECORDING_MONITOR --pattern app.zip -D <dir>`, unzip into /Applications, `codesign --force -s "Mantra Apps"`.
- Updater: app/Updater.swift (kit mac-updater), asks at start. Versions are whole numbers: bump `let VERSION` in app/App.swift.
- Guard: `check_one_title.sh` (one title only), run by build.sh.
- Coded by MAI Code 2 (review pass) on a first draft by Claude Code; schema in app/App.swift (`loadProgress`).
