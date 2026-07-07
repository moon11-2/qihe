import Foundation

@MainActor
final class AuthStore: ObservableObject {
    @Published var mode: AuthMode = .login
    @Published private(set) var status: AuthStatus = .signedOut
    @Published var isSubmitting = false
    @Published var message: String?

    /// 任务五：验证码登录
    @Published var showVerificationCode = false
    @Published var verificationCode = ""
    @Published var codeCountdown = 0
    @Published var isSendingCode = false
    private var countdownTimer: Timer?

    /// 任务五：是否显示旧密码登录入口（默认隐藏）
    @Published var showPasswordLogin = false

    private let apiClient: APIClient
    private let sessionStorage: AuthSessionStorage

    init(apiClient: APIClient = .local, sessionStorage: AuthSessionStorage = .shared) {
        self.apiClient = apiClient
        self.sessionStorage = sessionStorage
        if let session = sessionStorage.load() {
            status = .signedIn(session.user)
        }
    }

    func switchMode(_ mode: AuthMode) {
        self.mode = mode
        message = nil
        showVerificationCode = false
        verificationCode = ""
        stopCountdown()
    }

    func submit(emailOrPhone: String, password: String, displayName: String?) async {
        guard !isSubmitting else {
            return
        }

        let account = emailOrPhone.trimmedForInput.lowercased()
        let password = password.trimmedForInput
        let displayName = displayName?.nilIfBlank

        guard !account.isEmpty, !password.isEmpty else {
            message = "请先填写账号和密码。"
            return
        }

        guard account.contains("@") else {
            message = "当前后端账号使用邮箱登录。"
            return
        }

        if mode == .register, password.count < 8 {
            message = "密码至少 8 位。"
            return
        }

        isSubmitting = true
        message = nil
        defer { isSubmitting = false }

        do {
            let session: AuthSession
            switch mode {
            case .login:
                session = try await apiClient.login(email: account, password: password)
            case .register:
                session = try await apiClient.register(email: account, password: password, displayName: displayName)
            }
            sessionStorage.save(session)
            status = .signedIn(session.user)
            message = mode == .register ? "注册成功，已登录。" : "登录成功。"
        } catch {
            message = error.qiheDisplayMessage
        }
    }

    // MARK: - 验证码登录（任务五）

    /// 发送邮箱验证码
    func sendVerificationCode(email: String) async {
        let account = email.trimmedForInput.lowercased()
        guard account.contains("@"), !account.isEmpty else {
            message = "请输入有效的邮箱地址。"
            return
        }

        guard codeCountdown <= 0 else { return }

        isSendingCode = true
        message = nil
        defer { isSendingCode = false }

        do {
            try await apiClient.sendVerificationCode(email: account)
            showVerificationCode = true
            verificationCode = ""
            startCountdown()
            message = "验证码已发送，请查收邮箱。"
        } catch {
            message = error.qiheDisplayMessage
        }
    }

    /// 验证码登录
    func verifyCode(email: String, code: String) async {
        let account = email.trimmedForInput.lowercased()
        let code = code.trimmedForInput

        guard !account.isEmpty, code.count >= 6 else {
            message = "请输入邮箱和 6 位验证码。"
            return
        }

        isSubmitting = true
        message = nil
        defer { isSubmitting = false }

        do {
            let session = try await apiClient.verifyCode(email: account, code: code)
            sessionStorage.save(session)
            status = .signedIn(session.user)
            message = "登录成功。"
            stopCountdown()
        } catch {
            message = error.qiheDisplayMessage
        }
    }

    private func startCountdown() {
        stopCountdown()
        codeCountdown = 60
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.codeCountdown > 0 {
                    self.codeCountdown -= 1
                } else {
                    self.stopCountdown()
                }
            }
        }
    }

    private func stopCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        codeCountdown = 0
    }

    func signOut() {
        sessionStorage.clear()
        status = .signedOut
        message = "已退出登录。"
    }

    func requestSignIn() {
        mode = .login
        message = "请登录后使用"
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

struct AuthSession: Codable, Equatable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    let user: AuthUser
}

extension AuthUser: Codable {}

final class AuthSessionStorage: @unchecked Sendable {
    static let shared = AuthSessionStorage()

    private let defaults: UserDefaults
    private let key = "qihe.auth.session"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var accessToken: String? {
        load()?.accessToken.nilIfBlank
    }

    func load() -> AuthSession? {
        guard let data = defaults.data(forKey: key) else {
            return nil
        }
        return try? JSONDecoder().decode(AuthSession.self, from: data)
    }

    func save(_ session: AuthSession) {
        guard let data = try? JSONEncoder().encode(session) else {
            return
        }
        defaults.set(data, forKey: key)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}
