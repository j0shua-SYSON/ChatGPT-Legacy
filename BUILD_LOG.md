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
  Speech-framework dictation.
- `ChatGPTLegacy/UI/AppTheme.swift`: adaptive premium token system and reusable
  controls.
- `ChatGPTLegacy/UI/RootView.swift` and `LoginView.swift`: restore state and
  polished device-code sign-in.
- `ChatGPTLegacy/UI/ChatView.swift`, `MessageRow.swift`, `HistoryView.swift`,
  `SettingsView.swift`, and `PromptLibraryView.swift`: complete chat, multimodal
  composer, message actions, history/account management, settings, and presets.
- `ChatGPTLegacyTests/`: OAuth migration, SSE, Responses payload, persistence,
  image processing, and exact 414x736/320x568 render tests.
- `ChatGPTLegacyUITests/`: five deterministic flows with retained screenshots,
  including a complete premium UI tour and accessibility text sizing.
- `project.yml` plus `Info.plist` and asset catalogs: iOS 15 iPhone-only XcodeGen
  project, permissions, adaptive launch color, and a generated opaque app icon.
- `.github/workflows/ci.yml` and `scripts/ci/`: workspace-local XcodeGen,
  simulator selection, analyzer/test gate, MP4 recording, screenshot/video-frame
  export, arm64 build, ad-hoc signing, IPA inspection, evidence bundling, and tag
  release publishing.
- `README.md`, `SECURITY.md`, `LICENSE`, `docs/TEST_PLAN.md`, and release notes:
  public documentation, threat boundary, install guidance, and test disclosure.

Git and the public GitHub repository have not been initialized yet. The first
hosted Xcode compile/test run is the next source-of-truth gate.

## Current risks and items to verify

- The Swift source has not compiled yet; expect iterative fixes from hosted
  Xcode diagnostics.
- Verify all iOS 15 API availability and Swift concurrency syntax.
- FedRAMP claim/header routing and Codable defaults for tokens, attachments, and
  pins are implemented but still need XCTest compilation/execution.
- The current public macOS runner may not support an iPhone 8 Plus device type;
  fixed-size 414x736 rendering remains mandatory even if UI automation uses a
  newer simulator.
- Validate the direct Codex subscription endpoint on the physical device; CI can
  validate request construction but cannot complete a personal OAuth login.
- An unsigned IPA may require AppSync Unified or equivalent on the jailbroken
  device. Do not claim stock-device installability.

## Next implementation steps

1. Run local text/project checks; initialize Git; create and push the public repo.
2. Iterate on GitHub Actions until green. Download screenshots/video/results into
   this directory, inspect them, fix visible bugs, rerun, tag `v1.0.0`, and publish
   the tested release assets.
3. Preserve the generated `.xcodeproj` from hosted XcodeGen in the final source
   tree if the first build confirms the project specification.

## Operational facts

- GitHub CLI is authenticated as `j0shua-SYSON` with `repo` and `workflow` scope.
- `j0shua-SYSON/ChatGPT-Legacy` was verified absent and is available to create.
- Local Git exists; local Xcode is unavailable.
- A docs MCP entry was added only inside `.codex-tmp/codex-home`; no global Codex
  home was changed.
- Never record access tokens, refresh tokens, ID tokens, device-auth IDs, GitHub
  tokens, or user credentials in this log, source, CI output, or release assets.
