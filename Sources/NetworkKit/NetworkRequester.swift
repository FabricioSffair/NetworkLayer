//
//  Request.swift
//  BiometryksTest
//
//  Created by Fabrício Sperotto Sffair on 2021-10-08.
//

import Foundation

public protocol NetworkRequestable {
    var requestTimeOut: Int { get }
    func request<T: Decodable>(_ req: NetworkRequest, onComplete: @escaping (Result<T, NetworkRequestError>) -> Void)
}

public class NetworkRequester: NetworkRequestable {
    
    public var requestTimeOut: Int = 30

    public init() {}
    
    public func request<T>(_ req: NetworkRequest, onComplete: @escaping (Result<T, NetworkRequestError>) -> Void) where T: Decodable {
        if let timeout = req.timeout {
            let sessionConfig = URLSessionConfiguration.default
            sessionConfig.timeoutIntervalForRequest = TimeInterval(timeout)
        } else {
            let sessionConfig = URLSessionConfiguration.default
            sessionConfig.timeoutIntervalForRequest = TimeInterval(requestTimeOut)
        }
        
        guard let url = URL(string: req.url) else {
            onComplete(.failure(.badURL("Invalid url")))
            return
        }
        
        let task = URLSession.shared.dataTask(with: req.buildURLRequest(with: url),
                                              completionHandler: { (data, response, error) in
            if let response = response {
                response.handleResponse(data: data,
                                         error: error,
                                         completion: onComplete)
            } else {
                onComplete(.failure(NetworkRequestError.unknown(error?.localizedDescription ?? "")))
            }
        })
        task.resume()
    }
}


extension URLResponse {
    public func handleResponse<T: Decodable>(data: Data?,
                                    error: Error?,
                                    completion: @escaping (Result<T, NetworkRequestError>) -> Void) {
        if let error = error {
            return completion(.failure(.unknown(error.localizedDescription)))
        }
        guard let response = self as? HTTPURLResponse else {
            return completion(.failure(.noResponse("Unable to handle response. Did not receive response.")))
        }
        guard let data = data else {
            completion(.failure(.unableToParseData("Data is nil")))
            return
        }
        if let responseError = response.getResponseError(with: data.toJSONString()) {
            completion(.failure(responseError))
            return
        }
        
        do {
            let model = try JSONDecoder().decode(T.self, from: data)
            completion(.success(model))
        } catch let error as NSError {
            let escapeChars: Set<Character> = ["\\", "\""]
            var errorDescription = error.userInfo.description
            errorDescription.removeAll { escapeChars.contains($0) }
            errorDescription.append(" Input:\n")
            errorDescription.append(data.toJSONString())
            completion(.failure(.invalidJSON(errorDescription)))
        }
    }
}


extension HTTPURLResponse {
    public func getResponseError(with message: String) -> NetworkRequestError? {
        switch self.statusCode {
        case 200...299:
            return nil
        case 401:
            return .unauthorized("\(statusCode) error response. \(message)")
        case 400, 402...499:
            return .badRequest("\(statusCode) error response. \(message)")
        case 500...599:
            return .serverError("\(statusCode) error response. \(message)")
        default:
            return .unknown("\(statusCode) error response. \(message)")
        }
    }
}

extension Data {
    func toJSONString() -> String {
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: self, options: [])
            return String(data: try JSONSerialization.data(
                withJSONObject: jsonObject, options: [.prettyPrinted]),
                          encoding: String.Encoding(rawValue: String.Encoding.utf8.rawValue))
                ?? "Could not convert JSON object to utf8 string"
        } catch let error as NSError {
            let stringData = String(data: self, encoding: .utf8) ?? "Could not convert data to utf8 string"
            return "\(String(describing: error.userInfo)). Input: \(stringData)"
        }
    }
    
    func toStructFromJSONData<T: Decodable>() -> T? {
        try? JSONDecoder().decode(T.self, from: self)
    }
}
