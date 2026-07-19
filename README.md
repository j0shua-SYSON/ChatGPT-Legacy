# ChatGPT Legacy

A polished, native ChatGPT client for iOS 15 and the iPhone 6s Plus. ChatGPT
Legacy signs in through OpenAI's browser-based Codex device authorization; it
does not ask for an API key and has no developer-operated backend.

> [!IMPORTANT]
> This is an unofficial experimental client, not an OpenAI product. OpenAI
> documents ChatGPT OAuth for Codex clients, not a general third-party ChatGPT
> API OAuth program. The upstream flow or subscription backend can change and
> break this app.

## Features

- Streaming replies with Stop, Regenerate, and edit-and-resend branching
- Account model discovery plus reasoning and response-style controls
- Multiple local conversations with search, pin, rename, delete, and Markdown
  export
- Up to four optimized photo or camera attachments per message
- Speech-framework dictation, prompt library, custom instructions, copy/share,
  haptics, dark mode, Dynamic Type, and VoiceOver labels
- Device-only Keychain token storage and best-effort OAuth revocation on sign-out
- Deterministic unit, visual-layout, and XCUITest fixtures with release screenshots
  and an MP4 UI tour

## Requirements

- iOS 15.0 or later on an iPhone (the primary target is iPhone 6s Plus)
- An eligible ChatGPT account with Codex access
- For the release IPA: a compatible jailbroken installation path for ad-hoc or
  unsigned apps. The IPA is not intended for a stock, non-jailbroken device.

## Build from source

The project is described by [`project.yml`](project.yml) and generated with
[XcodeGen](https://github.com/yonaskolb/XcodeGen). On a Mac with Xcode and
XcodeGen:

```sh
xcodegen generate
xcodebuild -project ChatGPTLegacy.xcodeproj \
  -scheme ChatGPTLegacy \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test
```

The public GitHub Actions workflow runs the same project generation, unit and UI
tests, exact 414x736 and 320x568 visual-layout renders, an automated UI tour,
generic arm64 device build, ad-hoc signing, IPA integrity checks, and SHA-256
generation. No certificate, provisioning profile, OpenAI credential, or signing
secret is used.

## Install on a jailbroken test device

1. Download the IPA and `SHA256SUMS.txt` from the matching GitHub Release.
2. Verify the SHA-256 digest on your computer.
3. Install using your jailbreak's trusted ad-hoc/unsigned-app mechanism.
4. Launch, tap **Continue with ChatGPT**, and complete the one-time code at the
   OpenAI page opened by the app.

The app never receives your password. OAuth tokens stay in the iOS Keychain;
conversation history stays in the app sandbox. A jailbreak can weaken both
boundaries, so install only tweaks you trust. See [`SECURITY.md`](SECURITY.md).

## OAuth provenance

The authentication implementation follows OpenAI's official
[Codex authentication documentation](https://developers.openai.com/codex/auth),
the official [Codex app-server device-code flow](https://developers.openai.com/codex/app-server),
and the current open-source [`openai/codex`](https://github.com/openai/codex)
implementation. The embedded OAuth client ID is a public identifier from Codex,
not a secret.

## License

MIT. “ChatGPT” and “OpenAI” are trademarks of OpenAI; their use here only
describes compatibility.
