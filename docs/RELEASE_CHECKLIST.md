# Release checklist — PHINANZ

**Release:** 1.0 | **Date:** ____ | **Owner:** Farhan

## Pre-build
- [ ] Open in Xcode, **build with zero errors** and review warnings
- [ ] All unit and UI tests pass (Cmd+U)
- [ ] Manual device checks from `docs/TEST_PLAN.md` done (Face ID, mic, camera, Gemini, export)
- [ ] Decide the iOS deployment target (project currently says 26.4)
- [ ] Bundle ID and signing team set (`Farhan.Phbank`)
- [ ] App Group `group.Farhan.Phbank` registered for both the app and `PhinanzWidgetExtension` (Signing & Capabilities → App Groups). Push/iCloud entitlements were removed because sync is not used.
- [ ] Translations reviewed by a native speaker (German, Persian); App Store metadata in all three languages
- [ ] App icon present in `Assets.xcassets/AppIcon` (a 1024 px icon is included; replace with final artwork if desired)
- [ ] Version (`MARKETING_VERSION`) and build number updated

## Privacy and App Store
- [ ] Privacy policy URL (required): states that data stays on device and what is sent to Google Gemini when AI import is used
- [ ] App Privacy "nutrition label": financial info and audio/photos are collected only if the user enables AI import, and are sent to a third party (Google)
- [ ] Permission texts reviewed (camera, microphone, Face ID, notifications)
- [ ] Siri phrases, widgets and the Control Center control checked in all three languages
- [ ] Export compliance: uses only standard OS encryption (HTTPS, Keychain)
- [ ] Screenshots (6.9" and 6.5" iPhone), description, keywords (German + English)
- [ ] Age rating questionnaire, support URL, contact e-mail

## TestFlight
- [ ] Archive, validate, upload
- [ ] Internal testers: fresh install, create entries, kill and relaunch, data still there
- [ ] Update install over previous build keeps data (SwiftData migration)
- [ ] A backup made with the previous build restores in the new one

## Rollback triggers
- Crash on launch or a store that cannot be opened
- Entries missing after update
- Lock screen that cannot be passed with the correct credentials
- Any request that sends data to Google while AI import is switched off

## Post-release
- [ ] Watch crash reports and TestFlight feedback for 48 h
- [ ] Update changelog and tag the release in git
