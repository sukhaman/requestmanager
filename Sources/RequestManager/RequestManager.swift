

import Foundation
import Combine

public enum NetworkError: Error {
    case statusCode
    case custom(error: Error)
    
}

extension NetworkError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .statusCode:
            return NSLocalizedString("Request failed due to invalid status code.", comment: "")
        case .custom(let error):
            return error.localizedDescription
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .statusCode:
            return NSLocalizedString("Please check the request and try again.", comment: "")
        case .custom:
            return NSLocalizedString("Please try again later.", comment: "")
        }
    }
}

public class RequestManager {
    private init() {}
    
    public static func fetchData<T: Decodable>(from request: URLRequest) -> AnyPublisher<T, Error> {
        return URLSession.shared.dataTaskPublisher(for: request)
            .mapError { error in
                return NetworkError.custom(error: error)
            }
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                    let httpResponse = response as? HTTPURLResponse
                    let statusCode = httpResponse?.statusCode
                    let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                    throw NSError(domain: "Error", code: statusCode ?? 0, userInfo: json)
                }
                return data
            }
            .flatMap { data -> AnyPublisher<T, Error> in
                return Just(data)
                    .decode(type: T.self, decoder: JSONDecoder())
                    .mapError { error in
                        return NetworkError.custom(error: error)
                    }
                    .eraseToAnyPublisher()
                
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    public static func fetchNoResponseRequest(from request: URLRequest) -> AnyPublisher<Void,Error> {
        return URLSession.shared.dataTaskPublisher(for: request)
            .mapError({ error in
                return error
            })
            .tryMap { data, response in
                guard let httpResponse =  response as? HTTPURLResponse, (200...299)
                    .contains(httpResponse.statusCode) else {
                    let httpResponse = response as? HTTPURLResponse
                    let statusCode = httpResponse?.statusCode
                    let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                    throw NSError(domain: "Error", code: statusCode ?? 0, userInfo: json)
                }
                return ()
            }
            .eraseToAnyPublisher()
    }

public static func handleServerError(from failure: Error) -> String {
    let error = failure as NSError
    let userInfo = error.userInfo
    
    // Extract message from userInfo using possible keys
    var message = extractMessage(from: userInfo, keys: ["detail", "non_field_errors"])
    
    // Handle NetworkError
    if let networkError = failure as? NetworkError {
        message = handleError(networkError)
    }
    
    // Fallback message
    return message ?? "Unable to complete your request"
}

private static func extractMessage(from userInfo: [String: Any], keys: [String]) -> String? {
    for key in keys {
        if let message = userInfo[key] as? String {
            return message
        } else if let array = userInfo[key] as? [String] {
            return array.first
        }
    }
    return nil
}

private static func handleError(_ error: NetworkError) -> String {
    var message = ""
    let failureReason = error.localizedDescription
    message.append(failureReason)
    
    if let recoverySuggestion = error.recoverySuggestion {
        message.append("\n\(recoverySuggestion)")
    }
    
    return message
}

    
}

