  # Railocity

A Flutter app that helps Indian Railways passengers understand a disruption and
decide what to do next.

> When the journey changes, help the passenger understand what changed, how it
> affects them, and what they can do next.

**Status: working prototype.** All railway data in it is **simulated demo data**.
It is labelled as demo data on every screen that shows a time. See
[What is real and what is not](#what-is-real-and-what-is-not).

## The scenario it demonstrates

1. A passenger saves a journey with a connecting train.
2. Home shows the status, how fresh it is, and where the data came from.
3. A delay or platform change creates a relevant alert.
4. The connection window is recalculated by code.
5. The assistant explains the impact in simple language.
6. The passenger can see realistic other trains and official guidance.
7. If data or AI fails, the app says so clearly and shows a safe fallback.

To see it: open **Settings → Demo controls** and use `90101 +1 h 30 min`.

## How it keeps railway information honest

| Rule | How it is enforced |
| --- | --- |
| Times, connection checks and eligibility are never written by AI | `lib/domain/connection.dart`, `alternative.dart`, `support_rules.dart` are plain Dart. |
| The AI cannot invent a time, train or platform | `lib/logic/assistant/ai_guard.dart` rejects AI text with a value that is not in the verified facts, and rejects promises. A rejected text is replaced by the built-in summary. |
| The passenger can tell verified data, calculations and text apart | Every assistant reply is split into sections with a label: *Verified / Demo data*, *Calculated*, *AI-generated*, *Written by Railocity, not AI*. |
| Data age is always visible | `Updated 14:05 (3 min ago) · Source: …` on every status. Over 10 minutes old shows a stale banner. |
| Missing data is not guessed | No platform → "not known yet". No walking time for a station → the check says so and uses a stricter rule. |
| No false promises or false actions | Copy says "may", never "will". The app cannot file, book, cancel or refund, and says so. |
| AI failure never blocks the passenger | With no AI, or on error or rejection, the same facts and a built-in explanation are shown, with the reason. |

## Run it

You need the [Flutter SDK](https://docs.flutter.dev/get-started/install)
(developed on Flutter 3.47 / Dart 3.13) and an Android emulator or a device.

```
flutter pub get
flutter run
```

Run the checks:

```
flutter analyze
flutter test                              # 94 tests
node --test tools/ai_proxy/server.test.mjs  # 5 tests
```

### Turn on AI explanations (optional)

The app never holds an AI key. Start the proxy in `tools/ai_proxy` (see its
README), then:

```
flutter run --dart-define=RAILOCITY_AI_ENDPOINT=http://10.0.2.2:8787/explain
```

Without it, the assistant uses the built-in explanations, and says that AI is off.

## What is real and what is not

| Part | State |
| --- | --- |
| Connection calculation, alert rules, alternatives, guard | **Real, tested** (`test/`). |
| Offline saving of journey, status and alerts | **Real, tested.** |
| Railway data | **Simulated.** `MockRailwayDataService` only. No authorised live API is connected. `RailwayDataService` is the interface to implement. With `--dart-define=RAILOCITY_DEMO_DATA=false` the app shows clear "no data provider" errors. It never invents data. |
| Push notifications | **Not built.** Alerts show in the app, in a badge, and as a snack bar while the app is open. OS push needs a backend. |
| AI explanations | **Built, not run against a live model.** The proxy is tested against a fake model endpoint. |
| Refund and delay rules | **Unverified.** `SupportRules` holds a short summary of public rules (3 hour delay, cancelled train). A person must check them against the official source, then set `SupportRules.verifiedOn`. Until then the app says the summaries are unchecked. |
| Hindi text | **Draft.** Needs a review by a fluent reader. Train numbers, times and platforms are never translated. |
| Other Indian languages | Not added. Add a language only when it can be reviewed. |
| Google Sans | Used when the device has it. Not bundled (licence). Falls back to Roboto. |
| iOS | Project files exist. Not built or tested. |
| Android build | Not built on the machine used for development (no Android SDK). Analyse and tests pass. |

## Structure

```
lib/
  core/        theme (Material 3), localisation, config, clock
  domain/      pure Dart rules: connection, alternatives, alerts, support rules
  data/        railway data interface, demo service, local storage
  logic/       alert engine, assistant (facts, guard, explainer, orchestrator)
  state/       AppController (ChangeNotifier) and AppScope
  ui/          screens: home, journey, alerts, assistant, alternatives,
               support, settings, shell, shared widgets
test/          unit, scenario and widget tests
tools/ai_proxy small server that holds the AI key and adds safety rules
```

State management is one `ChangeNotifier` plus an `InheritedNotifier`. It uses
only the Flutter SDK. Packages: `shared_preferences`, `url_launcher`.

## Design notes

* Material 3, teal seed colour, tonal surfaces, no gradients or glow.
* Status uses colour **and** an icon **and** a text label.
* Layout is tested for overflow at 360 × 640 dp with 200% text on every main
  screen. It has **not** been looked at on a real device or emulator yet.
* Buttons have a 48 dp minimum size. Alerts, headings and loading and error
  messages have semantic labels or live regions. A screen reader pass on a
  device has **not** been done yet.
* Text follows ASD-STE100 style: short sentences, what happened, what it means,
  what to do. Developer log lines name the component and keep personal data out.

## Privacy

The app asks for the internet permission only. It stores train numbers, status
and alerts on the phone. It asks for no PNR, name, phone number or location.
The AI proxy receives only the verified facts for the saved journey.
