# Security

## Data handling

ChatGPT Legacy sends message content and selected images directly to OpenAI's
ChatGPT Codex backend over HTTPS. It has no developer-operated proxy, analytics,
advertising SDK, or API-key field. OAuth access, refresh, and ID tokens are saved
as a device-only Keychain item that is available only while the device is
unlocked. Conversation history and preferences remain in the app sandbox.

The app never logs tokens, one-time device authorization identifiers, passwords,
or message bodies. CI uses deterministic offline UI fixtures and contains no
OpenAI credentials.

## Important trust boundary

This is an unofficial, experimental client and is not affiliated with or
endorsed by OpenAI. It reproduces the public Codex device-code flow and talks to
the Codex subscription backend used by OpenAI's open-source Codex client. Those
interfaces can change without notice. Review the source and release checksum
before installing it on a jailbroken device.

Jailbreak tweaks can bypass normal iOS sandbox and Keychain protections. Treat
the device and every installed tweak as trusted. Sign out before lending,
selling, or retiring the device.

## Reporting a vulnerability

Open a GitHub security advisory for vulnerabilities that could expose OAuth
tokens, conversations, or arbitrary local data. Do not include live tokens,
device codes, or personal conversations in the report. For non-sensitive bugs,
use a normal GitHub issue.
