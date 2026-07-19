# ChatGPT Legacy 1.0.0

The first public release brings a native, iPhone-only ChatGPT experience back to
iOS 15. It is tuned for the 414x736-point iPhone 6s Plus display and uses
browser-based ChatGPT/Codex OAuth—there is no API-key field or developer proxy.

Highlights include streaming and cancellation, multiple searchable local
conversations, pin/rename/delete and Markdown export, edit-and-resend branching,
model and reasoning controls, custom instructions, a prompt library, photo and
camera attachments, dictation, copy/share actions, haptics, Dynamic Type, dark
mode, and VoiceOver labels.

The attached IPA is ad-hoc signed (`codesign -`) without a certificate or
provisioning profile. It is intended for a compatible jailbroken device with an
unsigned-app installation mechanism such as AppSync Unified; it will not install
on a stock iPhone. Verify `SHA256SUMS.txt` before installation.

This project is unofficial and is not affiliated with or endorsed by OpenAI.
Codex subscription interfaces are experimental and can change upstream.
