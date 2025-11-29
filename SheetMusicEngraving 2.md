# Sheet Music Engraving Research

## Overview

This document captures research on integrating sheet music rendering capabilities into the maistro iOS app.

## Options Evaluated

### 1. VexFlow (JavaScript) - SELECTED

**Website:** https://www.vexflow.com/
**GitHub:** https://github.com/0xfe/vexflow

VexFlow is a JavaScript library for rendering music notation using the HTML5 Canvas API.

**Integration approach:** Embed in `WKWebView`

**Pros:**
- Easier integration - load HTML/JS in a WebView
- Active development, good documentation
- Proven iOS integration via [OpenSheetMusicDisplay-Swift-Example](https://github.com/massimobio/OpenSheetMusicDisplay-Swift-Example)
- Supports MusicXML via OpenSheetMusicDisplay wrapper

**Cons:**
- WebView overhead
- Requires JS-Swift bridge for bidirectional communication
- Must bundle JS files locally (CDN loading has issues in WKWebView)

**Key Implementation Notes:**
- Use `WKWebView` (not deprecated `UIWebView`)
- Bundle vexflow JS files locally - CDN loading is unreliable
- Use `evaluateJavaScript()` for Swift -> JS communication
- Use `WKScriptMessageHandler` for JS -> Swift communication

### 2. Guido (C++) - NOT SELECTED

**Website:** https://guido.grame.fr/
**GitHub:** https://github.com/grame-cncm/guidolib

GuidoLib is a C++ music score layout engine that officially supports iOS.

**Integration approach:** Objective-C++ bridging layer

**Pros:**
- True native performance
- Real-time rendering capability
- No WebView overhead

**Cons:**
- Significant integration work required
- C++/Objective-C++ bridging complexity
- Larger binary size

**Why not selected:** Higher implementation complexity for initial version. Could revisit if performance becomes an issue.

### 3. music-notation-swift - NOT VIABLE

**GitHub:** https://codeberg.org/music-notation-swift/music-notation

Native Swift library for music notation modeling.

**Status:** Does not include rendering - model layer only. The `music-notation-render` package is incomplete.

## Implementation

### Files Created

```
maistro/
├── Views/SheetMusic/
│   └── SheetMusicWebView.swift    # SwiftUI wrapper for VexFlow
└── Resources/VexFlow/
    ├── vexflow.js                  # VexFlow 4.2.5 library
    └── vexflow-sheet.html          # HTML template for rendering
```

### Xcode Setup Required

**IMPORTANT:** You must add the VexFlow resources to your Xcode project:

1. In Xcode, right-click on the `maistro` folder in the Project Navigator
2. Select "Add Files to 'maistro'..."
3. Navigate to `maistro/Resources/VexFlow`
4. Select the `VexFlow` folder
5. Ensure "Copy items if needed" is **unchecked** (files are already in place)
6. Ensure "Create folder references" is **selected** (blue folder icon)
7. Click "Add"

This ensures the HTML and JS files are bundled with the app and accessible at runtime.

### Usage

```swift
import SwiftUI

struct MyView: View {
    var body: some View {
        SheetMusicView(
            notation: "C4/q, D4/q, E4/q, F4/q",
            label: "Target",
            width: 300,
            height: 120
        )
        .environmentObject(ThemeManager.shared)
    }
}
```

### Notation Format

Notes are specified as comma-separated values: `{pitch}{accidental?}{octave}/{duration}`

**Pitches:** C, D, E, F, G, A, B
**Accidentals:** # (sharp), b (flat), n (natural)
**Octaves:** 0-9 (middle C = C4)
**Durations:** w (whole), h (half), q (quarter), 8 (eighth), 16 (sixteenth)

**Examples:**
- `C4/q` - Quarter note middle C
- `F#5/h` - Half note F# in octave 5
- `Bb3/8` - Eighth note B-flat in octave 3
- `C4/q, D4/q, E4/q, F4/q` - C major scale quarter notes

### Phase 2: Future Enhancements

1. Implement JS -> Swift callbacks for user interaction
2. Add support for MusicXML import (via OpenSheetMusicDisplay)
3. Theming/styling to match app design
4. Support for rests, ties, and other notation elements

## Resources

- [VexFlow Documentation](https://github.com/0xfe/vexflow/wiki)
- [VexFlow iOS Issue #777](https://github.com/0xfe/vexflow/issues/777)
- [OpenSheetMusicDisplay Swift Example](https://github.com/massimobio/OpenSheetMusicDisplay-Swift-Example)
- [WKWebView Apple Docs](https://developer.apple.com/documentation/webkit/wkwebview)
- [iOS WKWebView JS-Swift Communication](https://medium.com/john-lewis-software-engineering/ios-wkwebview-communication-using-javascript-and-swift-ee077e0127eb)
