//
//  API.swift
//  BiometryksTest
//
//  Created by Fabrício Sperotto Sffair on 2021-10-08.
//

import Foundation

public enum HTTPMethod: String {
    case GET, POST, PUT, DELETE
}


@available(macOS 12.0, *)
@available(iOS 13.0, *)
public protocol NetworkServicable {
    var networkRequester: NetworkRequestable { get }
}

public protocol NetworkRequestRepresentable {
    var timeout: Float? { get }
    var url: String { get }
    var headers: [String: String]? { get }
    var httpMethod: HTTPMethod { get }
    var body: Encodable? { get }
    func buildURLRequest(with url: URL) -> URLRequest
}

public struct NetworkRequest: NetworkRequestRepresentable {
    public let url: String
    public let headers: [String: String]?
    public let body: Encodable?
    public let timeout: Float?
    public let httpMethod: HTTPMethod
    
    public init(url: String,
                headers: [String: String]?,
                body: Encodable?,
                timeout: Float?,
                httpMethod: HTTPMethod) {
        self.url = url
        self.headers = headers
        self.body = body
        self.timeout = timeout
        self.httpMethod = httpMethod
    }
    
    public func buildURLRequest(with url: URL) -> URLRequest {
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = httpMethod.rawValue
        urlRequest.allHTTPHeaderFields = headers ?? [:]
        urlRequest.httpBody = body?.encode()
        return urlRequest
    }
}


public enum NetworkRequestError: Error {
    case badURL(_ error: String)
    case apiError(_ error: String)
    case invalidJSON(_ error: String)
    case unauthorized(_ error: String)
    case badRequest(_ error: String)
    case serverError(_ error: String)
    case noResponse(_ error: String)
    case unableToParseData(_ error: String)
    case unknown(_ error: String)
}

extension Encodable {
    public func encode() -> Data? {
        do {
            return try JSONEncoder().encode(self)
        } catch {
            return nil
        }
    }
}
