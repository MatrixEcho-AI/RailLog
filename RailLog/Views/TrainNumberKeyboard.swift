import SwiftUI

// MARK: - Custom TextField Wrapper

struct TrainNumberTextField: UIViewRepresentable {
    @Binding var text: String

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.placeholder = "e.g. G81"
        textField.text = text
        textField.textAlignment = .right
        textField.font = .preferredFont(forTextStyle: .body)
        textField.delegate = context.coordinator
        textField.tintColor = .clear

        let keyboardView = TrainNumberKeyboardView(
            text: $text,
            dismiss: { textField.resignFirstResponder() }
        )
        let hostingController = UIHostingController(rootView: keyboardView)
        let hostingView = hostingController.view!
        let screenWidth = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.screen.bounds.width ?? 390
        hostingView.frame = CGRect(x: 0, y: 0, width: screenWidth, height: 240)
        hostingView.autoresizingMask = []
        hostingView.backgroundColor = .clear

        textField.inputView = hostingView
        context.coordinator.hostingController = hostingController

        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        uiView.text = text
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var text: String
        var hostingController: UIHostingController<TrainNumberKeyboardView>?

        init(text: Binding<String>) {
            _text = text
        }

        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            false
        }
    }
}

// MARK: - Custom Keyboard View

struct TrainNumberKeyboardView: View {
    @Binding var text: String
    let dismiss: () -> Void

    private var digitCount: Int {
        text.filter { $0.isNumber || $0 == "/" }.count
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                ForEach(["C", "G", "S", "D"], id: \.self) { letter in
                    KeyButton(title: letter, enabled: text.isEmpty) {
                        text = letter
                    }
                }
            }

            HStack(spacing: 6) {
                ForEach(1...10, id: \.self) { i in
                    let digit = "\(i % 10)"
                    KeyButton(title: digit, enabled: digitCount < 8 && !text.isEmpty) {
                        text.append(digit)
                    }
                }
            }

            HStack(spacing: 8) {
                KeyButton(title: "/", enabled: !text.contains("/") && !text.isEmpty && digitCount < 8) {
                    text.append("/")
                }

                KeyButton(title: "⌫", enabled: !text.isEmpty) {
                    text.removeLast()
                }

                Button {
                    dismiss()
                } label: {
                    Text("完成")
                        .font(.body.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(.blue, in: RoundedRectangle(cornerRadius: 8))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.systemGray6))
    }
}

// MARK: - Key Button

struct KeyButton: View {
    let title: String
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.title3.weight(.medium))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(enabled ? Color(.systemGray4) : Color(.systemGray6))
                .foregroundColor(enabled ? .primary : .secondary.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .disabled(!enabled)
    }
}

#Preview {
    TrainNumberKeyboardView(text: .constant(""), dismiss: {})
}
