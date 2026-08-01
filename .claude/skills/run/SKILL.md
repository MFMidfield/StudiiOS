---
name: run
description: Use whenever asked to run, build, launch, test, verify, or screenshot the PrototypeApp iOS app, or before claiming a UI/code change works. Overrides the default "build and test in the Simulator" behavior for this project.
version: 1.0.0
---

# Do not test this app in the Simulator

For this project, testing is entirely the user's responsibility. Do **not**:

- Run `xcodebuild` to build the app
- Boot, install into, or launch anything in the iOS Simulator
- Take or read Simulator screenshots
- Seed `UserDefaults`/`AppStorage` or fake profile data to "verify" a screen

Your job stops at writing and editing the Swift/SwiftUI code. The user builds
and runs the app themselves (in Xcode, on a device, or in the Simulator) and
will report back if something is broken.

## What to do instead

- Make the code change.
- If you want a sanity check that the code is well-formed, that's fine to skip
  entirely — the user does not need a compile check performed on their behalf.
- When reporting the result, say what changed and that it's ready for the user
  to test — do not say "verified", "tested", or "confirmed working" for
  anything you did not actually see run, since you didn't run it.

## If the user explicitly asks you to run/build/test

Then it's fine to do so — this override is about *not doing it unprompted*,
not a hard ban. If they ask directly ("build this for me", "launch the
simulator"), go ahead.
