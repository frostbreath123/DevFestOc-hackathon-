# Railocity AI proxy

A small server between the app and an AI model. It keeps the provider key off
the phone, adds the safety rules, and returns one plain-language explanation.

The app sends only verified journey data. It does not send names, PNRs, phone
numbers or locations. The app also checks the reply before it shows it, and
shows the deterministic facts next to it. See `lib/logic/assistant/`.

## Run

Needs Node 18 or newer. No packages to install.

```
set ANTHROPIC_API_KEY=your-key        (Windows cmd)
$env:ANTHROPIC_API_KEY = "your-key"   (PowerShell)
export ANTHROPIC_API_KEY=your-key     (macOS, Linux)

node tools/ai_proxy/server.mjs
```

| Variable            | Default                    | Meaning                         |
| ------------------- | -------------------------- | ------------------------------- |
| `ANTHROPIC_API_KEY` | none                       | Required. Never put it in the app. |
| `RAILOCITY_MODEL`   | `claude-sonnet-5-5`        | Model name.                     |
| `PORT`              | `8787`                     | Port.                           |
| `HOST`              | `127.0.0.1`                | Use `0.0.0.0` to allow a phone on your network. |

Check it: `GET /health` returns `{"ok":true,"configured":true}`.

## Use it from the app

```
flutter run --dart-define=RAILOCITY_AI_ENDPOINT=http://10.0.2.2:8787/explain
```

`10.0.2.2` is how the Android emulator reaches your computer. Debug builds
allow plain HTTP for this. Release builds need HTTPS.

## Before you put this on the internet

This is a prototype server. Before real passengers use it:

* Serve it over HTTPS.
* Add authentication, for example an app attestation token. The built-in limit
  (30 requests a minute for each address) only slows a mistake. It does not
  stop abuse.
* Log requests without the question text if you do not need it.
* Review the rules in `SYSTEM_PROMPT` with someone who knows railway rules.

## Test

```
node --test tools/ai_proxy/server.test.mjs
```

The tests use a fake model endpoint. They do not call a real AI service and do
not need a key. The proxy has not been run against a live model yet.
