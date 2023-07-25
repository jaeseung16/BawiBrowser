//
//  BawiCredential.swift
//  BawiBrowser
//
//  Created by Jae Seung Lee on 7/23/23.
//

import Foundation

struct BawiCredentials {
    var username: String
    var password: String
}

enum KeychainError: Error {
    case noPassword
    case unexpectedPasswordData
    case unhandledError(status: OSStatus)
}
