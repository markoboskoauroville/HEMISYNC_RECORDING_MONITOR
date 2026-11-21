#!/bin/sh
# GUARD "one title only" (MANTRA_MANIFEST modules/one-title-only.md): the app draws its own title, the system title stays hidden.
cd "$(dirname "$0")/app" || exit 1
fail=0
grep -q "titleVisibility = .hidden" App.swift || { echo "FAIL titleVisibility = .hidden missing"; fail=1; }
grep -q "func enforceOneTitle" App.swift || { echo "FAIL enforceOneTitle() missing"; fail=1; }
for h in windowDidBecomeKey windowDidResignKey windowDidResize windowDidEnterFullScreen windowDidExitFullScreen; do
  grep -q "func $h" App.swift || { echo "FAIL $h missing"; fail=1; }
done
grep -q "titleVisibility = .visible" *.swift && { echo "FAIL titleVisibility = .visible found"; fail=1; }
[ $fail = 0 ] && echo "one title only: OK"
exit $fail
