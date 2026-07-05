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

                VStack(spacing: 14) {
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
