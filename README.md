# HanziStroke

Native SwiftUI stroke-order rendering for Chinese characters (simplified and traditional), using the
[hanzi-writer-data](https://github.com/chanind/hanzi-writer-data) set (Make Me a Hanzi, ~9,500 characters).
iOS 17 / macOS 14, no dependencies.

![preview](preview.png)

## Use

Add the folder as a local Swift package (File ▸ Add Package Dependencies ▸ Add Local…), then:

```swift
import HanziStroke

// Quick start: a full demo screen
HanziStrokeDemo()

// Or the pieces
let c = try await HanziDataLoader.load("書")             // bundle → disk cache → CDN
StrokeOrderView(character: c, radicalColor: .blue)      // animated; tap to replay
StrokeOrderView(character: c, speed: 0.5, loops: true)
StrokeOrderView(character: c2, startDelay: c.animationDuration())  // play after c finishes
StrokeStepsView(character: c, panelSize: 56)            // one panel per stroke, start dot on the new stroke
```

## Loading, errors and privacy

`HanziDataLoader.load(_:)` normalizes the input (`HanziCharacter.normalize` keeps the last CJK
ideograph and strips variation selectors), then checks the app bundle, then a disk cache in
Caches, then jsDelivr, caching what it downloads. So anything looked up once works offline.

Errors are a `LoadError`: `.invalidCharacter`, `.notFound`, `.badData`, `.network(URLError.Code)` or
`.server(statusCode:)`; `isRetryable` says whether a retry button makes sense. Malformed data throws
`HanziCharacter.DataError` instead of crashing.

A CDN request sends the character and the user's IP address to jsDelivr. Bundle the characters you
need (or self-host) to avoid that, and account for it in your App Store privacy answers.

## Accessibility and localization

- Reduce Motion: `StrokeOrderView` shows the finished character instead of animating.
- VoiceOver: the view is a button with a Replay action; step panels read "Stroke 3 of 13".
- The step chart marks the new stroke with colour, extra thickness and a start dot.
- Step panels scale with Dynamic Type.
- Strings are in a String Catalog with plural rules, in English and Traditional Chinese (zh-Hant).

The animation pauses while off screen or in the background, including with `loops: true`.

## How it draws

Each stroke has a filled outline and a median (the brush path). Animation clips to the outline and
strokes a 180-unit-wide line along the median, trimmed to the current progress — the same technique
Hanzi Writer uses. Pacing follows Hanzi Writer: `(medianLength + 600) / 3000` s per stroke at speed 1.

Data is y-up with the top at y = 900; `HanziCharacter` flips it to SwiftUI's top-left origin in a
1024 × 1024 box.

## Offline data

`npm pack hanzi-writer-data@2.0.1`, extract, and add the JSON files to your app as a folder reference
named `hanzi-data` (~47 MB for all; copy only the characters you need to keep it small). Then use
`HanziDataLoader.fromBundle(_:)`.

## Taiwan stroke order

The data follows **PRC** stroke order. For characters where Taiwan's MOE order differs, use
`character.reordered([...])` to reorder strokes. That fixes order only, not stroke shape or direction.
Check the MOE site (stroke-order.learningweb.moe.edu.tw) for the reference order.

## License

Code: MIT (see `LICENSE`). Character data: Arphic Public License (see `ARPHICPL.TXT`, also shipped in the npm package);
ship that license with the data if you bundle it.


## Demo app

`Demo/HanziStrokeDemoApp.xcodeproj` is a small iOS app that uses this package as a local dependency:
a list of sample characters (simplified and traditional), a field to look up any character, and a
detail screen with the animation, replay, persistent speed/loop/radical/grid settings and the step
chart. About 3,900 characters (roughly a sixth-grade reading level, Traditional and Simplified) are
bundled in `Demo/HanziStrokeDemoApp/HanziData.bundle` (12 MB) and work offline; other characters are
downloaded once and cached. Regenerate the set with `python3 Scripts/make_offline_data.py`
(`--top N` and `--max-grade N` adjust its size); see the script for how the list is chosen. It's localized in English and Traditional
Chinese, ships a privacy manifest, and shows the Arphic license under Acknowledgements (ⓘ).

## Tests

`swift test` runs unit tests and snapshot tests for 了 (hook stroke), 體 (23 strokes) and 愛
(radical colour). Reference images are in `Tests/HanziStrokeTests/__Snapshots__`; delete one to
re-record it after an intentional rendering change.
