//
//  AttachmentHandler.swift
//  BawiBrowser
//
//  Created by Jae Seung Lee on 10/18/25.
//

import Foundation

actor AttachmentHandler: MessageHandling {
    
    private let data: Data
    
    init(data: Data) {
        self.data = data
    }
    
    func process() async -> Void {
        await SafariExtensionPersister.shared.addAttachment(data)
    }
    
}
