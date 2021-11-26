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


public protocol NetworkServicable {
    var networkRequester: NetworkRequestable { get }
}

public struct NetworkRequest {
    let url: String
    let headers: [String: String]?
    let body: Encodable?
    let timeout: Float?
    let httpMethod: HTTPMethod
    
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
