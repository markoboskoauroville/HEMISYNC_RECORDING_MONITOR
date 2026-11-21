// Hemi-Sync Recording Monitor (Mantra): one dashboard window for the long recording job. It reads
// ~/Music/HemiSync/progress.json every 2 s (path override for tests: env HEMISYNC_PROGRESS) and shows where the job is.
// Closing the window quits the app. Compiled only by GitHub Actions (build.sh).
import AppKit
import SwiftUI

let VERSION = 1
let APP_NAME = "Hemi-Sync Recording Monitor (Mantra)"

// MARK: model (every field optional; a missing file or field never crashes)

struct Item: Identifiable {
    let id: Int
    let kind: String, name: String, status: String, note: String
    let duration: Double?
}

struct Progress {
    var updated: Date?, started: Date?
    var phase = "", state = "", message = ""
    var clipsDone: Int?, clipsTotal: Int?, clipCurrent = ""
    var albumsDone: Int?, albumsTotal: Int?
    var album = "", track = "", trackIndex: Int?, trackCount: Int?, trackElapsed: Double?, trackLength: Double?
    var remaining: Double?
    var items: [Item] = []
}

func parseDate(_ s: String) -> Date? {
    let a = ISO8601DateFormatter(); a.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = a.date(from: s) { return d }
    let b = ISO8601DateFormatter(); b.formatOptions = [.withInternetDateTime]
    if let d = b.date(from: s) { return d }
    for f in ["yyyy-MM-dd'T'HH:mm:ss.SSSSSS", "yyyy-MM-dd'T'HH:mm:ss"] {      // no zone: local time
        let df = DateFormatter(); df.locale = Locale(identifier: "en_US_POSIX"); df.dateFormat = f
        if let d = df.date(from: s) { return d }
    }
    return nil
}

func num(_ v: Any?) -> Double? { (v as? NSNumber)?.doubleValue }
func int(_ v: Any?) -> Int? { (v as? NSNumber)?.intValue }
func str(_ v: Any?) -> String { (v as? String) ?? "" }

func loadProgress(_ url: URL) -> Progress? {
    guard let data = try? Data(contentsOf: url),
          let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
    var p = Progress()
    p.updated = (j["updated"] as? String).flatMap(parseDate)
    p.started = (j["started"] as? String).flatMap(parseDate)
    p.phase = str(j["phase"]); p.state = str(j["state"]); p.message = str(j["message"])
    if let c = j["clips"] as? [String: Any] {
        p.clipsDone = int(c["done"]); p.clipsTotal = int(c["total"]); p.clipCurrent = str(c["current"])
    }
    if let a = j["albums"] as? [String: Any] {
        p.albumsDone = int(a["done"]); p.albumsTotal = int(a["total"])
        p.album = str(a["current_album"]); p.track = str(a["current_track"])
        p.trackIndex = int(a["track_index"]); p.trackCount = int(a["track_count"])
        p.trackElapsed = num(a["track_elapsed_s"]); p.trackLength = num(a["track_length_s"])
    }
    p.remaining = num(j["remaining_s"])
    if let arr = j["items"] as? [[String: Any]] {
        p.items = arr.enumerated().map { i, d in
            Item(id: i, kind: str(d["kind"]), name: str(d["name"]), status: str(d["status"]), note: str(d["note"]), duration: num(d["duration_s"]))
        }
    }
    return p
}

// MARK: formatting

func hm(_ s: Double) -> String {
    let t = Int(max(0, s).rounded())
    let h = t / 3600, m = (t % 3600) / 60
    if h > 0 { return "\(h) h \(m) min" }
    if m > 0 { return "\(m) min" }
    return "\(t) s"
}
func clock(_ s: Double) -> String {
    let t = Int(max(0, s).rounded()); return String(format: "%d:%02d", t / 60, t % 60)
}
func ago(_ s: Double) -> String {
    let t = Int(max(0, s))
    if t < 60 { return "\(t) s ago" }
    if t < 3600 { return "\(t / 60) min \(t % 60) s ago" }
    return "\(t / 3600) h \((t % 3600) / 60) min ago"
}
func words(_ s: String) -> String {
    switch s {
    case "clips": return "Recording the clips"
    case "albums": return "Recording the albums"
    case "done": return "All done"
    case "error": return "Error"
    case "navigating": return "Navigating"
    case "downloading": return "Downloading"
    case "recording": return "Recording"
    case "encoding": return "Encoding"
    case "checking": return "Checking"
    case "idle": return "Idle"
    default: return s.isEmpty ? "" : s.prefix(1).uppercased() + s.dropFirst()
    }
}

// MARK: store

final class Store: ObservableObject {
    @Published var progress: Progress?
    @Published var now = Date()
    @Published var exists = false
    let url: URL
    var timer: Timer?
    var tick = 0

    init() {
        if let o = ProcessInfo.processInfo.environment["HEMISYNC_PROGRESS"], !o.isEmpty {
            url = URL(fileURLWithPath: (o as NSString).expandingTildeInPath)
        } else {
            url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Music/HemiSync/progress.json")
        }
        reload()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let s = self else { return }
            s.now = Date(); s.tick += 1
            if s.tick % 2 == 0 { s.reload() }
        }
    }
    func reload() {
        exists = FileManager.default.fileExists(atPath: url.path)
        progress = loadProgress(url)
    }
}

// MARK: design (TRAIL: dark ground, amber warning, green done; colour is the state channel)

enum Look {
    static let bg = Color(red: 0.043, green: 0.047, blue: 0.055)
    static let panel = Color(red: 0.11, green: 0.125, blue: 0.145)
    static let text = Color(red: 0.93, green: 0.94, blue: 0.95)
    static let dim = Color(red: 0.62, green: 0.65, blue: 0.69)
    static let amber = Color(red: 0.91, green: 0.64, blue: 0.24)
    static let green = Color(red: 0.2, green: 0.82, blue: 0.48)
    static let red = Color(red: 1, green: 0.23, blue: 0.19)
}

struct Hairline: View { var body: some View { Rectangle().fill(Look.panel).frame(height: 1) } }

struct Bar: View {
    let label: String, done: Int?, total: Int?
    var body: some View {
        let d = done ?? 0, t = total ?? 0
        VStack(alignment: .leading, spacing: 6) {
            Text(total == nil ? "\(label)  –" : "\(label) \(d) / \(t)")
                .font(.system(size: 20, weight: .semibold)).foregroundColor(Look.text)
                .fixedSize(horizontal: false, vertical: true)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6).fill(Look.panel)
                    RoundedRectangle(cornerRadius: 6).fill(Look.green)
                        .frame(width: t > 0 ? g.size.width * CGFloat(min(1, Double(d) / Double(t))) : 0)
                }
            }.frame(height: 14)
        }
    }
}

func mark(_ status: String) -> (String, Color) {
    switch status {
    case "done": return ("✓", Look.green)
    case "active": return ("●", Look.amber)
    case "failed": return ("✕", Look.red)
    case "swapped": return ("↺", Look.amber)
    default: return ("○", Look.dim)
    }
}

struct Root: View {
    @ObservedObject var store: Store
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(APP_NAME).font(.system(size: 13, weight: .medium)).foregroundColor(Look.dim)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24).padding(.top, 14).padding(.bottom, 10)
            Hairline()
            if let p = store.progress, p.updated != nil, !p.phase.isEmpty, !p.state.isEmpty {
                ScrollView { Dashboard(p: p, now: store.now).padding(24) }
            } else {
                VStack { Spacer()
                    Text("Waiting for the recorder…").font(.system(size: 26, weight: .semibold)).foregroundColor(Look.dim)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(store.url.path).font(.system(size: 12)).foregroundColor(Look.dim).padding(.top, 6)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer() }.frame(maxWidth: .infinity)
            }
            Hairline()
            HStack {
                Spacer()
                Button(action: openFolder) {
                    Text("Open folder").font(.system(size: 15, weight: .semibold)).foregroundColor(Color.black)
                        .padding(.horizontal, 18).padding(.vertical, 8)
                        .fixedSize(horizontal: false, vertical: true)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Look.amber))
                }.buttonStyle(.plain).accessibilityLabel("Open folder")
            }.padding(.horizontal, 24).padding(.vertical, 12)
        }
        .background(Look.bg)
    }
    func openFolder() {
        let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Music/HemiSync")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        NSWorkspace.shared.open(dir)
    }
}

struct Dashboard: View {
    let p: Progress, now: Date
    var body: some View {
        let age = p.updated.map { now.timeIntervalSince($0) }
        let silent = (age ?? 0) > 120
        let phaseColor: Color = p.phase == "error" || p.state == "error" ? Look.red : (p.phase == "done" ? Look.green : Look.text)
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text([words(p.phase), words(p.state)].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.system(size: 28, weight: .bold)).foregroundColor(phaseColor)
                    .fixedSize(horizontal: false, vertical: true)
                if !p.message.isEmpty {
                    Text(p.message).font(.system(size: 16)).foregroundColor(Look.dim)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Bar(label: "Clips", done: p.clipsDone, total: p.clipsTotal)
            Bar(label: "Albums", done: p.albumsDone, total: p.albumsTotal)
            current
            Hairline()
            timeBlock
            if let a = age {
                Text(silent ? "Last update \(ago(a)) · Recorder silent?" : "Last update \(ago(a))")
                    .font(.system(size: 16, weight: silent ? .bold : .regular)).foregroundColor(silent ? Look.amber : Look.dim)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !p.items.isEmpty {
                Hairline()
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(p.items) { it in row(it) }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder var current: some View {
        let hasAlbum = !p.album.isEmpty || !p.track.isEmpty
        VStack(alignment: .leading, spacing: 4) {
            if hasAlbum {
                Text("Album: \(p.album.isEmpty ? "–" : p.album)").font(.system(size: 16)).foregroundColor(Look.text)
                    .fixedSize(horizontal: false, vertical: true)
                let position = p.trackIndex.flatMap { index in
                    p.trackCount.map { "  (\(index) of \($0))" }
                } ?? ""
                let t = "Track: \(p.track.isEmpty ? "–" : p.track)" + position
                Text(t).font(.system(size: 16)).foregroundColor(Look.text)
                    .fixedSize(horizontal: false, vertical: true)
                if let e = p.trackElapsed, let l = p.trackLength, l > 0 {
                    Text("\(clock(e)) / \(clock(l))").font(.system(size: 16, weight: .semibold)).foregroundColor(Look.text)
                        .fixedSize(horizontal: false, vertical: true)
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4).fill(Look.panel)
                            RoundedRectangle(cornerRadius: 4).fill(Look.amber).frame(width: g.size.width * CGFloat(min(1, e / l)))
                        }
                    }.frame(height: 8)
                }
            }
            if !p.clipCurrent.isEmpty && p.phase != "albums" {
                Text("Clip: \(p.clipCurrent)").font(.system(size: 16)).foregroundColor(Look.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    var timeBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let r = p.remaining {
                Text("Time left: \(hm(r))").font(.system(size: 38, weight: .bold)).foregroundColor(Look.text)
                    .fixedSize(horizontal: false, vertical: true)
                let base = p.updated ?? now
                Text("Finishes about \(Self.hhmm(base.addingTimeInterval(r)))")
                    .font(.system(size: 26, weight: .semibold)).foregroundColor(Look.amber)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Time left: –").font(.system(size: 38, weight: .bold)).foregroundColor(Look.dim)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let s = p.started {
                Text("Elapsed: \(hm(now.timeIntervalSince(s)))").font(.system(size: 18)).foregroundColor(Look.dim)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    static func hhmm(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; f.timeZone = .current
        let cal = Calendar.current
        return cal.isDateInToday(d) ? f.string(from: d) : { let g = DateFormatter(); g.dateFormat = "EEE HH:mm"; return g.string(from: d) }()
    }

    func row(_ it: Item) -> some View {
        let (m, c) = mark(it.status)
        return HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(m).font(.system(size: 18, weight: .bold)).foregroundColor(c).frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(it.name.isEmpty ? "(unnamed)" : it.name)
                    .font(.system(size: 16, weight: it.status == "active" ? .bold : .regular))
                    .foregroundColor(it.status == "pending" ? Look.dim : Look.text)
                    .fixedSize(horizontal: false, vertical: true)
                let sub = [it.kind, it.duration.map { hm($0) } ?? "", it.note].filter { !$0.isEmpty }.joined(separator: " · ")
                if !sub.isEmpty {
                    Text(sub).font(.system(size: 13)).foregroundColor(Look.dim).fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: app

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var window: NSWindow?
    let store = Store()

    func applicationDidFinishLaunching(_ n: Notification) {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 780),
                         styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                         backing: .buffered, defer: false)
        w.title = APP_NAME
        w.titleVisibility = .hidden
        w.titlebarAppearsTransparent = true
        w.tabbingMode = .disallowed
        w.isReleasedWhenClosed = false
        w.isRestorable = false
        w.backgroundColor = NSColor(red: 0.043, green: 0.047, blue: 0.055, alpha: 1)
        w.contentMinSize = NSSize(width: 380, height: 420)
        let host = NSHostingView(rootView: Root(store: store))
        host.sizingOptions = []
        w.contentView = host
        w.delegate = self
        w.setFrameAutosaveName("HemiSyncRecordingMonitorMain")
        window = w
        enforceOneTitle(w)
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.async { self.enforceOneTitle(w) }
        Updater.checkAtStart()
    }

    /// ONE TITLE ONLY (MANTRA_MANIFEST modules/one-title-only.md): the app draws its own title; the system title stays hidden.
    func enforceOneTitle(_ w: NSWindow? = nil) {
        guard let w = w ?? window else { return }
        w.title = APP_NAME
        w.titleVisibility = .hidden
        w.titlebarAppearsTransparent = true
        func walk(_ v: NSView) {
            if v === w.contentView { return }
            if let t = v as? NSTextField, t.stringValue == APP_NAME { t.isHidden = true; t.alphaValue = 0 }
            v.subviews.forEach(walk)
        }
        if let frame = w.contentView?.superview { walk(frame) }
    }
    func windowDidBecomeKey(_ n: Notification) { enforceOneTitle() }
    func windowDidResignKey(_ n: Notification) { enforceOneTitle() }
    func windowDidResize(_ n: Notification) { enforceOneTitle() }
    func windowDidEnterFullScreen(_ n: Notification) { enforceOneTitle() }
    func windowDidExitFullScreen(_ n: Notification) { enforceOneTitle() }

    // No ON/OFF button: the window's X quits the app.
    func applicationShouldTerminateAfterLastWindowClosed(_ s: NSApplication) -> Bool { true }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
