import Foundation
import Combine

@available(iOS 15.0, *)
@available(macOS 12.0, *)
public protocol NetworkRequestable {
    var requestTimeOut: Int { get }
    func request<T: Decodable>(_ req: NetworkRequestRepresentable, onComplete: @escaping (Result<T, NetworkRequestError>) -> Void)
    func request<T>(_ req: NetworkRequestRepresentable) -> AnyPublisher<T, URLError> where T: Decodable
    func request<T: Decodable>(_ req: NetworkRequestRepresentable) async -> Result<T, NetworkRequestError>
}

@available(iOS 15.0, *)
@available(macOS 12.0, *)

public class NetworkRequester: NetworkRequestable {
    
    public var requestTimeOut: Int = 30

    public init() {}
    
    public func request<T: Decodable>(_ req: NetworkRequestRepresentable) async -> Result<T, NetworkRequestError> {
        if let timeout = req.timeout {
            let sessionConfig = URLSessionConfiguration.default
            sessionConfig.timeoutIntervalForRequest = TimeInterval(timeout)
        } else {
            let sessionConfig = URLSessionConfiguration.default
            sessionConfig.timeoutIntervalForRequest = TimeInterval(requestTimeOut)
        }
        
        guard let url = URL(string: req.url) else {
            return .failure(NetworkRequestError.badURL("Invalid URL"))
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            if let error = (response as? HTTPURLResponse)?.getResponseError(with: data.toJSONString()) {
                return .failure(error)
            }
            
            guard let response = try? JSONDecoder().decode(T.self, from: data) else {
                return .failure(.unableToParseData("Unable to decode data received"))
            }
            return .success(response)
        } catch {
            return .failure(.unknown("Session failed."))
        }
    }
    
    public func request<T>(_ req: NetworkRequestRepresentable, onComplete: @escaping (Result<T, NetworkRequestError>) -> Void) where T: Decodable {
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
    
    public func request<T>(_ req: NetworkRequestRepresentable) -> AnyPublisher<T, URLError> where T: Decodable {
        func emptyPublisher(completeImmediately: Bool = true) -> AnyPublisher<T, URLError> {
           Empty<T, URLError>(completeImmediately: true).eraseToAnyPublisher()
        }

        if let timeout = req.timeout {
            let sessionConfig = URLSessionConfiguration.default
            sessionConfig.timeoutIntervalForRequest = TimeInterval(timeout)
        } else {
            let sessionConfig = URLSessionConfiguration.default
            sessionConfig.timeoutIntervalForRequest = TimeInterval(requestTimeOut)
        }
        
        guard let url = URL(string: req.url) else {
            return emptyPublisher()
        }
        
        return URLSession.shared
            .dataTaskPublisher(for: req.buildURLRequest(with: url))
            .tryMap {
                guard let httpResponse = $0.response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                switch httpResponse.statusCode {
                case 401:
                    throw URLError(.userAuthenticationRequired)
                case 400,402...499:
                    throw URLError(.dataNotAllowed)
                case 500...599:
                    throw URLError(.badServerResponse)
                default:
                    break
                }
                return $0.data
            }
            .decode(type: T.self, decoder: JSONDecoder())
            .mapError({ _ in
                URLError(.cannotParseResponse)
            })
            .eraseToAnyPublisher()
        
    }
}


@available(macOS 12.0, *)
@available(iOS 15.0, *)
extension Publisher {
  func tryDecodeResponse<Item, Coder>(type: Item.Type, decoder: Coder) -> Publishers.Decode<Publishers.TryMap<Self, Data>, Item, Coder> where Item: Decodable, Coder: TopLevelDecoder, Self.Output == (data: Data, response: URLResponse) {
    return self
      .tryMap { output in
        guard let httpResponse = output.response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NetworkRequestError.serverError("Bad Server Response")
        }
        return output.data
      }
      .decode(type: type, decoder: decoder)
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
