import SwiftUI
import AVFoundation

struct ScannerView: View {
    let onScan: (ScannedTripData) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            CameraScanner { result in
                switch result {
                case .success(let urlString):
                    if let data = QRCodeParser.parse(urlString) {
                        onScan(data)
                    } else {
                        errorMessage = "无法识别该二维码中的列车信息：\(urlString)"
                        showError = true
                    }
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
            .ignoresSafeArea()
            .navigationTitle("扫描畅行码")
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

// MARK: - AVFoundation camera scanner

private struct CameraScanner: UIViewControllerRepresentable {
    let onResult: (Result<String, Error>) -> Void

    func makeUIViewController(context: Context) -> CameraScannerController {
        let vc = CameraScannerController()
        vc.onResult = onResult
        return vc
    }

    func updateUIViewController(_ uiViewController: CameraScannerController, context: Context) {}
}

private final class CameraScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onResult: ((Result<String, Error>) -> Void)?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer!

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .black

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            onResult?(.failure(ScannerError.noCamera))
            return
        }

        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]

        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        session.stopRunning()
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = object.stringValue else { return }

        session.stopRunning()
        onResult?(.success(value))
    }
}

enum ScannerError: LocalizedError {
    case noCamera

    var errorDescription: String? {
        switch self {
        case .noCamera: return "设备没有可用的摄像头"
        }
    }
}
