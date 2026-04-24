import Foundation

enum CoachServiceFactory {
    static func makeService(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        userDefaults: UserDefaults = .standard
    ) -> any CoachService {
        if let rawBaseURL = environment["AIBIC_API_BASE_URL"],
           !rawBaseURL.isEmpty,
           let baseURL = URL(string: rawBaseURL) {
            return RemoteCoachService(
                baseURL: baseURL,
                installationID: installationID(environment: environment, userDefaults: userDefaults),
                localeIdentifier: environment["AIBIC_LOCALE"] ?? Locale.current.identifier,
                appVersion: environment["AIBIC_APP_VERSION"] ?? appVersion
            )
        }

        let hasSeededResume = environment["AIBIC_UI_TEST_READY_RESUME"] == "1"
        let processingDelayNanoseconds: UInt64 = environment["AIBIC_UI_TEST_FAST"] == "1" ? 0 : 350_000_000

        return MockCoachService(
            processingDelayNanoseconds: processingDelayNanoseconds,
            initialActiveResume: hasSeededResume ? .readyUsable(fileName: "alex_pm_resume.pdf") : nil
        )
    }
}

private extension CoachServiceFactory {
    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    static func installationID(environment: [String: String], userDefaults: UserDefaults) -> String {
        if let installationID = environment["AIBIC_INSTALLATION_ID"], !installationID.isEmpty {
            return installationID
        }

        let key = "AIBICInstallationID"
        if let existingInstallationID = userDefaults.string(forKey: key), !existingInstallationID.isEmpty {
            return existingInstallationID
        }

        let newInstallationID = UUID().uuidString
        userDefaults.set(newInstallationID, forKey: key)
        return newInstallationID
    }
}
