import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var authStore: AuthStore
    @State private var emailOrPhone = ""
    @State private var password = ""
    @State private var displayName = ""
    @FocusState private var focusedField: ProfileField?

    var body: some View {
        ZStack {
            QiheColor.paper.ignoresSafeArea()
                .onTapGesture {
                    focusedField = nil
                    QiheKeyboard.dismiss()
                }

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    authCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, QiheLayout.rootTabBottomInset)
            }
            .qiheScrollDismissesKeyboard()
        }
        .navigationTitle("我的")
        .qiheInlineNavigationTitle()
    }

    private var header: some View {
        PaperCard(padding: 18) {
            HStack(alignment: .center, spacing: 16) {
                QiheBrandLockup(markSize: 44, titleSize: 23)

                Spacer(minLength: 10)

                QiheSloganLockup()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var authCard: some View {
        PaperCard(padding: 18) {
            authContent
        }
    }

    @ViewBuilder
    private var authContent: some View {
        switch authStore.status {
        case let .signedIn(user):
            signedInContent(user: user)
        case .signedOut:
            signedOutContent
        }
    }

    private func signedInContent(user: AuthUser) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(QiheColor.pine)
                    .frame(width: 40, height: 40)
                    .background(QiheColor.pineSoft)
                    .clipShape(RoundedRectangle(cornerRadius: QiheRadius.sm, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(user.displayName)
                        .font(QiheFont.body(size: 16, weight: .semibold))
                        .foregroundStyle(QiheColor.ink)
                        .lineLimit(1)

                    Text(user.account)
                        .font(QiheFont.caption(size: 12))
                        .foregroundStyle(QiheColor.muted)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)
            }

            if let message = authStore.message {
                statusMessage(message)
            }

            QiheSecondaryButton(title: "退出登录", systemImage: "rectangle.portrait.and.arrow.right") {
                authStore.signOut()
            }
        }
    }

    // MARK: - 验证码登录（任务五）

    private var signedOutContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 主流程：邮箱验证码登录
            VStack(alignment: .leading, spacing: 14) {
                Text("邮箱验证码登录")
                    .font(QiheFont.body(size: 14, weight: .semibold))
                    .foregroundStyle(QiheColor.ink)

                // Step 1: 邮箱输入
                VStack(alignment: .leading, spacing: 6) {
                    Text("邮箱")
                        .font(QiheFont.caption(size: 12, weight: .semibold))
                        .foregroundStyle(QiheColor.muted)

                    HStack(spacing: 10) {
                        TextField("请输入邮箱地址", text: $emailOrPhone)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .account)
                            .font(QiheFont.body(size: 14))
                            .foregroundStyle(QiheColor.ink)
                            .padding(.horizontal, 12)
                            .frame(height: 46)
                            .background(QiheColor.paper)
                            .clipShape(RoundedRectangle(cornerRadius: QiheRadius.sm, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: QiheRadius.sm, style: .continuous)
                                    .stroke(QiheColor.line, lineWidth: 1)
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
                            .frame(height: 46)
                            .padding(.horizontal, 14)
                            .background(
                                authStore.codeCountdown > 0 || authStore.isSendingCode
                                    ? QiheColor.muted
                                    : QiheColor.navy
                            )
                            .clipShape(RoundedRectangle(cornerRadius: QiheRadius.sm, style: .continuous))
                        }
                        .disabled(authStore.codeCountdown > 0 || authStore.isSendingCode || emailOrPhone.trimmedForInput.isEmpty)
                    }
                }

                // Step 2: 验证码输入（发送后显示）
                if authStore.showVerificationCode {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("验证码")
                            .font(QiheFont.caption(size: 12, weight: .semibold))
                            .foregroundStyle(QiheColor.muted)

                        TextField("请输入 6 位验证码", text: $authStore.verificationCode)
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .password)
                            .font(QiheFont.body(size: 14))
                            .foregroundStyle(QiheColor.ink)
                            .padding(.horizontal, 12)
                            .frame(height: 46)
                            .background(QiheColor.paper)
                            .clipShape(RoundedRectangle(cornerRadius: QiheRadius.sm, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: QiheRadius.sm, style: .continuous)
                                    .stroke(QiheColor.line, lineWidth: 1)
                            )
                            .onChange(of: authStore.verificationCode) { _, newValue in
                                // 限制最多 6 位
                                if newValue.count > 6 {
                                    authStore.verificationCode = String(newValue.prefix(6))
                                }
                            }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if let message = authStore.message {
                    statusMessage(message)
                }

                // 登录按钮
                QihePrimaryButton(
                    title: "登录",
                    systemImage: "envelope.badge.person.crop",
                    isLoading: authStore.isSubmitting,
                    isDisabled: authStore.isSubmitting || emailOrPhone.trimmedForInput.isEmpty
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

            Divider().background(QiheColor.line)

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
                }
                .buttonStyle(.plain)
            }
        }
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

                QihePrimaryButton(
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
            }
            .buttonStyle(.plain)
        }
    }

    private func statusMessage(_ message: String) -> some View {
        Text(message)
            .font(QiheFont.body(size: 13))
            .foregroundStyle(QiheColor.navy)
            .fixedSize(horizontal: false, vertical: true)
            .padding(11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(QiheColor.navySoft)
            .clipShape(RoundedRectangle(cornerRadius: QiheRadius.sm, style: .continuous))
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
                .font(QiheFont.caption(size: 12, weight: .semibold))
                .foregroundStyle(QiheColor.muted)

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
            .frame(height: 46)
            .background(QiheColor.paper)
            .clipShape(RoundedRectangle(cornerRadius: QiheRadius.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: QiheRadius.sm, style: .continuous)
                    .stroke(QiheColor.line, lineWidth: 1)
            )
        }
    }

}

private enum ProfileField: Hashable {
    case account
    case displayName
    case password
}
