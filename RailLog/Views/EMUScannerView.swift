import SwiftUI
import VisionKit

struct EMUScannerView: View {
    let onScan: ([String]) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            EMUCameraScanner { result in
                switch result {
                case .success(let numbers):
                    onScan(numbers)
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
            .ignoresSafeArea()
            .navigationTitle("扫描车身编号")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .alert("扫描失败", isPresented: $showError) {
                Button("确定") { dismiss() }
            } message: {
                Text(errorMessage)
            }
        }
    }
}

// MARK: - DataScannerViewController wrapper

private struct EMUCameraScanner: UIViewControllerRepresentable {
    let onResult: (Result<[String], Error>) -> Void

    func makeUIViewController(context: Context) -> EMUScannerController {
        let vc = EMUScannerController()
        vc.onResult = onResult
        return vc
    }

    func updateUIViewController(_ uiViewController: EMUScannerController, context: Context) {}
}

private final class EMUScannerController: UIViewController, DataScannerViewControllerDelegate {
    var onResult: ((Result<[String], Error>) -> Void)?

    private var seenNumbers: Set<String> = []
    private var scanTask: Task<Void, Never>?
    private let emuPattern: NSRegularExpression

    private lazy var scanner: DataScannerViewController = {
        let vc = DataScannerViewController(
            recognizedDataTypes: [.text(textContentType: nil)],
            qualityLevel: .balanced,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        vc.delegate = self
        return vc
    }()

    private lazy var guideOverlay: UIView = {
        let v = UIView()
        v.backgroundColor = .clear
        v.isUserInteractionEnabled = false
        let label = UILabel()
        label.text = "CR     -   "
        label.font = .monospacedSystemFont(ofSize: 36, weight: .bold)
        label.textColor = UIColor.white.withAlphaComponent(0.5)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: v.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: v.centerYAnchor)
        ])
        return v
    }()

    init() {
        // Build regex from train model dictionary: (longest_code|shorter_code|...)-(\d+)
        let modelCodes = DataBundleService.shared.models
            .map(\.code)
            .sorted(by: { $0.count > $1.count })
        if modelCodes.isEmpty {
            emuPattern = try! NSRegularExpression(pattern: #"\bCR[A-Z0-9]+-[A-Z0-9-]+\b"#)
        } else {
            let alternation = modelCodes.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|")
            emuPattern = try! NSRegularExpression(pattern: #"\b(\#(alternation))-(\d{4})\b"#)
        }
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        addChild(scanner)
        view.addSubview(scanner.view)
        scanner.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scanner.view.topAnchor.constraint(equalTo: view.topAnchor),
            scanner.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scanner.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scanner.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        scanner.didMove(toParent: self)

        // Guide overlay on top of scanner
        view.addSubview(guideOverlay)
        guideOverlay.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            guideOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            guideOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            guideOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            guideOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        do {
            try scanner.startScanning()
        } catch {
            onResult?(.failure(error))
            return
        }

        scanTask = Task { [weak self] in
            guard let self else { return }
            for await items in self.scanner.recognizedItems {
                self.processItems(items)
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        scanTask?.cancel()
        scanner.stopScanning()
    }

    private func processItems(_ items: [RecognizedItem]) {
        for item in items {
            guard case .text(let text) = item else { continue }
            let transcript = text.transcript
            let range = NSRange(transcript.startIndex..., in: transcript)
            let matches = emuPattern.matches(in: transcript, range: range)

            for match in matches {
                guard let r = Range(match.range, in: transcript) else { continue }
                seenNumbers.insert(String(transcript[r]))
            }
        }

        if seenNumbers.count == 1, let number = seenNumbers.first {
            scanTask?.cancel()
            scanner.stopScanning()
            onResult?(.success([number]))
        }
    }

    func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
        guard case .text(let text) = item else { return }
        let transcript = text.transcript
        let range = NSRange(transcript.startIndex..., in: transcript)
        let matches = emuPattern.matches(in: transcript, range: range)
        let numbers = matches.compactMap { match -> String? in
            guard let r = Range(match.range, in: transcript) else { return nil }
            return String(transcript[r])
        }
        if !numbers.isEmpty {
            scanTask?.cancel()
            scanner.stopScanning()
            onResult?(.success(numbers))
        }
    }
}
