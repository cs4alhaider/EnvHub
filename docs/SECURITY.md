# Security

## The short version

- **No network access, no telemetry, no accounts.** Nothing leaves your machine —
  see the [privacy policy](../PRIVACY.md).
- Working `.env` files are stored **as-is on disk** — encryption applies only to
  explicit `.envenc` exports.
- Values are **masked by default** everywhere they're displayed (editor, search,
  save review, CLI) — safe to screen-share.
- Every save keeps a `.bak` copy of the previous version next to the file.
- Lost `.envenc` passwords are **unrecoverable by design**.

## The `.envenc` format

A `.envenc` file is a JSON envelope:

```json
{
  "version": 1,
  "type": "single | project | library",
  "kdf": "scrypt",
  "kdfParams": { "N": 32768, "r": 8, "p": 1 },
  "salt": "base64",
  "nonce": "base64",
  "ciphertext": "base64"
}
```

The plaintext payload (before encryption) is JSON describing the file(s) — each with its
key/value pairs and raw text for faithful materialization. The key is
`scrypt(password, salt)`; the payload is sealed with **AES-256-GCM**, with the 16-byte GCM
auth tag appended to the ciphertext. Tampering or a wrong password fails cleanly —
authenticated encryption never yields silent garbage.

The scrypt implementation is in-house on CryptoKit primitives and validated against the
official RFC 7914 test vectors (see `EnvHubKit/Tests/CryptoTests`).

## Reporting a vulnerability

Please open a [GitHub issue](https://github.com/cs4alhaider/EnvHub/issues/new) — or, if
the report is sensitive, contact the author privately via [alhaider.net](https://alhaider.net)
before disclosing publicly.
