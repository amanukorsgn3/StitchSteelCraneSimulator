import Foundation

enum NetworkTransport {
    static func request(address: URL, method: String = "GET") -> URLRequest {
        var request = URLRequest(url: address, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData)
        request.httpMethod = method
        request.timeoutInterval = 12
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        return request
    }
}
