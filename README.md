# Currencies

A small native iPhone and iPad app for iOS 26 and later, built with SwiftUI, Swift Charts, and a synchronized WidgetKit widget. No external libraries or API key required.

<!-- screenshots:start -->
## Screenshots

Captured automatically by native UI tests using fixed sample data. Only small JPEG previews (320 pixels wide) load here; click an image to open the full-resolution PNG. Images are hosted on GitHub Pages and are not stored in the Git repository.

| Overview | Mental conversion | History | Editing | Dark mode |
| --- | --- | --- | --- | --- |
| <a href="https://leongeorgi.github.io/currency/screenshots/originals/en/overview-light.png"><img src="https://leongeorgi.github.io/currency/screenshots/previews/en/overview-light.jpg" alt="English · Overview" width="180"></a> | <a href="https://leongeorgi.github.io/currency/screenshots/originals/en/mental-math.png"><img src="https://leongeorgi.github.io/currency/screenshots/previews/en/mental-math.jpg" alt="English · Mental conversion" width="180"></a> | <a href="https://leongeorgi.github.io/currency/screenshots/originals/en/history.png"><img src="https://leongeorgi.github.io/currency/screenshots/previews/en/history.jpg" alt="English · History" width="180"></a> | <a href="https://leongeorgi.github.io/currency/screenshots/originals/en/editing.png"><img src="https://leongeorgi.github.io/currency/screenshots/previews/en/editing.jpg" alt="English · Editing" width="180"></a> | <a href="https://leongeorgi.github.io/currency/screenshots/originals/en/overview-dark.png"><img src="https://leongeorgi.github.io/currency/screenshots/previews/en/overview-dark.jpg" alt="English · Dark mode" width="180"></a> |

| German | Japanese | Spanish | French |
| --- | --- | --- | --- |
| <a href="https://leongeorgi.github.io/currency/screenshots/originals/de/overview-light.png"><img src="https://leongeorgi.github.io/currency/screenshots/previews/de/overview-light.jpg" alt="German · Overview" width="180"></a> | <a href="https://leongeorgi.github.io/currency/screenshots/originals/ja/overview-light.png"><img src="https://leongeorgi.github.io/currency/screenshots/previews/ja/overview-light.jpg" alt="Japanese · Overview" width="180"></a> | <a href="https://leongeorgi.github.io/currency/screenshots/originals/es/overview-light.png"><img src="https://leongeorgi.github.io/currency/screenshots/previews/es/overview-light.jpg" alt="Spanish · Overview" width="180"></a> | <a href="https://leongeorgi.github.io/currency/screenshots/originals/fr/overview-light.png"><img src="https://leongeorgi.github.io/currency/screenshots/previews/fr/overview-light.jpg" alt="French · Overview" width="180"></a> |

<details>
<summary>All full-resolution originals (PNG)</summary>

| Language | Overview | Mental conversion | History | Editing | Dark mode |
| --- | --- | --- | --- | --- | --- |
| English | [Overview](https://leongeorgi.github.io/currency/screenshots/originals/en/overview-light.png) | [Mental conversion](https://leongeorgi.github.io/currency/screenshots/originals/en/mental-math.png) | [History](https://leongeorgi.github.io/currency/screenshots/originals/en/history.png) | [Editing](https://leongeorgi.github.io/currency/screenshots/originals/en/editing.png) | [Dark mode](https://leongeorgi.github.io/currency/screenshots/originals/en/overview-dark.png) |
| German | [Overview](https://leongeorgi.github.io/currency/screenshots/originals/de/overview-light.png) | [Mental conversion](https://leongeorgi.github.io/currency/screenshots/originals/de/mental-math.png) | [History](https://leongeorgi.github.io/currency/screenshots/originals/de/history.png) | [Editing](https://leongeorgi.github.io/currency/screenshots/originals/de/editing.png) | [Dark mode](https://leongeorgi.github.io/currency/screenshots/originals/de/overview-dark.png) |
| Japanese | [Overview](https://leongeorgi.github.io/currency/screenshots/originals/ja/overview-light.png) | [Mental conversion](https://leongeorgi.github.io/currency/screenshots/originals/ja/mental-math.png) | [History](https://leongeorgi.github.io/currency/screenshots/originals/ja/history.png) | [Editing](https://leongeorgi.github.io/currency/screenshots/originals/ja/editing.png) | [Dark mode](https://leongeorgi.github.io/currency/screenshots/originals/ja/overview-dark.png) |
| Spanish | [Overview](https://leongeorgi.github.io/currency/screenshots/originals/es/overview-light.png) | [Mental conversion](https://leongeorgi.github.io/currency/screenshots/originals/es/mental-math.png) | [History](https://leongeorgi.github.io/currency/screenshots/originals/es/history.png) | [Editing](https://leongeorgi.github.io/currency/screenshots/originals/es/editing.png) | [Dark mode](https://leongeorgi.github.io/currency/screenshots/originals/es/overview-dark.png) |
| French | [Overview](https://leongeorgi.github.io/currency/screenshots/originals/fr/overview-light.png) | [Mental conversion](https://leongeorgi.github.io/currency/screenshots/originals/fr/mental-math.png) | [History](https://leongeorgi.github.io/currency/screenshots/originals/fr/history.png) | [Editing](https://leongeorgi.github.io/currency/screenshots/originals/fr/editing.png) | [Dark mode](https://leongeorgi.github.io/currency/screenshots/originals/fr/overview-dark.png) |

</details>

<!-- screenshots:end -->

## Getting started

1. Open `Currency.xcodeproj` in Xcode 26 or later.
2. Select the **Currency** scheme and an iPhone simulator, then run the app.
3. To run on a physical device, select your signing team for both targets. Set the bundle identifiers and the `APP_GROUP_IDENTIFIER` build setting to your own registered identifiers. The app and widget must use the same App Group; their entitlements and Info.plist files read this build setting automatically.

## Using the app

- The base currency and amount appear at the top, with comparison currencies in separate cards below. The amount and currency selection are saved between launches. Rates and converted amounts include currency symbols and up to twelve significant digits. Native flag emoji identify currencies in both the app and widget; the euro uses the EU flag, and currencies without a single associated country use a globe.
- Swipe the amount buttons below the input to choose a typical amount. Presets follow a 1–2–5 sequence, scaled roughly to the currency's value against the euro: EUR offers 1, 2, 5 … 200; JPY offers 100, 200, 500 … 20,000. The selected amount is highlighted, saved, and synchronized with the widget. You can still enter any amount directly.
- Tap the base currency code to change it. Use the **plus button** to select multiple comparison currencies. Both pickers support searching by currency name or code.
- Tap **Edit** at the top left to show native reorder handles and delete buttons. The saved order determines which three currencies appear in the widget. An empty comparison list is also saved.
- The target button (`scope`) on each comparison card makes that currency the base. The previous base takes its place in the comparison list; the other currencies and entered amount are preserved.
- Tap a comparison currency to open its details, including a worked mental-conversion example and its history. Choose a period and touch the chart to inspect individual rates. The chart shows the rate for one unit of the base currency, regardless of the entered amount. Five-year charts use weekly data points; ten-year charts use monthly points. **Start at zero** controls the vertical axis baseline and saves each change immediately, including across app restarts.
- Choose **… → Settings** to change the accent color. A large preview shows the current app icon; tap a color swatch below it to update the app, widget, and Home Screen icon together. The selected swatch has a checkmark. Choices include the original terracotta and thirteen standard Apple colors. The selection is saved between launches.
- Pull down to refresh or choose **… → Refresh**. Data source information and widget instructions are available under **… → About Currencies**.
- To add a widget, touch and hold the Home Screen, then choose **Edit → Add Widget → Currencies**. Small widgets show a compact conversion list; medium widgets have a separate amount area and comparison cards. Both use native SwiftUI layouts and system backgrounds for light and dark mode. The widget follows the app's amount, base currency, and first three comparison currencies in their saved order. Tapping it opens the app without replacing its full currency list.

## Languages

The app and widget support English, German, Japanese, Spanish, and French. They follow iOS language preferences; you can also set a language for the app in iOS Settings. App names, widget gallery descriptions, help, errors, chart periods, and VoiceOver labels are localized. Currency names, symbols, numbers, and dates use the native formatting for the selected language and region. Changing the language preserves the saved amount and currency selection.

The shared native String Catalogs, `Shared/Localizable.xcstrings` and `Shared/InfoPlist.xcstrings`, are included in both targets. Add new interface text as SwiftUI localization keys or with `String(localized:)`. Internal period identifiers remain language-independent so existing history caches continue to work. Repository documentation and screenshot gallery captions are in English; the app retains all five localizations.

## Data and updates

The app uses the public [Frankfurter v2 API](https://frankfurter.dev/): `/currencies`, `/rate/{base}/{quote}`, and `/rates`, with `base`, `quotes`, `from`, `to`, and optional `group` parameters. Rates are daily reference rates. The displayed date comes from the API, rather than the time of the request. These are not intraday or guaranteed transaction rates.

Rates and time series are cached locally. The app and widget share the latest rates through their App Group. The amount, accent color, and ordered currency selection are also saved as an atomic file in that group. The app owns these settings; the widget reads them and displays the first three comparisons. Failed requests fall back to cached data and mark it accordingly. Without cached data, the interface shows an empty error state. Sample rates are used only in widget previews and the separate debug screenshot mode.

Amount presets use the nearest power of ten to the number of currency units per euro. A euro reference is reused or fetched alongside comparison rates without adding it to the visible selection. Cached rates work offline, including the inverse direction; without a reference the app uses a default scale, with yen and won starting at 100 and 1,000 respectively.

Changes in the app request a widget refresh. Amount edits are briefly debounced and published immediately when the app leaves the foreground. The widget also requests a new timeline after four hours, or after thirty minutes when an error occurs. iOS determines the actual refresh time.

## Project structure

- `Currency/`: SwiftUI views, observable application state, and the mental-conversion rule generator. Worked examples use the saved amount, visible intermediate values and curved operation arrows; a compact sketch uses handwritten figures and short curved arrows beside the intermediate amounts. Useful rules are remembered while their reference error stays within 3%.
- `Currency/Resources/Fonts/`: Patrick Hand supplies the handwriting used only in mental-conversion sketches. Its SIL Open Font License and attribution are included with the app.
- `Currency/AppIcon.icon`: A layered Icon Composer document included directly in Xcode, with separate coin and currency symbol layers. Apple's Icon Composer supplies lighting, materials, and system appearances; dark mode uses a separate high-contrast symbol fill.
- `Currency/AppIcons/`: Alternate layered Icon Composer documents for the standard Apple colors. `Currency/Appearance.xcassets` contains light and dark previews rendered by Icon Composer for the Settings banner.
- `Design/Icon/`: SVG source layers and a Swift script that regenerates the vector paths. Run `swift Design/Icon/generate.swift Currency/AppIcon.icon/Assets` with the document closed in Icon Composer. The euro symbol is optically aligned using its rounded bowl; the adjustment is preserved in the generator. After editing the original icon, run `python3 Design/Icon/generate-color-variants.py` and `python3 Design/Icon/render-previews.py` to regenerate color variants and their previews. The renderer uses the Icon Composer included with the selected Xcode installation.
- `Shared/`: API client, models, settings, and cache compiled into both the app and widget.
- `Shared/Assets.xcassets`: The original terracotta accent with adjusted brightness in dark mode. `Shared/AppAccent.swift` maps appearance choices to native SwiftUI colors. Backgrounds and cards use native semantic system colors; the selected color applies to icons, controls, and charts. Icon variants use the [Apple system color palette](https://developer.apple.com/design/human-interface-guidelines/color); the app uses dynamic system colors at runtime.
- `CurrencyWidget/`: A static widget configuration using the app's selection and a timeline provider.
- `CurrencyTests/`: HTTP fixtures and tests for decoding, history requests, error handling, caching, and widget deep links.
- `CurrencyScreenshotTests/`: Native UI tests for the automated screenshot gallery.

## Experiments

The [mental currency conversion experiment](docs/mental-math.md) evaluates automatically generated rules for mental arithmetic across 870 currency conversions. Its conservative revision excludes unfamiliar fractions and counts the work behind percentage corrections. The [scientific evidence note](docs/mental-arithmetic-evidence.md) distinguishes experimental findings from the generator's design assumptions. An offline interactive prototype lives on a separate branch. The app now uses a Swift implementation of the accepted vocabulary and relative weights. Its detail view shows a worked example without exposing scores or technical explanations. The production search limits examples to four arithmetic actions, four displayed steps and six effort points; those limits are design heuristics, not measured human thresholds.

## Testing

### Automated screenshots

The [GitHub workflow](.github/workflows/screenshots.yml) captures screenshots when app code, translations, documentation, or screenshot scripts change on `main` or in a pull request. You can also start it from **Actions → App screenshots → Run workflow**. On the default branch, original PNGs and small JPEG previews are published directly from the build artifact to [GitHub Pages](https://leongeorgi.github.io/currency/). The workflow has no Git write permission and creates no commits. The README uses stable external URLs whose contents update after each successful deployment. Pull requests provide a downloadable `screenshot-gallery` workflow artifact; native test results are attached as well.

The gallery covers the overview, mental conversion, history, editing, and dark mode overview in all five languages on an iPhone 17. English screenshots lead the README, followed by an overview in each other language. Generated files live only in the ignored `build/Screenshots/Site/` directory: `screenshots/originals/` holds unchanged simulator PNGs, and `screenshots/previews/` holds JPEGs resized to 320 pixels wide. The README embeds nine small previews and links to all twenty-five originals. The published [screenshots/manifest.json](https://leongeorgi.github.io/currency/screenshots/manifest.json) records image dimensions and file sizes. The Pages home page displays the complete gallery.

Run locally with Xcode 26 or later:

```sh
bash scripts/screenshots.sh
```

The script creates and removes its own simulator, uses fixed sample data, and leaves the normal app's saved amounts, currency lists, and widget settings untouched. Screenshot mode is available only in debug builds. Dates and times are fixed so images change only when relevant content changes. System notification banners are dismissed and checked both before and after each capture; obscured images are not published. UI tests use the separate **Screenshots** scheme; unit tests remain in the **Currency** scheme.

GitHub Pages must be enabled once under **Settings → Pages → Source → GitHub Actions**; this repository is already configured. The publish job uses the built-in `GITHUB_TOKEN` with `pages: write`, `id-token: write`, and read-only repository access. No additional secrets or separate Git branch are required. Pull requests do not publish a public gallery, and runs for outdated commits skip deployment.

Regenerate the README links explicitly only when the gallery structure or host changes:

```sh
python3 scripts/publish-screenshots.py --update-readme
```

For a fork with its own Pages address, add `--base-url https://OWNER.github.io/REPOSITORY`. Previously committed screenshots remain in older Git commits; the current pipeline adds no further image versions to the repository.

### Validation performed

The app build and forty unit tests have passed with Xcode 27 on an iPhone 17 simulator running iOS 27. The deployment target is iOS 26; testing on a physical iOS 26 device is still pending.

Appearance checks cover color selection, the icon preview, alternate Home Screen icons, and persistence after relaunch. All five localizations have been checked in the simulator, including number, date, and currency formatting. Compiler-extracted interface text, placeholders, and compiled language resources have been checked in both the app and widget.

Use **⌘U** in Xcode to run the unit tests. They use local HTTP fixtures and require no network connection. Additional simulator checks cover live Frankfurter requests, multiple comparison currencies, changing the base currency, amount persistence after restarting the app, history navigation, ten-year charts, the saved zero baseline setting, flags, reordering and deletion, order persistence, synchronization of the first three widget currencies, and opening the app from a widget without losing other comparisons. Light and dark appearances have been inspected. The interface uses native SwiftUI layouts and buttons, semantic system backgrounds, and Dynamic Type.
