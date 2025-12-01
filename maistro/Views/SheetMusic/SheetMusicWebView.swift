//
//  SheetMusicWebView.swift
//  maistro
//

import SwiftUI
import WebKit

struct SheetMusicWebView: UIViewRepresentable {
    let notation: String
    let width: CGFloat
    let height: CGFloat
    let timeSignature: String

    init(notation: String, width: CGFloat, height: CGFloat, timeSignature: String) {
        self.notation = notation
        self.width = width
        self.height = height
        self.timeSignature = timeSignature
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(notation: notation, width: width, height: height, timeSignature: timeSignature)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.javaScriptEnabled = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.navigationDelegate = context.coordinator

        context.coordinator.loadVexFlowHTML(webView: webView)

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.notation = notation
        context.coordinator.width = width
        context.coordinator.height = height
        context.coordinator.timeSignature = timeSignature

        if context.coordinator.isLoaded {
            context.coordinator.renderNotation(webView: webView)
        }
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var notation: String
        var width: CGFloat
        var height: CGFloat
        var timeSignature: String
        var isLoaded = false

        init(notation: String, width: CGFloat, height: CGFloat, timeSignature: String) {
            self.notation = notation
            self.width = width
            self.height = height
            self.timeSignature = timeSignature
        }

        func loadVexFlowHTML(webView: WKWebView) {
            // Debug: List bundle contents to help diagnose
            print("[VexFlow] Bundle path: \(Bundle.main.bundlePath)")

            // Try multiple approaches to find the HTML file
            var htmlURL: URL?
            var baseURL: URL?

            // Approach 1: Folder reference (VexFlow directory)
            if let path = Bundle.main.path(forResource: "vexflow-sheet", ofType: "html", inDirectory: "VexFlow") {
                print("[VexFlow] Found via folder reference at: \(path)")
                htmlURL = URL(fileURLWithPath: path)
                baseURL = Bundle.main.bundleURL.appendingPathComponent("VexFlow")
            }
            // Approach 2: Flat structure (files added as group)
            else if let url = Bundle.main.url(forResource: "vexflow-sheet", withExtension: "html") {
                print("[VexFlow] Found via flat structure at: \(url)")
                htmlURL = url
                baseURL = url.deletingLastPathComponent()
            }
            // Approach 3: Search in Resources subdirectory
            else if let path = Bundle.main.path(forResource: "vexflow-sheet", ofType: "html", inDirectory: "Resources/VexFlow") {
                print("[VexFlow] Found via Resources/VexFlow at: \(path)")
                htmlURL = URL(fileURLWithPath: path)
                baseURL = Bundle.main.bundleURL.appendingPathComponent("Resources/VexFlow")
            }

            // If still not found, print diagnostic info
            guard let finalHTMLURL = htmlURL, let finalBaseURL = baseURL else {
                print("[VexFlow] ERROR: Could not locate vexflow-sheet.html")
                print("[VexFlow] Searching for any .html files in bundle...")

                if let resourcePath = Bundle.main.resourcePath {
                    let fileManager = FileManager.default
                    if let enumerator = fileManager.enumerator(atPath: resourcePath) {
                        while let file = enumerator.nextObject() as? String {
                            if file.hasSuffix(".html") || file.contains("vexflow") || file.contains("VexFlow") {
                                print("[VexFlow]   Found: \(file)")
                            }
                        }
                    }
                }

                print("[VexFlow] Make sure to add VexFlow folder to Xcode:")
                print("[VexFlow]   1. Right-click maistro folder in Xcode")
                print("[VexFlow]   2. Add Files to 'maistro'...")
                print("[VexFlow]   3. Select VexFlow folder")
                print("[VexFlow]   4. Choose 'Create folder references' (blue folder)")
                return
            }

            // Load the HTML content
            do {
                let htmlContent = try String(contentsOf: finalHTMLURL, encoding: .utf8)
                print("[VexFlow] Successfully loaded HTML (\(htmlContent.count) chars)")
                print("[VexFlow] Base URL: \(finalBaseURL)")
                webView.loadHTMLString(htmlContent, baseURL: finalBaseURL)
            } catch {
                print("[VexFlow] ERROR reading HTML file: \(error)")
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("[VexFlow] WebView finished loading")
            isLoaded = true
            renderNotation(webView: webView)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("[VexFlow] WebView navigation failed: \(error)")
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("[VexFlow] WebView provisional navigation failed: \(error)")
        }

        func renderNotation(webView: WKWebView) {
            let escapedNotation = notation
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\n", with: "\\n")

            let js = "renderNotation(\"\(escapedNotation)\", \(width), \(height), \"\(timeSignature)\");"
            print("[VexFlow] Executing JS: \(js.prefix(120))...")

            webView.evaluateJavaScript(js) { result, error in
                if let error = error {
                    print("[VexFlow] JS render error: \(error)")
                } else {
                    print("[VexFlow] JS render success, result: \(String(describing: result))")
                }
            }
        }
    }
}

// MARK: - SheetMusicView

struct SheetMusicView: View {
    @EnvironmentObject var themeManager: ThemeManager

    let notation: String
    let label: String?
    let width: CGFloat
    let height: CGFloat
    let timeSignature: String

    // Layout constants matching the JavaScript
    private static let firstMeasureAdditionalWidth: CGFloat = 50
    private static let measureHeight: CGFloat = 75

    init(notation: String, label: String? = nil, width: CGFloat = 300, height: CGFloat = 120, timeSignature: String = "4/4") {
        self.notation = notation
        self.label = label
        self.width = width
        self.height = height
        self.timeSignature = timeSignature
    }

    /// Initialize with a DiscretePassage (calculates dimensions automatically)
    init(passage: DiscretePassage, label: String?, timeSignature: String) {
        // Convert passage to JSON string for JavaScript
        // Note: Do NOT use convertToSnakeCase - the JS expects camelCase (noteDurations, noteName, etc.)
        print(passage)
        let encoder = JSONEncoder()
        if let jsonData = try? encoder.encode(passage),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            self.notation = jsonString
        } else {
            self.notation = ""
        }
        print(self.notation)
        print("===============")
        self.label = label
        self.timeSignature = timeSignature

        // Calculate dimensions based on passage content
        let dimensions = Self.computeDimensions(for: passage)
        self.width = dimensions.width
        self.height = dimensions.height
    }

    /// Compute dimensions based on measure content (mirrors JavaScript logic)
    private static func computeDimensions(for passage: DiscretePassage) -> (width: CGFloat, height: CGFloat) {
        let measures = passage.measures
        guard !measures.isEmpty else {
            return (width: 300, height: 120)
        }

        // Find max glyphs in any single measure
        var maxGlyph = 0
        for measure in measures {
            var glyphsInMeasure = 0
            for element in measure.elements {
                switch element.element {
                case .note(let note):
                    glyphsInMeasure += note.noteDurations.count
                case .rest(let rest):
                    glyphsInMeasure += rest.restDurations.count
                }
            }
            maxGlyph = max(maxGlyph, glyphsInMeasure)
        }

        // Determine measure width and measures per line based on glyph density
        let measureWidth: CGFloat
        let measuresPerLine: Int
        if maxGlyph <= 8 {
            measureWidth = 190
            measuresPerLine = 3
        } else if maxGlyph <= 16 {
            measureWidth = 285
            measuresPerLine = 2
        } else {
            measureWidth = 560
            measuresPerLine = 1
        }

        // Calculate total dimensions
        let numLines = max(1, Int(ceil(Double(measures.count) / Double(measuresPerLine))))
        let measuresOnFirstLine = min(measuresPerLine, measures.count)

        let width = firstMeasureAdditionalWidth + measureWidth * CGFloat(measuresOnFirstLine) + 20
        let height = 50 + measureHeight * CGFloat(numLines)

        return (width: width, height: height)
    }

    var body: some View {
        HStack(spacing: 12) {
            if let label = label {
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(themeManager.colors.textNeutral)
                    .frame(width: 50, alignment: .leading)
            }

            SheetMusicWebView(notation: notation, width: width, height: height, timeSignature: timeSignature)
                .frame(width: width, height: height)
                .background(Color.white)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(themeManager.colors.neutralAccent, lineWidth: 1)
                )
        }
    }
}

// MARK: - Preview Placeholder (for SwiftUI Canvas)

struct SheetMusicPreviewPlaceholder: View {
    let label: String?
    let width: CGFloat
    let height: CGFloat
    let notation: String

    var body: some View {
        HStack(spacing: 12) {
            if let label = label {
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.gray)
                    .frame(width: 50, alignment: .leading)
            }

            ZStack {
                // Staff lines
                VStack(spacing: 8) {
                    ForEach(0..<5, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.gray.opacity(0.4))
                            .frame(height: 1)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 20)

                // Treble clef placeholder
                HStack {
                    Text("𝄞")
                        .font(.system(size: 40))
                        .foregroundColor(.black)
                        .padding(.leading, 8)

                    Text("4/4")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.black)

                    Spacer()

                    // Note placeholders
                    HStack(spacing: 16) {
                        ForEach(parseNotesForPreview(), id: \.self) { note in
                            NotePreview(note: note)
                        }
                    }
                    .padding(.trailing, 20)
                }
                .padding(.horizontal, 8)
            }
            .frame(width: width, height: height)
            .background(Color.white)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
    }

    private func parseNotesForPreview() -> [String] {
        notation.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
    }
}

struct NotePreview: View {
    let note: String

    var body: some View {
        VStack(spacing: 0) {
            // Note head
            Ellipse()
                .fill(Color.black)
                .frame(width: 10, height: 8)
                .rotationEffect(.degrees(-20))

            // Stem
            Rectangle()
                .fill(Color.black)
                .frame(width: 1.5, height: 30)
                .offset(x: 4, y: -15)
        }
    }
}

// MARK: - Previews

#Preview("Live WebView") {
    VStack(spacing: 20) {
        SheetMusicView(
            notation: "C4/q, D4/q, E4/q, F4/q",
            label: "Target",
            width: 300,
            height: 120
        )
        .environmentObject(ThemeManager.shared)

        SheetMusicView(
            passage: DiscretePassage.samplePassage,
            label: "Sample",
            timeSignature: "4/4"
        )
        .environmentObject(ThemeManager.shared)
    }
}

// MARK: - Sample Passage for Previews

extension DiscretePassage {
    /// A sample passage for SwiftUI previews: two measures in 4/4 with varied rhythms
    static let samplePassage: DiscretePassage = {
        // Measure 1: quarter, quarter, half
        let measure1 = DiscreteMeasure(
            subdivisionDenominator: 8,
            elements: [
                DiscreteMeasureElement(
                    element: .note(DiscreteNote(
                        noteName: "B4",
                        noteDurations: [DenominatorDots(denominator: 4, dots: 0)]
                    )),
                    startSubdivision: 0,
                    tiedFromPrevious: false
                ),
                DiscreteMeasureElement(
                    element: .note(DiscreteNote(
                        noteName: "B4",
                        noteDurations: [DenominatorDots(denominator: 4, dots: 0)]
                    )),
                    startSubdivision: 2,
                    tiedFromPrevious: false
                ),
                DiscreteMeasureElement(
                    element: .note(DiscreteNote(
                        noteName: "B4",
                        noteDurations: [DenominatorDots(denominator: 2, dots: 0)]
                    )),
                    startSubdivision: 4,
                    tiedFromPrevious: false
                )
            ]
        )

        // Measure 2: dotted quarter, eighth, quarter rest, quarter
        let measure2 = DiscreteMeasure(
            subdivisionDenominator: 8,
            elements: [
                DiscreteMeasureElement(
                    element: .note(DiscreteNote(
                        noteName: "B4",
                        noteDurations: [DenominatorDots(denominator: 4, dots: 1)]
                    )),
                    startSubdivision: 0,
                    tiedFromPrevious: false
                ),
                DiscreteMeasureElement(
                    element: .note(DiscreteNote(
                        noteName: "B4",
                        noteDurations: [DenominatorDots(denominator: 8, dots: 0)]
                    )),
                    startSubdivision: 3,
                    tiedFromPrevious: false
                ),
                DiscreteMeasureElement(
                    element: .rest(DiscreteRest(
                        restDurations: [DenominatorDots(denominator: 4, dots: 0)]
                    )),
                    startSubdivision: 4,
                    tiedFromPrevious: false
                ),
                DiscreteMeasureElement(
                    element: .note(DiscreteNote(
                        noteName: "B4",
                        noteDurations: [DenominatorDots(denominator: 4, dots: 0)]
                    )),
                    startSubdivision: 6,
                    tiedFromPrevious: false
                )
            ]
        )

        return DiscretePassage(measures: [measure1, measure2])
    }()
}
