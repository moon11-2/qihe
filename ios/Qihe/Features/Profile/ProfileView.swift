import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var appState: AppState
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
                VStack(alignment: .leading, spacing: 16) {
                    header
                    authCard
                    apiNotice
                    handoffFields
                }
                .padding(20)
            }
            .qiheScrollDismissesKeyboard()
        }
        .navigationTitle("我的")
        .qiheInlineNavigationTitle()
    }

    private var header: some View {
        PaperCard(padding: 16) {
            HStack(spacing: 14) {
                SealMark(size: 48)

                VStack(alignment: .leading, spacing: 5) {
                    Text("契合账号")
                        .font(QiheFont.title(size: 20))
                        .foregroundStyle(QiheColor.ink)

                    Text("可选登录；不影响合同审查、生成和过程对话。")
                        .font(QiheFont.body(size: 13))
                        .foregroundStyle(QiheColor.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var authCard: some View {
        PaperCard(padding: 14) {
            VStack(alignment: .leading, spacing: 14) {
                Picker("账号操作", selection: Binding(
                    get: { authStore.mode },
                    set: { authStore.switchMode($0) }
                )) {
                    ForEach(AuthMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                VStack(spacing: 12) {
                    profileField(
                        title: "账号",
                        placeholder: "手机号或邮箱",
                        text: $emailOrPhone,
                        field: .account
                    )

                    if authStore.mode == .register {
                        profileField(
                            title: "昵称",
                            placeholder: "用于展示的名称",
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

                if let message = authStore.message {
                    Text(message)
                        .font(QiheFont.body(size: 13))
                        .foregroundStyle(QiheColor.navy)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(11)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(QiheColor.navySoft)
                        .clipShape(RoundedRectangle(cornerRadius: QiheRadius.sm, style: .continuous))
                }

                QihePrimaryButton(
                    title: authStore.mode.title,
                    systemImage: authStore.mode == .login ? "person.crop.circle" : "person.badge.plus"
                ) {
                    focusedField = nil
                    QiheKeyboard.dismiss()
                    authStore.submitShell(
                        emailOrPhone: emailOrPhone,
                        password: password,
                        displayName: displayName
                    )
                }
            }
        }
    }

    private var apiNotice: some View {
        PaperCard(padding: 14) {
            VStack(alignment: .leading, spacing: 9) {
                Label("当前为账号前端壳", systemImage: "person.crop.circle.badge.clock")
                    .font(QiheFont.body(size: 15, weight: .semibold))
                    .foregroundStyle(QiheColor.ink)

                Text("后端接口确认后再接入真实登录态和 Bearer Token；本阶段不写死 token，也不要求登录后才能使用核心功能。")
                    .font(QiheFont.body(size: 13))
                    .foregroundStyle(QiheColor.muted)
                    .fixedSize(horizontal: false, vertical: true)

                QiheSecondaryButton(title: "回到首页", systemImage: "house") {
                    appState.resetToHome()
                }
            }
        }
    }

    private var handoffFields: some View {
        PaperCard(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Text("等待后端确认")
                    .font(QiheFont.body(size: 15, weight: .semibold))
                    .foregroundStyle(QiheColor.ink)

                VStack(alignment: .leading, spacing: 7) {
                    handoffRow("注册字段", "account / password / display_name")
                    handoffRow("登录字段", "account / password")
                    handoffRow("登录返回", "access_token / token_type / user")
                    handoffRow("用户信息", "id / display_name / account")
                }
            }
        }
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
            .frame(height: 42)
            .background(QiheColor.paper)
            .clipShape(RoundedRectangle(cornerRadius: QiheRadius.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: QiheRadius.sm, style: .continuous)
                    .stroke(QiheColor.line, lineWidth: 1)
            )
        }
    }

    private func handoffRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label)
                .font(QiheFont.caption(size: 12, weight: .semibold))
                .foregroundStyle(QiheColor.navy)
                .frame(width: 66, alignment: .leading)

            Text(value)
                .font(QiheFont.caption(size: 12))
                .foregroundStyle(QiheColor.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private enum ProfileField: Hashable {
    case account
    case displayName
    case password
}
