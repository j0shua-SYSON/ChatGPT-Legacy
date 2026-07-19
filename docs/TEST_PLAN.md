# Test plan

ChatGPT Legacy uses a layered release gate because its primary device predates
the simulator hardware supported by current Xcode releases.

## Automated gate

Every `main` push and version tag runs on a clean GitHub-hosted macOS runner:

1. Generate the Xcode project and lint the property list and asset catalogs.
2. Run Xcode static analysis against the selected simulator SDK.
3. Execute unit tests for OAuth/JWT migration, SSE framing and server errors,
   multimodal Responses payloads, atomic history persistence and migration,
   image downsampling, and fixed-size SwiftUI rendering.
4. Render and retain 414x736 portrait and 736x414 landscape iPhone 6s Plus
   screenshots plus a 320x568 compact legacy-iPhone screenshot inside XCTest.
5. Run deterministic XCUITests covering signed-out trust disclosure, the OAuth
   device-code state, prompt insertion, streaming/stop state, history search,
   rename, stop-then-immediate-resend task isolation, all premium-tour sheets,
   dark mode, landscape, and accessibility-size control reachability. On the
   hosted iOS 26 simulator, XCTest's full automated accessibility audit must
   also pass for signed-out, device-code, and populated-chat surfaces.
6. Run the premium UI tour again while recording an H.264 MP4 bounded by
   in-app ready/finished markers, export every retained XCTest screenshot, and
   sample seven frames from the video. The track must be 8-65 seconds;
   Home-screen/build-startup footage is not accepted as tour evidence.
7. Require the fixed iPhone 6s Plus render to be exactly 1242x2208 pixels and
   reject the 960x1440 (320x480 at 3x) compatibility canvas in both runtime
   screenshots and sampled video frames. Require the dark 6s Plus fixture to
   match the same geometry and the runtime landscape capture to be wider than
   it is tall. Pixel sampling rejects light-resolved fixed or runtime dark
   evidence and any landscape capture with a large near-black unused canvas.
8. Build the generic arm64 iOS Release app with signing disabled, add an ad-hoc
   signature, verify the signature and arm64 slice, package the IPA, test the ZIP,
   require an iPhone-only `UIDeviceFamily`, and assert the bundle ID, version,
   build, launch storyboard, arm64 capability, and iOS 15 minimum before
   generating SHA-256 digests.

The workflow prefers an iPhone 8 Plus simulator when a compatible runtime still
exists, then falls back through 414-point and current iPhone device types. Exact
legacy viewport coverage does not depend on that availability because the visual
unit tests host the real app UI at fixed point sizes.

## Physical iPhone 6s Plus acceptance

The release cannot automate a personal ChatGPT login or a private jailbroken
phone from public CI. Before treating a build as proven on-device, manually check:

- install/upgrade through the device's trusted ad-hoc application mechanism;
- cold launch and portrait/landscape rotation on iOS 15;
- device-code login, token refresh after relaunch, and sign-out/revocation;
- model list and one streamed text reply on the account;
- Stop and Regenerate, then edit an earlier prompt and resend;
- photo-library, camera, microphone, and speech permission paths;
- large image attachment memory behavior and four-image limit;
- background/foreground during streaming and after memory pressure;
- history persistence, search, rename, pin, export, and deletion;
- light/dark mode, largest accessibility text, VoiceOver focus order, and the
  software keyboard in portrait and landscape.

Never put a live token, one-time code, account ID, email address, or conversation
in a bug report or release artifact.
