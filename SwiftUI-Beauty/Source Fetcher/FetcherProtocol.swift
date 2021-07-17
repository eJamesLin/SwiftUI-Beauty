//
//  FetcherProtocol.swift
//  SwiftUI Beauty
//
//  Created by Nelson on 2018/8/8.
//  Copyright © 2018年 Nelson. All rights reserved.
//

import Foundation
import Combine

enum CustomError: Error {
    case networkError(_: Error)
    case parseError(_: Error)
    case invalidData(_: Data)
    case serverError(code: Int)
    case clientError(code: Int)
    case otherResponseError(code: Int)
    case emptyData
}

enum FetchResult<Value> {
    case success(Value)
    case failure(CustomError)
}

typealias Parser<T> = (_ html: String) throws -> [T]

protocol Fetcher {
    var name: String { get }
    func fetchPosts(at page: UInt) -> AnyPublisher<[Post], CustomError>
    func fetchPhotos(at url: URL) -> AnyPublisher<[URL], CustomError>
}

extension Fetcher {
    func fetchContent<T>(for request: URLRequest, encoding: String.Encoding = .utf8, using parser: @escaping Parser<T>) -> AnyPublisher<[T], CustomError> {
        URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response -> Data in
                let response = response as! HTTPURLResponse
                switch response.statusCode {
                case 200..<300:
                    return data
                case 400..<500:
                    throw CustomError.clientError(code: response.statusCode)
                case 500..<600:
                    throw CustomError.serverError(code: response.statusCode)
                default:
                    throw CustomError.otherResponseError(code: response.statusCode)
                }
            }
            .tryMap { data -> String in
                guard let content = String(data: data, encoding: encoding) else {
                    throw CustomError.invalidData(data)
                }
                return content
            }
            .tryMap { content -> [T] in
                do {
                    let parseResult = try parser(content)
                    if parseResult.isEmpty {
                        throw CustomError.emptyData
                    } else {
                        return parseResult
                    }
                } catch {
                    throw CustomError.parseError(error)
                }
            }
            .mapError { error in
                return (error as? CustomError) ?? CustomError.networkError(error)
            }
            .eraseToAnyPublisher()
    }
}
