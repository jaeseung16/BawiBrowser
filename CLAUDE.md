# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

BawiBrowser is a macOS SwiftUI companion app for 천년바위 (https://www.bawi.org). It wraps the site in a `WKWebView` and intercepts what the user posts (articles, comments, notes) to store a local backup in Core Data, synced via iCloud/CloudKit. It also ships a Safari app extension (`BawiBrowserSafariExtension`) that does the same interception inside Safari.

## Build & Test

There is one Xcode project (`BawiBrowser.xcodeproj`) with a single scheme, `BawiBrowser`. Dependencies are Swift Package Manager packages resolved by Xcode (MultipartKit, jaeseung16/PersistenceSwift, swift-nio).

```sh
# Build (Debug)
xcodebuild -scheme BawiBrowser -configuration Debug build

# Run all unit tests
xcodebuild test -scheme BawiBrowser -destination 'platform=macOS' -only-testing:BawiBrowserTests

# Run a single test
xcodebuild test -scheme BawiBrowser -destination 'platform=macOS' \
  -only-testing:BawiBrowserTests/BawiBrowserTests/testMultiPartFormWithImage
```

Test coverage is minimal: `BawiBrowserTests` mainly verifies multipart form decoding against the fixture `BawiBrowserTests/multipartFormWithImage`. `BawiBrowserUITests` and `BawiBrowserUIPerformanceTests` are template UI/launch tests.

## Architecture

### Request interception (the core mechanism)

The app never talks to a bawi.org API — it observes the browser's own HTTP traffic:

1. `Views/WebView.swift` (an `NSViewRepresentable` around `WKWebView`) implements `decidePolicyFor navigationAction` in its `Coordinator`. Every POST is matched against `Model/BawiAction.swift`, an enum whose cases map to bawi.org CGI endpoints (`note.cgi`, `comment.cgi`, `write.cgi`, `edit.cgi`, `login.cgi`, ...).
2. The matched request body is handed to `BawiBrowserViewModel` (`processNote`, `processComment`, `processEdit`, `processCredentials`), which parses it — URL-encoded bodies via `URLComponents`, multipart bodies via MultipartKit's `FormDataDecoder` into `Model/BawiWriteForm.swift` — and saves DTOs (`BawiArticleDTO`, `BawiCommentDTO`, `BawiNoteDTO`) through `PersistenceHelper`.
3. **New articles are a two-phase save**: the article id doesn't exist yet at POST time, so `preprocessWrite` builds a `BawiArticleDTO` held on the `Coordinator`, and `didFinish` navigation later extracts the assigned `aid` from the redirect URL before calling `saveArticle`.

The Coordinator also scrapes page context (board title, article title) with `evaluateJavaScript` in `didFinish`, and triggers login autofill from Keychain credentials (`LoginAutofill.js` + `Model/KeyChainHelper.swift`, opt-in via the `BawiBrowser.useKeychain` setting).

### Central view model

`Model/BawiBrowserViewModel.swift` is a single `@MainActor ObservableObject` created in `AppDelegate` and injected everywhere as an `EnvironmentObject`. It owns persistence, Spotlight indexing (`SearchHelper`), Keychain access, published entity arrays (`articles`, `comments`, `notes`), tab selection, and browser navigation commands (`BawiBrowserNavigation` enum consumed by `WebView.updateNSView`).

### Persistence & sync

- Core Data + CloudKit is wrapped by the external `Persistence` package (github.com/jaeseung16/PersistenceSwift), configured in `AppDelegate` with the app name and iCloud container id from `BawiBrowserConstants`.
- Entities (`Article`, `Attachment`, `Comment`, `Note`) live in `BawiBrowser.xcdatamodeld` with class codegen — there are no hand-written `NSManagedObject` subclasses.
- `NSPersistentStoreRemoteChange` notifications drive re-indexing of changed objects into Core Spotlight.
- `AppDelegate` also subscribes to CloudKit database changes for `CD_Article` records and posts local user notifications when a new article arrives from another device; tapping one navigates to that article.

### Search (two distinct paths)

`ContentView`'s `.searchable` field switches behavior by tab: on the browser tab, the search string is piped into JavaScript injected by `UIWebViewSearch.js` (highlight/scroll in the web page); on the Articles/Comments/Notes tabs it runs a Core Spotlight query via `SearchHelper` and re-fetches matching Core Data objects.

### Safari extension

`BawiBrowserSafariExtension/Resources/script.js` is a content script that dispatches messages (`writeForm`, `commentForm`, `noteForm`, `attach1`–`attach10`) to `SafariExtensionHandler`. Handlers created by `MessageHandlerFactory` (`Handlers/`) persist through `SafariExtensionPersister`, an actor with its own instance of the same Persistence/CloudKit stack. Article saving is again two-phase: the form message stores a pending `BawiArticleDTO`, and a later message from `read.cgi` supplies the article id. The extension reuses the main app's DTO and constant files directly (they're compiled into both targets).

### UI

`ContentView` is a four-tab `TabView` (Bawi browser / Articles / Comments / Notes) bound to `viewModel.selectedTab`. List/detail views live under `Views/Article`, `Views/Comment`, `Views/Note`. Dark mode for the web view is a user setting (`BawiBrowser.appearance`).

## Notes

- Mermaid architecture diagrams live in `docs/diagrams/` (views, view model, sequence flows).
- Korean text in fixtures, UI, and site content is expected — the target site is Korean.

### Work log

After completing each step or major task, append a summary of it to docs/worklog/YYYY-MM-DD-<topic>.md in this repo (create the file if it does not exist), in addition to reporting the summary in the conversation.
