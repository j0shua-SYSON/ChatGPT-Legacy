# ChatGPT Legacy build log

Last updated: 2026-07-19 (Asia/Seoul)

## Objective

Build and publicly release **ChatGPT Legacy**, a premium, feature-rich native
ChatGPT client for iOS 15, targeting a jailbroken iPhone 6s Plus. Authentication
must use ChatGPT/Codex OAuth rather than an OpenAI API key.

## Hard boundaries

- All writes, caches, clones, build outputs, and downloaded artifacts stay under
  `F:\JOSHUA_1st_2021\projects\ChatGPT-Legacy`.
- Do not install packages or change global Git, GitHub CLI, Codex, Xcode, or OS
  configuration.
- The user's `C:` drive is out of storage. It may be read for preinstalled
  instructions, but it must not be written.
- Use GitHub Actions through `gh` for Apple builds because Xcode is unavailable
  locally.
- Create `j0shua-SYSON/ChatGPT-Legacy` as a public repository.
- Do not install anything on a phone automatically. The target is a jailbroken
  test device, so the release should carry an unsigned/ad-hoc-signed IPA and
  should not use certificates, provisioning profiles, or signing secrets.

## Requested product scope

- iOS 15 deployment target and iPhone-only layout tuned for the iPhone 6s Plus
  414x736-point viewport.
- OpenAI Codex device-code OAuth, Keychain token storage, refresh-token rotation,
  and best-effort revocation on sign-out.
- Streaming chat and account-specific model discovery.
- Feature-rich experience: multiple local conversations, search, pin, rename,
  delete, Markdown export, stop/regenerate, edit-and-resend branching, model
  picker, reasoning and response-style controls, custom instructions, prompt
  presets, photo/camera input, voice dictation, copy/share actions, local history,
  and haptics.
- Consistent premium UI with real UI automation, screenshots, and recorded video.
- Rigorous release gate: source/static checks, unit tests, simulator build/tests,
  UI tests, generic arm64 device build, IPA inspection, SHA-256 checksums, then a
  public `v1.0.0` GitHub Release containing the tested IPA and evidence.

## Authentication and backend evidence

- Official OpenAI Codex authentication docs state that Codex supports ChatGPT
  subscription sign-in and API-key sign-in:
  <https://developers.openai.com/codex/auth>
- Official Codex app-server docs document `chatgptDeviceCode` and the verification
  URL `https://auth.openai.com/codex/device`:
  <https://developers.openai.com/codex/app-server>
- Current upstream source was inspected from `openai/codex` commit
  `0fb559f0f6e231a88ac02ea002d3ecd248e2b515` (latest release observed:
  `rust-v0.144.6`, published 2026-07-18).
- Workspace-local sparse clone: `.codex-tmp/upstream-codex`.
- Device flow reproduced from `codex-rs/login/src/device_code_auth.rs`:
  `/api/accounts/deviceauth/usercode`, `/api/accounts/deviceauth/token`, then
  `/oauth/token` with authorization-code + PKCE exchange.
- Public Codex OAuth client identifier found in upstream source:
  `app_EMoamEEZ73f0CkXaXp7hrann`. It is a public identifier, not a secret.
- Refresh uses JSON at `https://auth.openai.com/oauth/token`; logout revokes at
  `https://auth.openai.com/oauth/revoke`.
- Subscription requests use
  `https://chatgpt.com/backend-api/codex/{models,responses}` with Bearer auth and
  `ChatGPT-Account-ID`, matching upstream Codex source.
- Product disclosure: this is an unofficial experimental Codex-subscription
  client. OpenAI documents OAuth for Codex clients, not a general third-party
  ChatGPT API OAuth program; upstream changes can break the integration.

## Design direction

- Subject: a calm, capable ChatGPT client for a still-useful legacy iPhone.
- Palette: cool mineral canvas, paper surfaces, graphite ink, restrained signal
  teal, adaptive dark mode. No warm-cream template, neon-on-black template, blur,
  or heavy GPU effects.
- Type: restrained system serif display, rounded system utility text, standard
  readable message body, monospaced operational labels.
- Signature element: a slim conversation rail and compact `L` signal mark.
- UI is Dynamic Type-aware, VoiceOver-labeled, minimum 44-point controls, solid
  backgrounds for 6s performance, and consistent 16/20-point corner language.

## Implemented so far

- `ChatGPTLegacy/Models/ChatModels.swift`: conversations, messages, image
  attachments, pinning, title generation, Markdown export, account profile.
- `ChatGPTLegacy/Models/AppSettings.swift`: response style, reasoning effort,
  custom instructions, haptics, built-in prompt library.
- `ChatGPTLegacy/Models/ImageAttachmentProcessor.swift`: bounded 1600px JPEG
  normalization suitable for the 6s.
- `ChatGPTLegacy/Persistence/ConversationRepository.swift`: atomic local JSON
  history.
- `ChatGPTLegacy/Security/KeychainStore.swift`: device-only Keychain OAuth token
  storage.
- `ChatGPTLegacy/Auth/OAuthModels.swift`: endpoints, token identity, JWT claim
  parsing, device and refresh response models.
- `ChatGPTLegacy/Auth/OpenAIAuthService.swift`: device code, polling, PKCE token
  exchange, refresh, restore, revoke, and local persistence.
- `ChatGPTLegacy/Networking/SSEParser.swift`: line-oriented SSE parser and error/
  output-text decoding.
- `ChatGPTLegacy/Networking/OpenAIChatService.swift`: model discovery, multimodal
  Responses payloads, OAuth headers, streaming, and HTTP/SSE errors.
- `ChatGPTLegacy/App/AppModel.swift`: auth lifecycle, conversations, model state,
  sending, retry after token refresh, streaming updates, stop/regenerate,
  edit-and-resend branching, prompt/image actions, and persistence.
- `ChatGPTLegacy/UI/SystemBridges.swift`: iOS 15 image picker, share sheet, and
  Speech-framework dictation with independent Speech and Microphone permission
  handling.
- `ChatGPTLegacy/UI/AppTheme.swift`: adaptive premium token system and reusable
  controls.
- `ChatGPTLegacy/UI/RootView.swift` and `LoginView.swift`: restore state and
  polished device-code sign-in.
- `ChatGPTLegacy/UI/ChatView.swift`, `MessageRow.swift`, `HistoryView.swift`,
  `SettingsView.swift`, and `PromptLibraryView.swift`: complete chat, multimodal
  composer, message actions, history/account management, settings, and presets.
- `ChatGPTLegacyTests/`: OAuth migration, SSE, Responses payload, persistence,
  image processing, and exact 414x736/320x568 render tests.
- `ChatGPTLegacyUITests/`: fifteen deterministic flows with retained screenshots,
  including OAuth-code, dark-mode, landscape, premium-tour, and accessibility
  coverage plus Stop/immediate-resend task isolation and XCTest's complete
  automated accessibility audit across welcome, device-code, chat, history,
  prompt-library, and response-settings surfaces.
- `project.yml` plus `Info.plist` and asset catalogs: iOS 15 iPhone-only XcodeGen
  project, permissions, adaptive launch color, and a generated opaque app icon.
- `.github/workflows/ci.yml` and `scripts/ci/`: workspace-local XcodeGen,
  simulator selection, analyzer/test gate, MP4 recording, screenshot/video-frame
  export, arm64 build, ad-hoc signing, IPA inspection, evidence bundling, and tag
  release publishing.
- `README.md`, `SECURITY.md`, `LICENSE`, `docs/TEST_PLAN.md`, and release notes:
  public documentation, threat boundary, install guidance, and test disclosure.

Git is initialized on `main`, and the public repository is live at
<https://github.com/j0shua-SYSON/ChatGPT-Legacy>. Hosted Xcode has compiled and
analyzed the complete app target successfully; the active gate is making all
unit/UI tests green before release.

## Current risks and items to verify

- The app target compiles, passes the Xcode static analyzer, and completed the
  full unit/UI/package pipeline on hosted Xcode 26.5. The next run must verify
  the iPhone-only metadata, clean bounded video, and expanded UI matrix.
- Unit request-construction tests cover OAuth headers, FedRAMP routing, payloads,
  migration defaults, SSE, persistence, images, and exact fixture rendering.
- The current public macOS runner may not support an iPhone 8 Plus device type;
  fixed-size 414x736 rendering remains mandatory even if UI automation uses a
  newer simulator.
- Validate the direct Codex subscription endpoint on the physical device; CI can
  validate request construction but cannot complete a personal OAuth login.
- An unsigned IPA may require AppSync Unified or equivalent on the jailbroken
  device. Do not claim stock-device installability.

## Next implementation steps

1. Push the iPhone-only, clean-video, dark/landscape/OAuth-code test changes and
   iterate until the expanded source-of-truth workflow is green.
2. Download and manually inspect every retained screenshot and every sampled
   frame from the bounded tour video; reject any system overlay or bad geometry.
3. Preserve the generated `.xcodeproj`, rerun the final source-of-truth gate, tag
   `v1.0.0`, verify the arm64 IPA/checksums/evidence, and publish the release.

## Operational facts

- GitHub CLI is authenticated as `j0shua-SYSON` with `repo` and `workflow` scope.
- `j0shua-SYSON/ChatGPT-Legacy` exists and was verified public.
- Local Git exists; local Xcode is unavailable.
- A docs MCP entry was added only inside `.codex-tmp/codex-home`; no global Codex
  home was changed.
- Never record access tokens, refresh tokens, ID tokens, device-auth IDs, GitHub
  tokens, or user credentials in this log, source, CI output, or release assets.

## Hosted run history

- Run `29682765640` for commit `5a381af` (2026-07-19): XcodeGen 2.46.0
  downloaded inside the runner workspace and generated `ChatGPTLegacy.xcodeproj`
  successfully. The validation step then failed before compilation because
  macOS `plutil -lint` rejected the JSON app-icon manifest. Fix: validate the
  asset JSON with `jq empty`; no app source change was required.
- Run `29682810139` for commit `61ad19a` (2026-07-19): project generation,
  plist/JSON validation, and `xcodebuild -list` passed on the macOS runner. The
  simulator step failed before compilation because failed `simctl create` output
  for iPhone 8 Plus was mistaken for a UUID. Fix: require a UUID-shaped success
  result and fall back across every available iPhone device type for iOS 26.5.
- Run `29682893582` for commit `6f5af68` (2026-07-19): cancelled during the
  simulator-preparation step after historical create probes were still slow on
  the iOS 26.5 runner. Fix: select the closest preinstalled compatible iPhone
  simulator first; exact iPhone 6s Plus dimensions remain covered independently
  by the fixed 414x736 render test.
- Run `29683008773` for commit `7cbb48f` (2026-07-19): selected and cold-booted
  the preinstalled iPhone 17 Pro Max simulator; Xcode 26.5 compiled and analyzed
  the complete app target for iOS 15 successfully. Test compilation then failed
  because the spaced display product name inferred module `ChatGPT_Legacy` while
  tests import target module `ChatGPTLegacy`. Fix: explicitly set
  `PRODUCT_MODULE_NAME: ChatGPTLegacy`. The evidence upload is also changed to
  include the hidden `.artifacts` tree so later diagnostics contain full logs.
- Run `29683170143` for commit `04cb0e5` (2026-07-19): the complete app compiled
  and passed static analysis on Xcode 26.5. Fifteen of sixteen unit tests passed;
  the only failure proved that ISO-8601 JSON encoding rounded subsecond `Date`
  precision. All five UI tests launched the app but failed because SwiftUI root
  accessibility identifiers propagated over descendant identifiers. The
  hierarchy and recordings also exposed a real 320x480 compatibility-mode bug:
  the color-only `UILaunchScreen` entry did not establish a native launch size.
  Fixes: encode new history timestamps as exact Unix seconds while accepting old
  ISO-8601 files, remove propagating root identifiers and wait on concrete
  controls, add a compiled launch storyboard, and assert a window larger than
  320x568. Full results, hierarchies, screenshots, and five failure recordings
  were downloaded under `.artifacts/runs/29683170143`.
- Visual evidence from run `29683170143`: the exact 414x736 populated fixture and
  320x568 empty fixture were inspected and are crisp, coherent, and readable;
  the populated view has a strong hierarchy, restrained teal accents, clear
  message grouping, and a compact composer. UI hierarchy evidence confirms the
  failed UI flows were running and visible rather than crashing. The next green
  run must confirm native full-screen sizing and all interaction paths.
- Run `29683731631` for commit `a863243` (2026-07-19): the app again compiled and
  passed static analysis. All legacy migration tests passed, but exact timestamp
  equality still failed because converting `Date` through Unix seconds loses
  low-order IEEE-754 bits; new files now encode the exact reference-date bit
  pattern and still accept both numeric and ISO-8601 history from prior builds.
  Two of five UI tests passed, including Accessibility Medium and the signed-out
  OAuth screen. The other failures were an intentionally mocked response that
  completed before XCTest could observe Stop, plus a history-row menu obscured
  by the search keyboard; the fixture stream is lengthened and search now has a
  real Done submission path.
- Crucially, generated-project inspection from run `29683731631` showed XcodeGen
  silently ignored the target-level `resources:` block: neither
  `Assets.xcassets` nor `LaunchScreen.storyboard` appeared in the PBX resource
  phase, so the supposedly fixed build remained in 320x480 compatibility mode
  and lacked its compiled app icon. Both resource types now remain inside the
  auto-typed `sources` tree, and CI explicitly requires their `in Resources`
  entries plus `UILaunchStoryboardName=LaunchScreen` before compilation.
- Visual geometry is now a release-blocking CI check rather than a manual hope:
  the true 6s Plus render must be 1242x2208 pixels, the compact render must be
  960x1704, and neither the runtime tour screenshot nor sampled video frame may
  be the broken 960x1440 compatibility canvas seen in the rejected runs.
- Run `29684223768` for commit `b6b5c16` (2026-07-19) stopped at the new
  preflight gate in seconds. XcodeGen's `info:` generator had overwritten the
  checked-in `Info.plist` and stripped `UILaunchStoryboardName` before the
  validation command read it. The app target now uses an explicit
  `INFOPLIST_FILE` build setting instead, leaving the reviewed plist untouched.
- Run `29684261077` for commit `dfcafa6` (2026-07-19) is the first complete green
  native-layout run: Xcode 26.5 static analysis passed, all 16 unit tests and all
  5 UI tests passed, the generic arm64/iOS 15 app built and verified under ad-hoc
  signing, and all evidence/release artifacts uploaded. The exact visual gates
  passed at 1242x2208 for the iPhone 6s Plus fixture, 960x1704 for the compact
  fixture, and 1320x2868 for runtime screenshots/video.
- Manual review of every visual state confirmed that the prior black-barred
  960x1440 compatibility canvas is gone. It also rejected two otherwise-green
  artifacts before release: Apple's first-run keyboard tutorial appeared over
  one composer capture, and the raw tour video spent its build startup/cleanup
  on the simulator Home Screen. UI automation now dismisses that tutorial, and
  the recorder is bounded by explicit ready/finished markers emitted while the
  tested app is on screen. Frame extraction also rejects tour tracks outside an
  8-65 second window, so the rejected 88-second recording cannot recur silently.
- Release inspection for run `29684261077` found a second metadata defect before
  tagging: XcodeGen's application-target default overrode the project-level
  iPhone family and emitted `UIDeviceFamily=[1,2]`, along with unused iPad icon
  warnings. The application target now explicitly sets family `1`, and package
  verification fails if the built plist contains anything except iPhone. The
  next hosted run also adds deterministic OAuth device-code, dark-mode,
  landscape, Stop/immediate-resend, and 414x736 dark rendering coverage.
- A final concurrency audit found that a cancelled generation or OAuth task
  could finish late and overwrite the state of an immediately started
  replacement. Both flows now carry operation identities. Stopping before the
  first token also removes the empty assistant placeholder synchronously; a
  dedicated UI regression test immediately resends and requires the replacement
  stream to stay active.
- Manual inspection of run `29685055751` rejected two newly added screenshots
  even though their interaction assertions passed: the requested dark style had
  resolved light, and the landscape attachment captured a sideways transitional
  surface with a large black unused canvas. UI tests now force dark mode through
  the SwiftUI environment, landscape capture waits for a settled rotated window,
  and a macOS pixel-sampling gate rejects light dark-mode evidence or black-barred
  landscape evidence automatically.
- All visual checks are joined as one short-circuiting pipeline before `tee`, so
  an early appearance or geometry failure cannot be masked by a later passing
  check when Bash computes the grouped command's exit status.
- The cleaned MP4 itself contained only app footage, but frame-zero inspection
  showed that `simctl recordVideo` began encoding several seconds after the
  ready marker and missed the opening chat/history beats. The deterministic tour
  now holds its opening chat for six seconds so the published video begins with
  the intended overview rather than midway through an action menu.
- Run `29685055751` for commit `b68c33d` (2026-07-19) otherwise completed the
  entire pipeline: 17 unit/visual tests and 8 UI tests passed, the cleaned tour
  was bounded to 31.11 seconds instead of 88 seconds, native geometry passed,
  and the arm64/iOS 15 ad-hoc package was verified with
  `UIDeviceFamily=[1]`. The IPA SHA-256 was
  `f11debe9fb9d2d5d3f8a8c89197d2949f2e9f47568fdb635509c8c5f7266b845`.
  It remains intentionally untagged because the dark/landscape visual defects
  above were found during artifact review.
- Run `29685726791` for commit `3248509` (2026-07-19) passed all 17
  unit/render tests and 8 of 9 UI tests, then correctly withheld packaging. The
  sole failure was in the new Stop/immediate-resend test. Its exported UI
  hierarchy proved the first deterministic chunk ("A good place to begin...")
  had already arrived before XCTest tapped Stop, so retaining that partial
  assistant response was correct and the "blank response" assertion was a
  false positive. The regression flow now opts into a four-second, test-only
  first-token delay. It can therefore verify both removal of a genuinely empty
  placeholder and operation-identity isolation for the immediate replacement,
  without weakening production cancellation behavior.
- Run `29686336491` for commit `0963252` (2026-07-19) passed all 18
  unit/render tests and 9 of 10 UI tests. The corrected Stop/immediate-resend
  regression passed. XCTest's unfiltered accessibility audit then rejected the
  signed-out eyebrow because its ten-point fixed font did not support Dynamic
  Type; packaging was skipped. All visible text now uses semantic scalable
  styles, compact controls expose at least 44-by-44-point hit regions, and the
  audit is split into six independent surface tests so one early issue cannot
  hide findings on chat, history, prompts, or settings.
- Run `29686769614` for commit `e5f4840` (2026-07-19) kept all 18
  unit/render tests green and ran all 15 UI flows. The nine functional UI tests
  passed; all six independent audits executed and exposed four Dynamic Type
  nodes plus two undersized nodes. Exported element crops identified the exact
  targets: model value, history Done, prompt title, version label, OAuth
  spinner, and settings refresh. Decorative/duplicate children are now grouped
  behind meaningful VoiceOver labels or values, toolbar actions use labeled
  symbols, the noninteractive spinner is hidden from the accessibility tree,
  and refresh has a 44-point hit region. Audit tests now follow Apple's
  recommendation to continue after a finding, allowing a single run to report
  every issue on each visible surface while still failing the release gate.
- Run `29687332174` for commit `02173d1` (2026-07-19) used the continuing audit
  mode and enumerated the complete visible set: 56 accessibility findings and
  one functional tour failure. The tour regression was caused by converting
  prompt buttons into new accessibility elements, which stripped their stable
  automation identifiers; that modifier is removed. The audit findings resolve
  into five shared causes rather than 56 unrelated bugs: compressed fixed-row
  text, utility text that did not scale fully, low-contrast secondary tokens,
  unlabeled UIKit text views/decorative symbols, and truncated search prompts.
  Rows now reflow vertically, utility fonts use semantic Dynamic Type styles,
  light-theme secondary colors exceed 4.5:1 with margin, prompt badges use
  decorative symbols, text views expose real labels/hints, and search prompts
  are shorter inside flexible-height fields. No audit category is filtered.
