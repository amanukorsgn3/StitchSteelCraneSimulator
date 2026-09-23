import Foundation

enum BridgeResolution {
    case session(token: String, address: String)
    case none
    case offline
}

final class BridgeService {
    private let endpoint = AppConstants.bridgeEndpoint
    private let partner = AppConstants.partnerCode

    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.urlCache = nil
        return URLSession(configuration: configuration)
    }()

    func resolve(completion: @escaping (BridgeResolution) -> Void) {
        guard let request = makeRequest() else {
            completion(.none)
            return
        }
        let task = session.dataTask(with: request) { data, _, error in
            var result: BridgeResolution = .none
            if let error, Self.isOffline(error) {
                result = .offline
            } else if let data, let body = String(data: data, encoding: .utf8) {
                result = Self.parse(body)
            }
            DispatchQueue.main.async {
                completion(result)
            }
        }
        task.resume()
    }

    private func makeRequest() -> URLRequest? {
        let raw = "p=\(partner)&os=\(DeviceInfo.systemDescription)&lng=\(DeviceInfo.primaryLanguage)&devicemodel=\(DeviceInfo.hardwareModel)&country=\(DeviceInfo.regionCode)"
        let encoded = Data(raw.utf8).base64EncodedString()
        guard let allowed = encoded.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let target = URL(string: endpoint + allowed) else {
            return nil
        }
        let request = NetworkTransport.request(address: target, method: "GET")
        return request
    }

    private static func parse(_ body: String) -> BridgeResolution {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let separatorIndex = trimmed.firstIndex(of: "#") else {
            return .none
        }
        let token = String(trimmed[trimmed.startIndex..<separatorIndex])
        let address = String(trimmed[trimmed.index(after: separatorIndex)...])
        guard !address.isEmpty else { return .none }
        return .session(token: token, address: address)
    }

    private static func isOffline(_ error: Error) -> Bool {
        guard let networkError = error as? URLError else { return false }
        let offlineCodes: [URLError.Code] = [
            .notConnectedToInternet,
            .networkConnectionLost,
            .cannotFindHost,
            .cannotConnectToHost,
            .dnsLookupFailed,
            .timedOut
        ]
        return offlineCodes.contains(networkError.code)
    }
}
