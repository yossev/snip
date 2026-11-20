import SwiftUI
import AppKit

struct Snippet: Codable, Identifiable, Hashable {
    var id = UUID()
    var trigger: String
    var text: String
}

let marker: Int64 = 0x534E4950 // tags the keys Snip types itself, so it ignores them

// MARK: - Engine: watches typing, expands triggers

final class Engine: ObservableObject {
    @Published var snippets: [Snippet] {
        didSet { UserDefaults.standard.set(try? JSONEncoder().encode(snippets), forKey: "snippets") }
    }
    @Published var enabled: Bool { didSet { UserDefaults.standard.set(enabled, forKey: "enabled") } }
    @Published var trusted = false
    var tap: CFMachPort?
    private var buffer = ""
    private var poll: Timer?

    init() {
        let d = UserDefaults.standard
        snippets = d.data(forKey: "snippets").flatMap { try? JSONDecoder().decode([Snippet].self, from: $0) } ?? [
            Snippet(trigger: ";sig", text: "Best regards,\nYour Name"),
            Snippet(trigger: ";thx", text: "Thanks a lot!\n\nBest regards,\nYour Name"),
            Snippet(trigger: ";shrug", text: "¯\\_(ツ)_/¯"),
        ]
        enabled = d.object(forKey: "enabled") as? Bool ?? true
        DispatchQueue.main.async { self.start() }
    }

    func start() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        trusted = AXIsProcessTrustedWithOptions(opts)
        if trusted { install(); return }
        // Wait for the user to grant Accessibility, then start.
        poll = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] t in
            guard AXIsProcessTrusted() else { return }
            t.invalidate(); self?.trusted = true; self?.install()
        }
    }

    private func install() {
        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.leftMouseDown.rawValue) | (1 << CGEventType.rightMouseDown.rawValue)
        guard let t = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                        eventsOfInterest: mask, callback: onEvent, userInfo: nil) else { return }
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, t, 0), .commonModes)
        CGEvent.tapEnable(tap: t, enable: true)
        tap = t
    }

    func handle(_ type: CGEventType, _ e: CGEvent) {
        guard enabled, e.getIntegerValueField(.eventSourceUserData) != marker else { return }
        guard type == .keyDown, !e.flags.contains(.maskCommand), !e.flags.contains(.maskControl) else { buffer = ""; return }
        let code = e.getIntegerValueField(.keyboardEventKeycode)
        if code == 51 { if !buffer.isEmpty { buffer.removeLast() }; return }          // backspace
        if [36, 48, 53, 76, 123, 124, 125, 126].contains(code) { buffer = ""; return } // return, tab, esc, arrows
        var len = 0
        var chars = [UniChar](repeating: 0, count: 4)
        e.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &len, unicodeString: &chars)
        guard len > 0 else { buffer = ""; return }
        buffer += String(utf16CodeUnits: chars, count: len)
        if buffer.count > 64 { buffer.removeFirst(buffer.count - 64) }

        let match = snippets.filter { !$0.trigger.isEmpty && buffer.hasSuffix($0.trigger) }
            .max { $0.trigger.count < $1.trigger.count }
        if let m = match {
            buffer = ""
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { self.expand(m) }
        }
    }

    // Delete the trigger, then paste the text (pasting keeps line breaks and is instant).
    private func expand(_ s: Snippet) {
        let src = CGEventSource(stateID: .hidSystemState)
        func press(_ code: CGKeyCode, _ flags: CGEventFlags = []) {
            for down in [true, false] {
                guard let ev = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: down) else { continue }
                ev.flags = flags
                ev.setIntegerValueField(.eventSourceUserData, value: marker)
                ev.post(tap: .cghidEventTap)
            }
        }
        for _ in 0..<s.trigger.count { press(51) }

        let pb = NSPasteboard.general
        let saved: [NSPasteboardItem] = pb.pasteboardItems?.map { item in
            let copy = NSPasteboardItem()
            for t in item.types { if let d = item.data(forType: t) { copy.setData(d, forType: t) } }
            return copy
        } ?? []
        pb.clearContents()
        pb.setString(s.text, forType: .string)
        pb.setString("", forType: .init("org.nspasteboard.TransientType")) // clipboard managers skip it
        press(9, .maskCommand) // ⌘V
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            pb.clearContents()
            if !saved.isEmpty { pb.writeObjects(saved) }
        }
    }
}

let engine = Engine()

let onEvent: CGEventTapCallBack = { _, type, event, _ in
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let t = engine.tap { CGEvent.tapEnable(tap: t, enable: true) }
    } else {
        engine.handle(type, event)
    }
    return Unmanaged.passUnretained(event)
}

// MARK: - Views

let accent = Color(red: 0.45, green: 0.42, blue: 0.98)

struct Panel: View {
    @ObservedObject var e = engine
    @State private var editing: Snippet?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(editing == nil ? "SNIPPETS" : "EDIT SNIPPET")
                    .font(.system(size: 11, weight: .semibold)).tracking(1.2).foregroundStyle(.secondary)
                Spacer()
                if editing == nil {
                    Toggle("", isOn: $e.enabled).labelsHidden().toggleStyle(.switch).controlSize(.mini)
                    small("plus") { editing = Snippet(trigger: ";", text: "") }
                }
            }

            if !e.trusted {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Snip needs the Accessibility permission to see what you type and insert snippets.")
                        .font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
                    Button("Open Accessibility Settings") {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                    }.controlSize(.small)
                }
                .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
            }

            if let s = editing {
                Editor(draft: s, isNew: !e.snippets.contains { $0.id == s.id }) { result in
                    if let r = result {
                        if let i = e.snippets.firstIndex(where: { $0.id == r.id }) { e.snippets[i] = r } else { e.snippets.append(r) }
                    }
                    editing = nil
                } onDelete: {
                    e.snippets.removeAll { $0.id == s.id }; editing = nil
                }
            } else {
                list
                Divider()
                HStack {
                    Text(e.enabled ? "Type a trigger anywhere to expand it." : "Paused")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                    Spacer()
                    Button("Quit") { NSApp.terminate(nil) }
                        .buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .frame(width: 320)
    }

    var list: some View {
        ScrollView {
            VStack(spacing: 2) {
                ForEach(e.snippets) { s in
                    Button { editing = s } label: {
                        HStack(spacing: 10) {
                            Text(s.trigger)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundStyle(accent)
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))
                            Text(s.text.replacingOccurrences(of: "\n", with: " ⏎ "))
                                .font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 5).padding(.horizontal, 6)
                        .contentShape(Rectangle())
                    }.buttonStyle(RowStyle())
                }
                if e.snippets.isEmpty {
                    Text("No snippets yet. Click + to add one.")
                        .font(.system(size: 12)).foregroundStyle(.secondary).padding(.vertical, 20)
                }
            }
        }
        .frame(height: min(CGFloat(max(e.snippets.count, 2)) * 34, 270))
    }
}

struct RowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Color.primary.opacity(configuration.isPressed ? 0.1 : 0.0001), in: RoundedRectangle(cornerRadius: 6))
    }
}

struct Editor: View {
    @State var draft: Snippet
    let isNew: Bool
    let done: (Snippet?) -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Trigger").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
            TextField(";trigger", text: $draft.trigger)
                .textFieldStyle(.roundedBorder).font(.system(size: 13, design: .monospaced))
            Text("Expands to").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
            TextEditor(text: $draft.text)
                .font(.system(size: 13))
                .scrollContentBackground(.hidden)
                .padding(6)
                .frame(height: 130)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.1)))
            Text("Tip: start triggers with ; so they never fire by accident.")
                .font(.system(size: 11)).foregroundStyle(.tertiary)
            HStack {
                if !isNew {
                    Button("Delete", role: .destructive, action: onDelete).buttonStyle(.plain).foregroundStyle(.red)
                }
                Spacer()
                Button("Cancel") { done(nil) }
                Button("Save") {
                    draft.trigger = draft.trigger.trimmingCharacters(in: .whitespacesAndNewlines)
                    done(draft)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(draft.trigger.trimmingCharacters(in: .whitespaces).count < 2 || draft.text.isEmpty)
            }
            .font(.system(size: 12)).controlSize(.small)
        }
    }
}

func small(_ icon: String, _ action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Image(systemName: icon).font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
            .frame(width: 22, height: 22).contentShape(Rectangle())
    }.buttonStyle(.plain)
}

@main
struct SnipApp: App {
    @ObservedObject var e = engine
    var body: some Scene {
        MenuBarExtra {
            Panel()
        } label: {
            Image(systemName: e.enabled ? "text.cursor" : "pause.circle")
        }
        .menuBarExtraStyle(.window)
    }
}
