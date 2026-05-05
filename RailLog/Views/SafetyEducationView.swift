import SwiftUI

struct SafetyEducationView: View {
    let domain: Domain
    let onComplete: () -> Void

    @State private var currentPage = 0
    @State private var inputText = ""

    private var education: SafetyEducation? { domain.safetyEducation }

    var body: some View {
        if let education = education {
            VStack(spacing: 0) {
                // 页面指示器
                HStack {
                    ForEach(0..<2) { i in
                        Capsule()
                            .fill(i == currentPage ? Color.blue : Color(.systemGray4))
                            .frame(width: i == currentPage ? 20 : 8, height: 8)
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 8)

                TabView(selection: $currentPage) {
                    // 第一页：安全规则
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            VStack(spacing: 8) {
                                Image(systemName: "hand.raised.fill")
                                    .font(.system(size: 52))
                                    .foregroundStyle(.blue)
                                Text("铁路安全须知")
                                    .font(.title.bold())
                                Text("请仔细阅读以下安全规定")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 24)

                            ForEach(education.rules) { rule in
                                SafetyRuleCard(rule: rule)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                    }
                    .tag(0)

                    // 第二页：确认输入
                    VStack(spacing: 32) {
                        Spacer()

                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.green)

                        Text("安全承诺")
                            .font(.title.bold())

                        Text("请输入「\(education.confirmationPhrase)」以确认你已阅读并理解以上安全规定。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)

                        TextField("在此输入", text: $inputText)
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.center)
                            .font(.body.weight(.medium))
                            .padding(.horizontal, 32)
                            .autocorrectionDisabled()

                        if !inputText.isEmpty && inputText != education.confirmationPhrase {
                            Text("输入不正确，请检查")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }

                        Spacer()

                        Button {
                            onComplete()
                        } label: {
                            Text("确认并开始使用")
                                .font(.body.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(inputText == education.confirmationPhrase ? Color.blue : Color(.systemGray4), in: RoundedRectangle(cornerRadius: 14))
                                .foregroundColor(inputText == education.confirmationPhrase ? .white : .secondary)
                        }
                        .disabled(inputText != education.confirmationPhrase)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 8)
                    }
                    .tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .background(Color(.systemGroupedBackground))
        }
    }
}

// MARK: - 安全规则卡片

private struct SafetyRuleCard: View {
    let rule: SafetyRule

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: rule.icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 36, height: 36)
                .padding(8)
                .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 6) {
                Text(rule.title)
                    .font(.headline)
                Text(rule.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    SafetyEducationView(domain: Domain.chinaRailway, onComplete: {})
}
