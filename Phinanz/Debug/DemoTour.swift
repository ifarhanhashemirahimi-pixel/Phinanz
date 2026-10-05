//
//  DemoTour.swift
//  Phinanz
//
//  DEBUG-only: records a scripted tour through the real app into
//  snapshots/demo-<language>.mp4 when snapshots/DEMO exists. The app runs
//  with in-memory showcase data; the tour drives the real screens through
//  `DemoDirector` and records the app's own windows at 30 fps.
//  A timeline (demo-timeline.txt) lists when each step started, for captions.
//

#if DEBUG
import SwiftUI
import SwiftData
import Combine
import AVFoundation
import UIKit

enum DemoSheet: String, Identifiable {
    case report, goal, security
    var id: String { rawValue }
}

enum DemoCommand {
    case tab(AppTab)
    case sheet(ActiveSheet?)
    case extra(DemoSheet?)
    case journal(Date)
    case typeAmount(String)
    case typeStore(String)
    case saveEditor
    case bankCSV(URL)
    case saveReview
    case addToGoal(Double)
}

@MainActor
final class DemoDirector {
    static let shared = DemoDirector()
    let commands = PassthroughSubject<DemoCommand, Never>()
    func send(_ command: DemoCommand) { commands.send(command) }
}

enum DemoTour {
    @MainActor
    static func runIfRequested(lock: AppLock) async {
        guard AppEnvironment.isDemo,
              let flag = DebugFlags.url("DEMO"),
              let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first
        else { return }
        let directory = flag.deletingLastPathComponent()
        let language = Locale.current.language.languageCode?.identifier ?? "xx"
        let output = directory.appendingPathComponent("demo-\(language).mp4")
        try? FileManager.default.removeItem(at: output)

        try? await Task.sleep(for: .seconds(2.5)) // let the journal settle

        let recorder: WindowRecorder
        do {
            recorder = try WindowRecorder(scene: scene, url: output)
        } catch {
            try? "Recorder failed: \(error)".write(to: directory.appendingPathComponent("demo-timeline.txt"), atomically: true, encoding: .utf8)
            return
        }
        recorder.start()

        var timeline = "language\t\(language)\n"
        func mark(_ name: String) {
            timeline += String(format: "%.2f\t%@\n", recorder.elapsed, name)
        }
        func wait(_ seconds: Double) async {
            try? await Task.sleep(for: .milliseconds(Int(seconds * 1_000)))
        }
        let director = DemoDirector.shared
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // 1. Journal: one page per day
        mark("journal")
        await wait(3)
        mark("swipe-days")
        director.send(.journal(calendar.date(byAdding: .day, value: -1, to: today) ?? today))
        await wait(1.8)
        director.send(.journal(calendar.date(byAdding: .day, value: -2, to: today) ?? today))
        await wait(1.8)
        director.send(.journal(today))
        await wait(1.6)

        // 2. New entry with automatic category
        mark("add-entry")
        director.send(.sheet(.add(YearCalendar.entryDate(on: today, calendar: calendar))))
        await wait(1.4)
        for text in ["4", "4,", "4,8", "4,80"] {
            director.send(.typeAmount(text))
            await wait(0.3)
        }
        await wait(0.4)
        mark("auto-category")
        var typed = ""
        for character in "Bäckerei Schmidt" {
            typed.append(character)
            director.send(.typeStore(typed))
            await wait(0.11)
        }
        await wait(1.6)
        director.send(.saveEditor)
        await wait(2.2)

        // 3. Summary and monthly report
        mark("summary")
        director.send(.tab(.summary))
        await wait(3.5)
        mark("report")
        director.send(.extra(.report))
        await wait(5)
        director.send(.extra(nil))
        await wait(1)

        // 4. Plan: accounts and savings goals
        mark("plan")
        director.send(.tab(.plan))
        await wait(3.5)
        mark("goal")
        director.send(.extra(.goal))
        await wait(1.8)
        director.send(.addToGoal(120))
        await wait(2.6)
        director.send(.extra(nil))
        await wait(1)

        // 5. Bank CSV import, read on the device
        mark("import")
        director.send(.tab(.journal))
        await wait(0.8)
        director.send(.sheet(.scan))
        await wait(2.6)
        director.send(.sheet(nil))
        await wait(0.8)
        mark("bank-csv")
        if let csv = writeSampleCSV(today: today, calendar: calendar) {
            director.send(.bankCSV(csv))
        }
        await wait(4.2)
        mark("bank-csv-save")
        director.send(.saveReview)
        await wait(2.2)

        // 6. Security
        mark("security")
        director.send(.extra(.security))
        await wait(4.5)
        director.send(.extra(nil))
        await wait(1)

        // 7. Dark mode
        mark("dark")
        setStyle(.dark, in: scene)
        await wait(2.6)
        director.send(.tab(.summary))
        await wait(2.4)
        director.send(.tab(.journal))
        await wait(1.4)

        // 8. Face ID lock
        mark("lock")
        lock.isLocked = true
        await wait(2.8)
        lock.isLocked = false
        await wait(1.6)
        setStyle(.unspecified, in: scene)
        await wait(1.4)
        mark("end")

        await recorder.finish()
        timeline += "frames\t\(recorder.frames)\n"
        try? timeline.write(to: directory.appendingPathComponent("demo-timeline.txt"), atomically: true, encoding: .utf8)
        try? FileManager.default.removeItem(at: flag)
    }

    @MainActor
    private static func setStyle(_ style: UIUserInterfaceStyle, in scene: UIWindowScene) {
        for window in scene.windows {
            UIView.transition(with: window, duration: 0.6, options: .transitionCrossDissolve) {
                window.overrideUserInterfaceStyle = style
            }
        }
    }

    /// A small Sparkasse-style export for this month, including one booking
    /// the journal already has (it shows up as a possible duplicate).
    private static func writeSampleCSV(today: Date, calendar: Calendar) -> URL? {
        func day(_ offset: Int) -> String {
            let date = calendar.date(byAdding: .day, value: offset, to: today) ?? today
            let formatter = DateFormatter()
            formatter.dateFormat = "dd.MM.yy"
            return formatter.string(from: date)
        }
        let rows = [
            "\"Auftragskonto\";\"Buchungstag\";\"Valutadatum\";\"Buchungstext\";\"Verwendungszweck\";\"Beguenstigter/Zahlungspflichtiger\";\"Betrag\";\"Waehrung\";\"Info\"",
            "\"DE01\";\"\(day(0))\";\"\(day(0))\";\"KARTENZAHLUNG\";\"REWE SAGT DANKE\";\"REWE\";\"-38,72\";\"EUR\";\"Umsatz gebucht\"",
            "\"DE01\";\"\(day(-1))\";\"\(day(-1))\";\"LASTSCHRIFT\";\"Mobilfunk Oktober\";\"Vodafone GmbH\";\"-29,99\";\"EUR\";\"Umsatz gebucht\"",
            "\"DE01\";\"\(day(-2))\";\"\(day(-2))\";\"KARTENZAHLUNG\";\"Tankstelle\";\"Aral\";\"-54,10\";\"EUR\";\"Umsatz gebucht\"",
            "\"DE01\";\"\(day(-2))\";\"\(day(-2))\";\"KARTENZAHLUNG\";\"Wocheneinkauf\";\"Lidl\";\"-31,46\";\"EUR\";\"Umsatz gebucht\"",
            "\"DE01\";\"\(day(-3))\";\"\(day(-3))\";\"GUTSCHRIFT\";\"Rueckerstattung Bestellung\";\"Zalando SE\";\"19,95\";\"EUR\";\"Umsatz gebucht\"",
            "\"DE01\";\"\(day(-3))\";\"\(day(-3))\";\"LASTSCHRIFT\";\"Abo\";\"Spotify AB\";\"-10,99\";\"EUR\";\"Umsatz gebucht\""
        ]
        let url = DataProtection.exportURL(named: "demo-bank.csv")
        do {
            try rows.joined(separator: "\r\n").write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }
}

/// Writes what the app's windows show into an H.264 file, 30 frames a second.
@MainActor
final class WindowRecorder: NSObject {
    private let scene: UIWindowScene
    private let writer: AVAssetWriter
    private let input: AVAssetWriterInput
    private let adaptor: AVAssetWriterInputPixelBufferAdaptor
    private let pixelWidth: Int
    private let pixelHeight: Int
    private let scale: CGFloat
    private var link: CADisplayLink?
    private var startTime: CFTimeInterval = 0
    private(set) var frames = 0

    var elapsed: Double { startTime == 0 ? 0 : CACurrentMediaTime() - startTime }

    init(scene: UIWindowScene, url: URL, scale: CGFloat = 2) throws {
        self.scene = scene
        self.scale = scale
        let bounds = scene.windows.first?.bounds ?? scene.effectiveGeometry.coordinateSpace.bounds
        // H.264 needs even dimensions.
        pixelWidth = Int((bounds.width * scale / 2).rounded()) * 2
        pixelHeight = Int((bounds.height * scale / 2).rounded()) * 2
        writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: pixelWidth,
            AVVideoHeightKey: pixelHeight,
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 14_000_000]
        ])
        input.expectsMediaDataInRealTime = true
        adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: pixelWidth,
            kCVPixelBufferHeightKey as String: pixelHeight
        ])
        writer.add(input)
        super.init()
    }

    func start() {
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        startTime = CACurrentMediaTime()
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 30, preferred: 30)
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    @objc private func tick() {
        guard input.isReadyForMoreMediaData, let pool = adaptor.pixelBufferPool else { return }
        var buffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
        guard let buffer else { return }

        CVPixelBufferLockBaseAddress(buffer, [])
        if let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) {
            context.setFillColor(UIColor.black.cgColor)
            context.fill(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
            context.translateBy(x: 0, y: CGFloat(pixelHeight))
            context.scaleBy(x: scale, y: -scale)
            UIGraphicsPushContext(context)
            // App windows in z-order; the lock window sits on top. The keyboard can't be captured.
            for window in scene.windows.sorted(by: { $0.windowLevel < $1.windowLevel })
            where !window.isHidden && window.alpha > 0.01 && !String(describing: type(of: window)).contains("Keyboard") {
                window.drawHierarchy(in: window.frame, afterScreenUpdates: false)
            }
            UIGraphicsPopContext()
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])

        let time = CMTime(seconds: CACurrentMediaTime() - startTime, preferredTimescale: 600)
        if adaptor.append(buffer, withPresentationTime: time) { frames += 1 }
    }

    func finish() async {
        link?.invalidate()
        link = nil
        input.markAsFinished()
        await writer.finishWriting()
    }
}
#endif
