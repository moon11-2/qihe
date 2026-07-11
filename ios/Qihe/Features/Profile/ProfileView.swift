import Foundation
import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var appState: AppState
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var formControlMinHeight: CGFloat = 46
    @State private var emailOrPhone = ""
    @State private var password = ""
    @State private var displayName = ""
    @FocusState private var focusedField: ProfileField?

    /// 任务六：积分余额、激活码
    @State private var creditBalance: CreditBalance?
    @State private var activationCode = ""
    @State private var isRedeeming = false
    @State private var redeemMessage: String?
    @State private var showStorePaywall = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            QiheColor.pageBackgroundGradient.ignoresSafeArea()
                .onTapGesture {
                    focusedField = nil
                    QiheKeyboard.dismiss()
                }

            Circle()
                .fill(QiheColor.brandLight.opacity(0.14))
                .frame(width: 230, height: 230)
                .blur(radius: 10)
                .offset(x: 82, y: -102)
                .accessibilityHidden(true)

            ScrollView {
                Group {
                    switch authStore.status {
                    case let .signedIn(user):
                        signedInContent(user: user)
                    case .signedOut:
                        VStack(spacing: 24) {
                            loginHero
                            signedOutContent
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, authStore.status.isSignedIn ? 14 : 28)
                .padding(.bottom, QiheLayout.rootTabBottomInset)
            }
            .qiheScrollDismissesKeyboard()
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var loginHero: some View {
        VStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(QiheColor.neutral0.opacity(0.92))

                QiheLogoMark(size: 58)
            }
            .frame(width: 84, height: 84)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(QiheColor.neutral0, lineWidth: 1)
            )
            .shadow(color: QiheColor.shadowBlue, radius: 22, x: 0, y: 10)

            Text("契合")
                .font(QiheFont.body(size: 27, weight: .bold))
                .foregroundStyle(QiheColor.ink)
                .tracking(7)
                .padding(.leading, 7)
                .padding(.top, 18)

            Text("专业严谨的 AI 合同助手")
                .font(QiheFont.body(size: 14, weight: .medium))
                .foregroundStyle(QiheColor.inkSoft)
                .tracking(0.6)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
    }

    private func signedInContent(user: AuthUser) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("我的")
                .font(QiheFont.body(size: 22, weight: .bold))
                .foregroundStyle(QiheColor.ink)
                .padding(.vertical, 6)

            profileSummaryCard(user: user)
            creditBalanceCard

            Text("账户与服务")
                .font(QiheFont.caption(size: 13, weight: .semibold))
                .foregroundStyle(QiheColor.muted)
                .padding(.top, 2)
                .padding(.horizontal, 2)

            VStack(spacing: 0) {
                activationCodeSection

                Divider()
                    .overlay(QiheColor.line)
                    .padding(.leading, 62)

                if showStorePaywall {
                    storePaywallSection
                } else {
                    Button {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            showStorePaywall = true
                        }
                    } label: {
                        HStack(spacing: 12) {
                            serviceIcon(
                                systemName: "cart",
                                foreground: QiheColor.brandBlue,
                                background: QiheColor.infoBlueSoft
                            )

                            Text("购买积分")
                                .font(QiheFont.body(size: 15, weight: .medium))
                                .foregroundStyle(QiheColor.ink)
                                .lineLimit(1)

                            Spacer(minLength: 8)

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(QiheColor.lineStrong)
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 62)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .profileSurface(cornerRadius: 18)

            if let message = authStore.message {
                statusMessage(message)
            }

            Button {
                authStore.signOut()
            } label: {
                Label("退出登录", systemImage: "rectangle.portrait.and.arrow.right")
                    .font(QiheFont.body(size: 14, weight: .medium))
                    .foregroundStyle(QiheColor.muted)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .onAppear {
            Task { await fetchCredits() }
        }
    }

    private func profileSummaryCard(user: AuthUser) -> some View {
        HStack(spacing: 14) {
            Text(userInitial(for: user))
                .font(QiheFont.body(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 62, height: 62)
                .background(
                    LinearGradient(
                        colors: [QiheColor.brandFrost, QiheColor.brandBlue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Circle())
                .overlay(Circle().stroke(QiheColor.neutral0.opacity(0.8), lineWidth: 3))
                .shadow(color: QiheColor.shadowBlue, radius: 14, x: 0, y: 7)

            VStack(alignment: .leading, spacing: 5) {
                Text(user.displayName)
                    .font(QiheFont.body(size: 17, weight: .bold))
                    .foregroundStyle(QiheColor.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(user.account)
                    .font(QiheFont.caption(size: 12))
                    .foregroundStyle(QiheColor.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                if let plan = creditBalance?.plan?.nilIfBlank {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10, weight: .semibold))

                        Text(plan)
                            .lineLimit(1)
                    }
                    .font(QiheFont.micro(size: 11, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x92400E))
                    .padding(.horizontal, 9)
                    .frame(height: 24)
                    .background(Color(hex: 0xFEF3C7))
                    .clipShape(Capsule())
                }
            }

            Spacer(minLength: 0)

            QiheLogoMark(size: 34)
                .opacity(0.18)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 20)
        .background(
            LinearGradient(
                colors: [QiheColor.neutral0, QiheColor.neutral50],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(QiheColor.neutral0.opacity(0.92), lineWidth: 1)
        )
        .shadow(color: QiheColor.shadowNavy.opacity(0.8), radius: 16, x: 0, y: 7)
    }

    private func userInitial(for user: AuthUser) -> String {
        let source = user.displayName.nilIfBlank ?? user.account.nilIfBlank ?? "契"
        return String(source.prefix(1)).uppercased()
    }

    // MARK: - 积分余额（任务六）

    private var creditBalanceCard: some View {
        HStack(spacing: 14) {
            serviceIcon(
                systemName: "bolt.fill",
                foreground: .white,
                background: QiheColor.brandBlue
            )

            Text("可用积分")
                .font(QiheFont.body(size: 14, weight: .medium))
                .foregroundStyle(QiheColor.inkSoft)

            Spacer(minLength: 8)

            Text("\(creditBalance?.credits ?? 0)")
                .font(QiheFont.body(size: 25, weight: .bold))
                .foregroundStyle(creditBalanceTextColor)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text("积分")
                .font(QiheFont.caption(size: 12, weight: .medium))
                .foregroundStyle(QiheColor.muted)
                .padding(.leading, -8)
        }
        .padding(16)
        .profileSurface(cornerRadius: 18)
    }

    private var creditBalanceTextColor: Color {
        (creditBalance?.isLow ?? true) ? QiheColor.riskOrange : QiheColor.brandNavy
    }

    // MARK: - 激活码兑换（任务六）

    private var activationCodeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                serviceIcon(
                    systemName: "ticket",
                    foreground: QiheColor.safeGreen,
                    background: QiheColor.safeGreenSoft
                )

                Text("激活码兑换")
                    .font(QiheFont.body(size: 15, weight: .medium))
                    .foregroundStyle(QiheColor.ink)
            }

            HStack(spacing: 10) {
                TextField("输入激活码", text: $activationCode)
                    .font(QiheFont.body(size: 14))
                    .foregroundStyle(QiheColor.ink)
                    .autocapitalization(.allCharacters)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 12)
                    .frame(height: 46)
                    .background(QiheColor.neutral0)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(QiheColor.lineStrong.opacity(0.62), lineWidth: 1)
                    )

                Button {
                    QiheKeyboard.dismiss()
                    Task { await redeemCode() }
                } label: {
                    Group {
                        if isRedeeming {
                            ProgressView().tint(.white).scaleEffect(0.8)
                        } else {
                            Text("兑换")
                                .font(QiheFont.body(size: 14, weight: .semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.82)
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(width: 76, height: 46)
                    .background(redeemButtonBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .disabled(activationCode.trimmedForInput.isEmpty || isRedeeming)
            }

            if let redeemMessage {
                Text(redeemMessage)
                    .font(QiheFont.caption(size: 12))
                    .foregroundStyle(redeemMessage.contains("成功") ? QiheColor.safeGreen : QiheColor.riskRed)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        redeemMessage.contains("成功") ? QiheColor.safeGreenSoft : QiheColor.riskRedSoft
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .padding(16)
    }

    @ViewBuilder
    private var redeemButtonBackground: some View {
        if activationCode.trimmedForInput.isEmpty || isRedeeming {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(QiheColor.neutral300)
        } else {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(QiheColor.primaryGradient)
                .shadow(color: QiheColor.shadowBlue.opacity(0.7), radius: 10, x: 0, y: 4)
        }
    }

    // MARK: - StoreKit 购买积分（任务六，预留）

    private var storePaywallSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 12) {
                    serviceIcon(
                        systemName: "cart",
                        foreground: QiheColor.brandBlue,
                        background: QiheColor.infoBlueSoft
                    )

                    Text("购买积分")
                        .font(QiheFont.body(size: 15, weight: .medium))
                        .foregroundStyle(QiheColor.ink)
                }

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.22)) { showStorePaywall = false }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(QiheColor.muted)
                }
            }

            // 预留产品卡片
            ForEach([("20 积分", "¥6.00"), ("60 积分", "¥12.00"), ("150 积分", "¥28.00")], id: \.0) { name, price in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(name)
                            .font(QiheFont.body(size: 14, weight: .semibold))
                            .foregroundStyle(QiheColor.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                        Text("一次性购买")
                            .font(QiheFont.caption(size: 11))
                            .foregroundStyle(QiheColor.muted)
                            .lineLimit(1)
                    }
                    Spacer()
                    Text(price)
                        .font(QiheFont.body(size: 16, weight: .bold))
                        .foregroundStyle(QiheColor.brandBlue)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .padding(.horizontal, 14)
                        .frame(height: 36)
                        .background(QiheColor.infoBlueSoft)
                        .clipShape(RoundedRectangle(cornerRadius: QiheRadius.sm, style: .continuous))
                }
                .padding(12)
                .background(QiheColor.neutral50)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(QiheColor.line, lineWidth: 1)
                )
            }

            Text("后续将接入 StoreKit 内购，当前为占位示意。")
                .font(QiheFont.caption(size: 11))
                .foregroundStyle(QiheColor.muted)
        }
        .padding(16)
    }

    private func serviceIcon(systemName: String, foreground: Color, background: Color) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(foreground)
            .frame(width: 34, height: 34)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    // MARK: - 积分方法（任务六）

    private func fetchCredits() async {
        guard authStore.status.isSignedIn else { return }
        do {
            creditBalance = try await appState.apiClient.getBalance()
        } catch {
            // 静默失败
        }
    }

    private func redeemCode() async {
        let code = activationCode.trimmedForInput
        guard !code.isEmpty else { return }
        isRedeeming = true
        redeemMessage = nil
        defer { isRedeeming = false }

        do {
            let response = try await appState.apiClient.redeemCode(code: code)
            redeemMessage = response.displayMessage
            if response.success {
                activationCode = ""
                await fetchCredits()
            }
        } catch {
            redeemMessage = error.qiheDisplayMessage
        }
    }

    // MARK: - 验证码登录（任务五）

    private var signedOutContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 主流程：邮箱验证码登录
            VStack(alignment: .leading, spacing: 14) {
                Text("邮箱验证码登录")
                    .font(QiheFont.body(size: 17, weight: .bold))
                    .foregroundStyle(QiheColor.ink)

                // Step 1: 邮箱输入
                VStack(alignment: .leading, spacing: 7) {
                    Text("邮箱")
                        .font(QiheFont.caption(size: 13, weight: .semibold))
                        .foregroundStyle(QiheColor.inkSoft)

                    emailFieldLayout {
                        TextField("请输入邮箱地址", text: $emailOrPhone)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .account)
                            .font(QiheFont.body(size: 14))
                            .foregroundStyle(QiheColor.ink)
                            .padding(.horizontal, 12)
                            .frame(minHeight: formControlMinHeight)
                            .background(QiheColor.neutral0)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(QiheColor.lineStrong.opacity(0.62), lineWidth: 1)
                            )

                        Button {
                            focusedField = nil
                            QiheKeyboard.dismiss()
                            Task {
                                await authStore.sendVerificationCode(email: emailOrPhone)
                            }
                        } label: {
                            Group {
                                if authStore.isSendingCode {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(.white)
                                        .scaleEffect(0.8)
                                } else if authStore.codeCountdown > 0 {
                                    Text("\(authStore.codeCountdown)s")
                                        .font(QiheFont.body(size: 14, weight: .semibold))
                                } else {
                                    Text("发送验证码")
                                        .font(QiheFont.body(size: 13, weight: .semibold))
                                }
                            }
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .frame(width: dynamicTypeSize.isAccessibilitySize ? nil : 102)
                            .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil)
                            .frame(minHeight: formControlMinHeight)
                            .background(sendCodeButtonBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .disabled(isSendCodeDisabled)
                    }
                }

                // Step 2: 验证码输入（发送后显示）
                if authStore.showVerificationCode {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("验证码")
                            .font(QiheFont.caption(size: 13, weight: .semibold))
                            .foregroundStyle(QiheColor.inkSoft)

                        TextField("请输入 6 位验证码", text: $authStore.verificationCode)
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .password)
                            .font(QiheFont.body(size: 14))
                            .foregroundStyle(QiheColor.ink)
                            .padding(.horizontal, 12)
                            .frame(minHeight: formControlMinHeight)
                            .background(QiheColor.neutral0)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(QiheColor.lineStrong.opacity(0.62), lineWidth: 1)
                            )
                            .onChange(of: authStore.verificationCode) { _, newValue in
                                let normalizedCode = String(
                                    newValue.filter { "0123456789".contains($0) }.prefix(6)
                                )
                                if normalizedCode != newValue {
                                    authStore.verificationCode = normalizedCode
                                }
                            }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if let message = authStore.message {
                    statusMessage(message)
                }

                // 登录按钮
                ProfileActionButton(
                    title: "登录",
                    systemImage: "envelope.badge.person.crop",
                    isLoading: authStore.isSubmitting,
                    isDisabled: isVerificationLoginDisabled
                ) {
                    focusedField = nil
                    QiheKeyboard.dismiss()
                    if authStore.showVerificationCode {
                        Task {
                            await authStore.verifyCode(
                                email: emailOrPhone,
                                code: authStore.verificationCode
                            )
                        }
                    } else {
                        Task {
                            await authStore.sendVerificationCode(email: emailOrPhone)
                        }
                    }
                }
            }

            Divider()
                .overlay(QiheColor.line)

            // 旧密码登录入口（默认隐藏，点击展开）
            if authStore.showPasswordLogin {
                legacyPasswordLogin
            } else {
                Button {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        authStore.showPasswordLogin = true
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "key")
                            .font(.system(size: 12))
                        Text("使用密码登录")
                            .font(QiheFont.caption(size: 12))
                    }
                    .foregroundStyle(QiheColor.muted)
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .profileSurface(cornerRadius: 18)
    }

    @ViewBuilder
    private var sendCodeButtonBackground: some View {
        if isSendCodeDisabled {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(QiheColor.neutral300)
        } else {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(QiheColor.primaryGradient)
                .shadow(color: QiheColor.shadowBlue.opacity(0.7), radius: 10, x: 0, y: 4)
        }
    }

    private var emailFieldLayout: AnyLayout {
        if dynamicTypeSize.isAccessibilitySize {
            AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
        } else {
            AnyLayout(HStackLayout(spacing: 10))
        }
    }

    private var normalizedEmail: String {
        emailOrPhone.trimmedForInput.lowercased()
    }

    private var isEmailValid: Bool {
        let parts = normalizedEmail.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return false }
        let localPart = parts[0]
        guard !localPart.isEmpty,
              !localPart.hasPrefix("."),
              !localPart.hasSuffix("."),
              !localPart.contains("..") else {
            return false
        }

        return normalizedEmail.range(
            of: #"^[A-Z0-9._%+-]+@(?:[A-Z0-9](?:[A-Z0-9-]{0,61}[A-Z0-9])?\.)+[A-Z]{2,63}$"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }

    private var isVerificationCodeValid: Bool {
        let code = authStore.verificationCode.trimmedForInput
        return code.count == 6 && code.allSatisfy { "0123456789".contains($0) }
    }

    private var isSendCodeDisabled: Bool {
        !isEmailValid || authStore.codeCountdown > 0 || authStore.isSendingCode
    }

    private var isVerificationLoginDisabled: Bool {
        if authStore.isSubmitting || !isEmailValid {
            return true
        }
        if authStore.showVerificationCode {
            return !isVerificationCodeValid
        }
        return authStore.isSendingCode
    }

    // MARK: - 旧密码登录（保留，默认隐藏）

    private var legacyPasswordLogin: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("账号操作", selection: Binding(
                get: { authStore.mode },
                set: { authStore.switchMode($0) }
            )) {
                ForEach(AuthMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(3)
            .background(QiheColor.neutral100.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

            VStack(alignment: .leading, spacing: 14) {
                VStack(spacing: 14) {
                    profileField(
                        title: "邮箱",
                        placeholder: "请输入邮箱地址",
                        text: $emailOrPhone,
                        field: .account
                    )

                    if authStore.mode == .register {
                        profileField(
                            title: "昵称",
                            placeholder: "可选",
                            text: $displayName,
                            field: .displayName
                        )
                    }

                    profileField(
                        title: "密码",
                        placeholder: "至少 8 位",
                        text: $password,
                        field: .password,
                        isSecure: true
                    )
                }

                if authStore.mode == .register {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(QiheColor.pine)
                        Text("注册无需验证码。")
                            .font(QiheFont.caption(size: 12))
                            .foregroundStyle(QiheColor.muted)
                    }
                }

                if let message = authStore.message {
                    statusMessage(message)
                }

                ProfileActionButton(
                    title: authStore.mode.title,
                    systemImage: authStore.mode == .login ? "person.crop.circle" : "person.badge.plus",
                    isLoading: authStore.isSubmitting,
                    isDisabled: authStore.isSubmitting
                ) {
                    focusedField = nil
                    QiheKeyboard.dismiss()
                    Task {
                        await authStore.submit(
                            emailOrPhone: emailOrPhone,
                            password: password,
                            displayName: displayName
                        )
                    }
                }
            }

            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    authStore.showPasswordLogin = false
                    authStore.message = nil
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "envelope")
                        .font(.system(size: 12))
                    Text("使用验证码登录")
                        .font(QiheFont.caption(size: 12))
                }
                .foregroundStyle(QiheColor.muted)
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func statusMessage(_ message: String) -> some View {
        Text(message)
            .font(QiheFont.body(size: 13))
            .foregroundStyle(QiheColor.brandBlue)
            .fixedSize(horizontal: false, vertical: true)
            .padding(11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(QiheColor.infoBlueSoft)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func profileField(
        title: String,
        placeholder: String,
        text: Binding<String>,
        field: ProfileField,
        isSecure: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(QiheFont.caption(size: 13, weight: .semibold))
                .foregroundStyle(QiheColor.inkSoft)

            Group {
                if isSecure {
                    SecureField(placeholder, text: text)
                } else {
                    TextField(placeholder, text: text)
                }
            }
            .autocorrectionDisabled()
            .focused($focusedField, equals: field)
            .font(QiheFont.body(size: 14))
            .foregroundStyle(QiheColor.ink)
            .padding(.horizontal, 12)
            .frame(minHeight: formControlMinHeight)
            .background(QiheColor.neutral0)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(QiheColor.lineStrong.opacity(0.62), lineWidth: 1)
            )
        }
    }

}

private enum ProfileField: Hashable {
    case account
    case displayName
    case password
}

private struct ProfileActionButton: View {
    let title: String
    let systemImage: String
    var isLoading = false
    var isDisabled = false
    let action: () -> Void
    @ScaledMetric(relativeTo: .body) private var minHeight: CGFloat = 48

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: systemImage)
                        .font(.system(size: 15, weight: .semibold))
                }

                Text(title)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(QiheFont.body(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .frame(minHeight: minHeight)
            .background {
                if isDisabled {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(QiheColor.neutral300)
                } else {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(QiheColor.primaryGradient)
                        .shadow(color: QiheColor.shadowBlue, radius: 14, x: 0, y: 7)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
        .accessibilityLabel(title)
    }
}

private struct ProfileSurfaceModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(QiheColor.glassFill)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(QiheColor.neutral0.opacity(0.9), lineWidth: 1)
            )
            .shadow(color: QiheColor.shadowNavySoft, radius: 10, x: 0, y: 4)
    }
}

private extension View {
    func profileSurface(cornerRadius: CGFloat) -> some View {
        modifier(ProfileSurfaceModifier(cornerRadius: cornerRadius))
    }
}
