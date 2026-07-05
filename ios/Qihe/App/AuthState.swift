import Foundation

@MainActor
final class AuthStore: ObservableObject {
    @Published var mode: AuthMode = .login
    @Published var status: AuthStatus = .signedOut
    @Published var message: String?

    func switchMode(_ mode: AuthMode) {
        self.mode = mode
        message = nil
    }

    func submitShell(emailOrPhone: String, password: String, displayName: String?) {
        let account = emailOrPhone.trimmedForInput
        let password = password.trimmedForInput
        let displayName = displayName?.trimmedForInput

        guard !account.isEmpty, !password.isEmpty else {
            message = "请先填写账号和密码。"
            return
        }

        if mode == .register, displayName?.nilIfBlank == nil {
            message = "请填写昵称，后续会作为账号显示名。"
            return
        }

        message = "账号接口待后端合同确认后接入；审查、生成和对话仍可直接使用。"
    }
}

enum AuthMode: String, CaseIterable, Identifiable {
    case login
    case register

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .login:
            return "登录"
        case .register:
            return "注册"
        }
    }
}

enum AuthStatus: Equatable {
    case signedOut
    case signedIn(AuthUser)

    var isSignedIn: Bool {
        if case .signedIn = self {
            return true
        }
        return false
    }
}

struct AuthUser: Equatable, Hashable {
    let id: String
    let displayName: String
    let account: String
}

