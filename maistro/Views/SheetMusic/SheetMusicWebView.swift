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

    func makeCoordinator() -> Coordinator {
        Coordinator(notation: notation, width: width, height: height)
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

        if context.coordinator.isLoaded {
            context.coordinator.renderNotation(webView: webView)
        }
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var notation: String
        var width: CGFloat
        var height: CGFloat
        var isLoaded = false

        init(notation: String, width: CGFloat, height: CGFloat) {
            self.notation = notation
            self.width = width
            self.height = height
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

            let js = "renderNotation(\"\(escapedNotation)\", \(width), \(height));"
            print("[VexFlow] Executing JS: \(js.prefix(100))...")

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

    init(notation: String, label: String? = nil, width: CGFloat = 300, height: CGFloat = 120) {
        self.notation = notation
        self.label = label
        self.width = width
        self.height = height
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

            SheetMusicWebView(notation: notation, width: width, height: height)
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
    SheetMusicView(
        notation: "C4/q, D4/q, E4/q, F4/q",
        label: "Target",
        width: 300,
        height: 120
    )
    .environmentObject(ThemeManager.shared)
}
