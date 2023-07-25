//
//  KeyChainHelper.swift
//  BawiBrowser
//
//  Created by Jae Seung Lee on 7/23/23.
//

import Foundation
import os

class KeyChainHelper {
    private let logger = Logger()
    private let keyLabel = BawiBrowserConstants.appName.rawValue
    var credentials = BawiCredentials(username: "", password: "")
    
    func initialize() -> Void {
        search() { result in
            switch result {
            case .failure(let error):
                self.logger.log("Can't find credentials in key chain: \(error.localizedDescription, privacy: .public)")
            case .success(_):
                self.logger.log("Found credentials in key chain")
            }
        }
    }
    
    func add() throws -> Void {
        let account = credentials.username
        let password = credentials.password.data(using: String.Encoding.utf8)!
        let query: [String: Any] = [kSecClass as String: kSecClassInternetPassword,
                                    kSecAttrLabel as String: keyLabel,
                                    kSecAttrService as String: keyLabel,
                                    kSecAttrAccount as String: account,
                                    kSecValueData as String: password]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            print("Can't add")
            throw KeychainError.unhandledError(status: status)
        }
    }
    
    func search(completionHandler: @escaping (Result<BawiCredentials, Error>) -> Void) -> Void {
        let query: [String: Any] = [kSecClass as String: kSecClassInternetPassword,
                                    kSecAttrLabel as String: keyLabel,
                                    kSecAttrService as String: keyLabel,
                                    kSecMatchLimit as String: kSecMatchLimitOne,
                                    kSecReturnAttributes as String: true,
                                    kSecReturnData as String: true]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status != errSecItemNotFound else {
            completionHandler(.failure(KeychainError.noPassword))
            return
        }
        
        guard status == errSecSuccess else {
            completionHandler(.failure(KeychainError.unhandledError(status: status)))
            return
        }

        guard let existingItem = item as? [String : Any],
            let passwordData = existingItem[kSecValueData as String] as? Data,
            let password = String(data: passwordData, encoding: String.Encoding.utf8),
            let account = existingItem[kSecAttrAccount as String] as? String
        else {
            completionHandler(.failure(KeychainError.unexpectedPasswordData))
            return
        }
        
        credentials = BawiCredentials(username: account, password: password)
        
        completionHandler(.success(credentials))
    }
    
    func update() throws -> Void {
        let account = credentials.username
        let password = credentials.password.data(using: String.Encoding.utf8)!
        let attributes: [String: Any] = [kSecAttrAccount as String: account,
                                         kSecValueData as String: password]
        let query: [String: Any] = [kSecClass as String: kSecClassInternetPassword,
                                    kSecAttrLabel as String: keyLabel,
                                    kSecAttrService as String: keyLabel]
        
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        guard status != errSecItemNotFound else { throw KeychainError.noPassword }
        guard status == errSecSuccess else {
            print("Can't update")
            throw KeychainError.unhandledError(status: status)
        }
    }
    
    func delete() throws -> Void {
        let query: [String: Any] = [kSecClass as String: kSecClassInternetPassword,
                                    kSecAttrLabel as String: keyLabel,
                                    kSecAttrService as String: keyLabel]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            print("Can't delete")
            throw KeychainError.unhandledError(status: status)
        }
    }
}
