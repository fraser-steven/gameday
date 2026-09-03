//
//  FootballError.swift
//  gameday
//

import Foundation

enum FootballError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Couldn't build the request URL."
        case .invalidResponse:
            "The server sent an unexpected response."
        case .httpStatus(let code):
            "The server responded with status \(code)."
        }
    }
}