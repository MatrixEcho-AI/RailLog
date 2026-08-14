import CoreImage
import SwiftUI
import UIKit

/// 新手教程（首启强制）：第一页为全流程动画演示（复用真实界面代码），
/// 后两页为安全须知与确认（原有安全教育内容）。
struct SafetyEducationView: View {
    let domain: Domain
    let onComplete: () -> Void

    @State private var currentPage = 0
    @State private var inputText = ""

    private var education: SafetyEducation? { domain.safetyEducation }
    private let pageCount = 3

    var body: some View {
        if let education = education {
            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    FullJourneyDemo().tag(0)
                    rulesPage(education).tag(1)
                    confirmPage(education).tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // 页面指示器（底部）
                HStack {
                    ForEach(0..<pageCount, id: \.self) { i in
                        Capsule()
                            .fill(i == currentPage ? Color.blue : Color(.systemGray4))
                            .frame(width: i == currentPage ? 20 : 8, height: 8)
                    }
                }
                .padding(.top, 10)
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
        }
    }

    // MARK: - 安全规则页（原有内容）

    private func rulesPage(_ education: SafetyEducation) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(spacing: 6) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.blue)
                    Text("铁路安全须知")
                        .font(.title.bold())
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 12)

                ForEach(education.rules) { rule in
                    SafetyRuleCard(rule: rule)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }

    // MARK: - 安全承诺页（原有内容）

    private func confirmPage(_ education: SafetyEducation) -> some View {
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
    }
}

/// 教程演示用的示例行程
private let tutorialDemoLog: TripLog = {
    var log = TripLog()
    log.isDraft = false
    log.isFavorite = true
    log.trainNumber = "G6525"
    log.emuNumber = "CR400AF-2186"
    log.carriage = "04"
    log.seat = "01A"
    log.departureStation = "深圳北"
    log.arrivalStation = "香港西九龙"
    log.bureau = "广州局"
    log.depot = "广州动车段"
    log.mileage = "39"
    log.maxSpeed = "250"
    log.ticketPrice = "75"
    log.verifiedOnRailway = true
    let dep = Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 17, hour: 14, minute: 18))!
    log.departureTime = dep
    log.arrivalTime = dep.addingTimeInterval(24 * 60)
    return log
}()

/// 填写页演示用的草稿形态（保存按钮显示为"完成运转"）
private var tutorialDemoDraft: TripLog {
    var log = tutorialDemoLog
    log.isDraft = true
    return log
}

/// 教程演示用的示例日志集（主行程 + 若干历史记录，让列表/统计页更真实）
private let tutorialDemoLogs: [TripLog] = {
    func make(_ train: String, _ emu: String, _ dep: String, _ arr: String,
              bureau: String, depot: String, carriage: String, seat: String,
              mileage: String, speed: String, price: String, isPoints: Bool = false,
              date: DateComponents, hours: Double) -> TripLog {
        var log = TripLog()
        log.isDraft = false
        log.trainNumber = train
        log.emuNumber = emu
        log.carriage = carriage
        log.seat = seat
        log.departureStation = dep
        log.arrivalStation = arr
        log.bureau = bureau
        log.depot = depot
        log.mileage = mileage
        log.maxSpeed = speed
        log.ticketPrice = price
        log.ticketPriceIsPoints = isPoints
        log.verifiedOnRailway = true
        let start = Calendar.current.date(from: date)!
        log.departureTime = start
        log.arrivalTime = start.addingTimeInterval(hours * 3600)
        return log
    }
    return [
        tutorialDemoLog,
        make("G100", "CR400BF-3091", "香港西九龙", "深圳北", bureau: "广州局", depot: "广州动车段",
             carriage: "07", seat: "12F", mileage: "39", speed: "250", price: "75",
             date: DateComponents(year: 2026, month: 3, day: 15, hour: 9, minute: 5), hours: 0.4),
        make("G81", "CR400AF-2186", "北京南", "上海虹桥", bureau: "北京局", depot: "北京动车段",
             carriage: "04", seat: "05C", mileage: "1318", speed: "350", price: "553",
             date: DateComponents(year: 2026, month: 3, day: 8, hour: 9, minute: 0), hours: 4.5),
        make("D901", "CRH2E-2136", "深圳北", "上海虹桥", bureau: "上海局", depot: "上海动车段",
             carriage: "09", seat: "22", mileage: "1623", speed: "250", price: "740",
             date: DateComponents(year: 2026, month: 2, day: 27, hour: 20, minute: 10), hours: 11),
        make("C7086", "CRH6A-0618", "广州东", "深圳", bureau: "广州局", depot: "广州动车段",
             carriage: "02", seat: "08D", mileage: "139", speed: "200", price: "79.5",
             date: DateComponents(year: 2026, month: 2, day: 14, hour: 13, minute: 40), hours: 1.3),
        make("G80", "CR400BF-Z-3124", "香港西九龙", "北京西", bureau: "北京局", depot: "北京动车段",
             carriage: "01", seat: "02F", mileage: "2440", speed: "350", price: "1077",
             date: DateComponents(year: 2026, month: 2, day: 10, hour: 11, minute: 20), hours: 8.3),
        make("G79", "CR400BF-Z-3124", "北京西", "香港西九龙", bureau: "北京局", depot: "北京动车段",
             carriage: "16", seat: "11A", mileage: "2440", speed: "350", price: "1077",
             date: DateComponents(year: 2026, month: 1, day: 30, hour: 10, minute: 0), hours: 8.2),
        make("G2963", "CR400AF-S-1064", "深圳北", "成都东", bureau: "成都局", depot: "成都动车段",
             carriage: "08", seat: "07C", mileage: "1607", speed: "300", price: "846.5",
             date: DateComponents(year: 2026, month: 1, day: 18, hour: 8, minute: 30), hours: 7.5),
        make("D728", "CR200J-5021", "深圳", "北京丰台", bureau: "北京局", depot: "北京车辆段",
             carriage: "11", seat: "03下", mileage: "2372", speed: "160", price: "51900", isPoints: true,
             date: DateComponents(year: 2026, month: 1, day: 5, hour: 19, minute: 40), hours: 22),
        make("G6021", "CR400AF-2033", "深圳北", "长沙南", bureau: "广州局", depot: "长沙动车段",
             carriage: "03", seat: "10B", mileage: "809", speed: "300", price: "388.5",
             date: DateComponents(year: 2025, month: 12, day: 21, hour: 15, minute: 8), hours: 3.2),
        make("C7108", "CRH6A-0622", "深圳", "广州东", bureau: "广州局", depot: "广州动车段",
             carriage: "05", seat: "16A", mileage: "139", speed: "200", price: "7950", isPoints: true,
             date: DateComponents(year: 2025, month: 12, day: 7, hour: 17, minute: 22), hours: 1.3),
        make("G5601", "CR400AF-2211", "深圳北", "福田", bureau: "广州局", depot: "广州动车段",
             carriage: "06", seat: "01F", mileage: "9", speed: "200", price: "900", isPoints: true,
             date: DateComponents(year: 2025, month: 11, day: 16, hour: 10, minute: 2), hours: 0.2),
    ]
}()

/// 把子视图钉成舞台的精确尺寸并顶部对齐（防止尺寸协商把内容顶出舞台）
private struct StageFrame: ViewModifier {
    let geo: GeometryProxy
    func body(content: Content) -> some View {
        content
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
    }
}

// MARK: - 全流程演示

/// 扫描 → 填写 → 列表 → 详情 → 钱包 → 统计，标题图标随阶段切换。
private struct FullJourneyDemo: View {
    /// 0 扫描 / 1 填写(顶部) / 2 填写(滚到底+点完成) / 3 列表(点行) / 4 详情(顶部) /
    /// 5 详情(滚到钱包+按下) / 6 卡片升起 / 7 卡片入钱包 / 8 完成勾 / 9 统计 / 10 收起重播
    @State private var step = 0
    @State private var demoStore = DataStore()
    /// 统计数字增长进度（0→1），每轮循环重置，配合 AboutView.demoProgress 从 0 增长
    @State private var statsProgress: Double = 0
    /// 表单填入进度（TripEditView 分区依次显示）
    @State private var formReveal = 0
    /// 虚拟手指：可见性、位置（舞台内绝对 pt，与内容坐标系一致）、按压态
    @State private var fingerVisible = false
    @State private var fingerY: CGFloat = 500
    @State private var fingerTapped = false
    /// 表单/详情的当前滚动量（分段拖拽驱动，手指移动距离与其严格一致）
    @State private var formOffset: CGFloat = 0
    @State private var detailOffset: CGFloat = 0

    // MARK: 点击目标坐标（按模拟器截图实测校准；要调就改这几个数）
    // 注：新增"票价"行后按行高估算调整（表单 +44pt、详情时间轴 +28pt），如手指落点偏移请截图复校
    private let formScroll: CGFloat = 710          // 表单滚动量（与下方 offset 一致）
    private let formSaveButtonY: CGFloat = 1110    // "完成运转"按钮的内容 y（票价行 +44）
    private let listFirstRowY: CGFloat = 102       // 列表第一行中心的内容 y
    private let detailScroll: CGFloat = 535        // 详情滚动量（与下方 offset 一致）
    private let detailWalletY: CGFloat = 939       // "添加到钱包"按钮的内容 y（票价行 +28）

    private var header: (icon: String, title: String) {
        switch step {
        case 0: ("qrcode.viewfinder", "扫描录入")
        case 1, 2: ("square.and.pencil", "填写信息")
        case 3: ("book.pages", "运转列表")
        case 4, 5: ("doc.text", "运转详情")
        case 6, 7, 8: ("wallet.pass.fill", "加入钱包")
        default: ("info.circle", "统计")
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            // 图标 + 大标题（随阶段切换；标题直接替换，不用转场——避免转场叠加层闪帧）
            VStack(spacing: 6) {
                Image(systemName: header.icon)
                    .font(.system(size: 40))
                    .foregroundStyle(.blue)
                    .contentTransition(.symbolEffect(.replace))
                Text(header.title)
                    .font(.title.bold())
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 12)

            // 演示舞台：GeometryReader 量出可用空间后强制固定尺寸，超出部分裁剪
            GeometryReader { geo in
                ZStack(alignment: .top) {
                    Color(.secondarySystemGroupedBackground)

                    // 各阶段常驻，每个子视图都显式钉上舞台的精确尺寸（顶部对齐），
                    // 仅用透明度切换——不做插入/移除转场，避免转场叠加层伪影
                    ScannerMock(active: step == 0)
                        .modifier(StageFrame(geo: geo))
                        .opacity(step == 0 ? 1 : 0)

                    // 真实填写页（草稿形态，按钮为"完成运转"）；step 2 整体上移露出底部按钮
                    ZStack(alignment: .top) {
                        Color(.systemGroupedBackground)
                        TripEditView(draft: tutorialDemoDraft, revealCount: formReveal)
                            .environment(demoStore)
                            .disabled(true)
                            .allowsHitTesting(false)
                            .frame(height: 1400)
                            .offset(y: -formOffset)
                    }
                    .modifier(StageFrame(geo: geo))
                    .opacity(step >= 1 && step <= 2 ? 1 : 0)

                    // 真实运转列表
                    ZStack(alignment: .top) {
                        Color(.systemGroupedBackground)
                        LogListView(hideNavigationBar: true)
                            .environment(demoStore)
                            .ignoresSafeArea(.container, edges: .top)
                            .disabled(true)
                            .allowsHitTesting(false)
                    }
                    .modifier(StageFrame(geo: geo))
                    .opacity(step == 3 ? 1 : 0)

                    // 真实运转详情；step 5 整体上移露出"添加到钱包"
                    ZStack(alignment: .top) {
                        Color(.systemGroupedBackground)
                        LogDetailView(log: tutorialDemoLog)
                            .environment(demoStore)
                            .disabled(true)
                            .allowsHitTesting(false)
                            .frame(height: 1200)
                            .offset(y: -detailOffset)
                    }
                    .modifier(StageFrame(geo: geo))
                    .opacity(step >= 4 && step <= 5 ? 1 : 0)

                    // 钱包阶段（常驻，子视图按 step 自行控制显隐与位移）
                    walletStage
                        .modifier(StageFrame(geo: geo))

                    // 真实统计页
                    ZStack(alignment: .top) {
                        Color(.systemGroupedBackground)
                        AboutView(hideNavigationBar: true, demoProgress: statsProgress)
                            .environment(demoStore)
                            .ignoresSafeArea(.container, edges: .top)
                            .disabled(true)
                            .allowsHitTesting(false)
                    }
                    .modifier(StageFrame(geo: geo))
                    .opacity(step == 9 ? 1 : 0)
                }
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay { finger(in: geo) }
            }
            .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .task {
            demoStore.seedForTutorial(tutorialDemoLogs)
            await runLoop()
        }
    }

    /// 钱包阶段：6=卡片升起 7=缩小飞入堆叠（居中） 8=完成勾弹出
    /// 常驻视图，全程用 offset/opacity/scale 驱动，不做插入/移除转场
    private var walletStage: some View {
        ZStack {
            // 钱包堆叠（居中偏上，仅 step 7-8 可见——否则统计阶段会残留闪回）
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemGray3))
                    .frame(width: 110, height: 68)
                    .offset(y: -24)
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemGray4))
                    .frame(width: 110, height: 68)
                    .offset(y: -12)
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemGray5))
                    .frame(width: 110, height: 68)
            }
            .offset(y: -70)
            .opacity(step >= 7 && step <= 8 ? 1 : 0)

            // 卡片：候场在舞台下方外 → 升起 → 缩小飞进堆叠 → 溶入消失
            PassCardMock()
                .padding(.horizontal, 36)
                .scaleEffect(step >= 7 ? 0.24 : 1)
                .offset(y: cardOffset)
                .opacity(step >= 6 && step <= 7 ? 1 : 0)

            // 完成勾（仅 step 8 在堆叠处弹出）
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 30))
                .foregroundStyle(.green)
                .background(.white, in: Circle())
                .offset(y: -70)
                .scaleEffect(step == 8 ? 1 : 0.2)
                .opacity(step == 8 ? 1 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 卡片纵向位置：候场(舞台外) → 中下方 → 堆叠处
    private var cardOffset: CGFloat {
        if step >= 7 { return -70 }
        if step >= 6 { return 80 }
        return 420
    }

    /// 虚拟手指层：按压时手指收缩、波纹爆开
    private func finger(in geo: GeometryProxy) -> some View {
        ZStack {
            // 按压波纹
            Circle()
                .stroke(Color.black.opacity(0.35), lineWidth: 2)
                .frame(width: 28, height: 28)
                .scaleEffect(fingerTapped ? 2.0 : 0.6)
                .opacity(fingerTapped ? 0 : 0.9)
            // 手指本体
            Circle()
                .fill(Color.black.opacity(0.4))
                .frame(width: 26, height: 26)
                .overlay(Circle().stroke(.white, lineWidth: 2.5))
                .shadow(color: .black.opacity(0.3), radius: 3)
                .scaleEffect(fingerTapped ? 0.75 : 1)
        }
        .opacity(fingerVisible ? 1 : 0)
        .position(x: geo.size.width / 2, y: fingerY)
        .allowsHitTesting(false)
    }

    private func showFinger(at y: CGFloat) {
        fingerY = y
        withAnimation(.easeOut(duration: 0.2)) { fingerVisible = true }
    }

    private func hideFinger() {
        withAnimation(.easeOut(duration: 0.15)) { fingerVisible = false }
    }

    /// 按压脉冲：手指缩一下 + 波纹爆开
    private func tap() async {
        withAnimation(.easeIn(duration: 0.1)) { fingerTapped = true }
        try? await Task.sleep(for: .seconds(0.18))
        withAnimation(.easeOut(duration: 0.25)) { fingerTapped = false }
        try? await Task.sleep(for: .seconds(0.15))
    }

    /// 抬手并在下方重新按下（分段拖拽之间）
    private func liftAndRepress(at y: CGFloat) async {
        withAnimation(.easeOut(duration: 0.12)) { fingerVisible = false }
        try? await Task.sleep(for: .seconds(0.14))
        fingerY = y
        withAnimation(.easeOut(duration: 0.12)) { fingerVisible = true }
        try? await Task.sleep(for: .seconds(0.12))
    }

    private func runLoop() async {
        while !Task.isCancelled {
            // 扫描录入
            formOffset = 0
            detailOffset = 0
            formReveal = 0
            withAnimation(.none) { statsProgress = 0 }
            withAnimation(.easeInOut(duration: 0.25)) { step = 0 }
            try? await Task.sleep(for: .seconds(2.2))

            // 填写：先逐区填入信息 → 分段拖两次 → 落到"完成运转"上按压
            withAnimation(.easeInOut(duration: 0.35)) { step = 1 }
            try? await Task.sleep(for: .seconds(0.5))
            for i in 1...4 {
                withAnimation(.easeOut(duration: 0.3)) { formReveal = i }
                try? await Task.sleep(for: .seconds(0.45))
            }
            try? await Task.sleep(for: .seconds(0.3))
            showFinger(at: 560)
            try? await Task.sleep(for: .seconds(0.6))
            withAnimation(.easeInOut(duration: 0.5)) {
                formOffset = 380
                fingerY = 180
            }
            try? await Task.sleep(for: .seconds(0.55))
            await liftAndRepress(at: 560)
            withAnimation(.easeInOut(duration: 0.5)) {
                formOffset = 710
                fingerY = 230
            }
            try? await Task.sleep(for: .seconds(0.55))
            withAnimation(.easeInOut(duration: 0.2)) { fingerY = formSaveButtonY - formScroll }
            try? await Task.sleep(for: .seconds(0.25))
            await tap()
            hideFinger()

            // 运转列表：先停顿展示 → 点第一行
            withAnimation(.easeInOut(duration: 0.35)) { step = 3 }
            try? await Task.sleep(for: .seconds(1.3))
            showFinger(at: listFirstRowY)
            try? await Task.sleep(for: .seconds(0.6))
            await tap()
            hideFinger()

            // 运转详情：先停顿展示 → 分段拖两次 → 落到"添加到钱包"上按压
            withAnimation(.easeInOut(duration: 0.35)) { step = 4 }
            try? await Task.sleep(for: .seconds(1.3))
            showFinger(at: 560)
            try? await Task.sleep(for: .seconds(0.6))
            withAnimation(.easeInOut(duration: 0.5)) {
                detailOffset = 280
                fingerY = 280
            }
            try? await Task.sleep(for: .seconds(0.55))
            await liftAndRepress(at: 560)
            withAnimation(.easeInOut(duration: 0.5)) {
                detailOffset = 535
                fingerY = 305
            }
            try? await Task.sleep(for: .seconds(0.55))
            withAnimation(.easeInOut(duration: 0.2)) { fingerY = detailWalletY - detailScroll }
            try? await Task.sleep(for: .seconds(0.25))
            await tap()
            hideFinger()

            // 加入钱包：卡片升起 → 飞入堆叠 → 完成勾
            withAnimation(.spring(duration: 0.45)) { step = 6 }
            try? await Task.sleep(for: .seconds(1.6))
            withAnimation(.easeInOut(duration: 0.55)) { step = 7 }
            try? await Task.sleep(for: .seconds(0.8))
            withAnimation(.easeOut(duration: 0.25)) { step = 8 }
            try? await Task.sleep(for: .seconds(1.4))

            // 统计：进入后数字从 0 增长
            withAnimation(.easeInOut(duration: 0.35)) { step = 9 }
            try? await Task.sleep(for: .seconds(0.6))
            withAnimation(.easeOut(duration: 1.2)) { statsProgress = 1 }
            try? await Task.sleep(for: .seconds(2.2))
            withAnimation(.easeOut(duration: 0.3)) { step = 10 }
            try? await Task.sleep(for: .seconds(0.5))
        }
    }
}

/// 扫描画面复刻（相机页依赖摄像头无法直接复用；白底）
/// 动画：编号由模糊变清晰（对焦）→ 取景框收缩锁定（变绿）。
/// 常驻视图，用 active 显式重置播放。
private struct ScannerMock: View {
    var active: Bool = true
    @State private var blurred = true
    @State private var locked = false

    var body: some View {
        ZStack {
            Text("CR400AF-2186")
                .font(.title2)
                .bold()
                .fontDesign(.monospaced)
                .foregroundStyle(.primary.opacity(0.85))
                .blur(radius: blurred ? 14 : 0)

            RoundedRectangle(cornerRadius: 12)
                .stroke(locked ? Color.green : Color(.systemGray2), lineWidth: 2)
                .frame(width: locked ? 240 : 300, height: locked ? 96 : 130)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
        .onAppear { if active { play() } }
        .onChange(of: active) { _, newValue in
            if newValue { play() } else { reset() }
        }
    }

    private func play() {
        blurred = true
        locked = false
        withAnimation(.easeOut(duration: 0.9)) { blurred = false }
        withAnimation(.spring(duration: 0.45).delay(1.0)) { locked = true }
    }

    private func reset() {
        withAnimation(.linear(duration: 0.15)) {
            blurred = true
            locked = false
        }
    }
}

/// 钱包卡片复刻：横幅与二维码均来自 PassGenerator 的真实输出
private struct PassCardMock: View {
    private let ink = Color(red: 16.0/255, green: 42.0/255, blue: 87.0/255)
    private let generator = PassGenerator()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 左上角：动车组号（logoText 位）
            Text(tutorialDemoLog.emuNumber)
                .font(.caption.weight(.medium))
                .fontDesign(.monospaced)

            // 真实 strip 绘制结果
            if let img = generator.stripPreviewImage(for: tutorialDemoLog) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
            }

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("2026年03月17日 14:18开")
                    Text("04车01A号")
                }
                .font(.caption2)
                .opacity(0.8)
                Spacer()
                qrImage()
                    .frame(width: 48, height: 48)
                    .padding(4)
                    .background(.white, in: RoundedRectangle(cornerRadius: 6))
            }
        }
        .foregroundStyle(ink)
        .padding(14)
        .background(Color(red: 214.0/255, green: 234.0/255, blue: 246.0/255), in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
    }

    private func qrImage() -> Image {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else {
            return Image(systemName: "qrcode")
        }
        // 与真实卡片一致的二维码内容
        filter.setValue(Data(generator.barcodePreviewMessage(for: tutorialDemoLog).utf8), forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let out = filter.outputImage else { return Image(systemName: "qrcode") }
        let scaled = out.transformed(by: CGAffineTransform(scaleX: 4, y: 4))
        guard let cg = CIContext().createCGImage(scaled, from: scaled.extent) else {
            return Image(systemName: "qrcode")
        }
        return Image(uiImage: UIImage(cgImage: cg))
            .interpolation(.none)
            .resizable()
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
