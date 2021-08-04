//
//  PersistenceHistoryProcessor.swift
//  BawiBrowser
//
//  Created by Jae Seung Lee on 8/3/21.
//

import Foundation
import CoreData

class PersistenceHistoryProcess {
    private let persistentContainer: NSPersistentCloudKitContainer
    private let backgroundContext: NSManagedObjectContext
    
    init(persistentContainer: NSPersistentCloudKitContainer, backgroundContext: NSManagedObjectContext) {
        self.persistentContainer = persistentContainer
        self.backgroundContext = backgroundContext
        
        addObserver()
    }
    
    
    private func addObserver() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(fetchChanges),
                                               name: NSNotification.Name.NSPersistentStoreRemoteChange,
                                               object: persistentContainer.persistentStoreCoordinator)
    }
    
    @objc private func fetchChanges() {
        backgroundContext.performAndWait {
            do {
                let fetchHistoryRequest = NSPersistentHistoryChangeRequest.fetchHistory(after: lastToken)
                
                if let historyResult = try self.backgroundContext.execute(fetchHistoryRequest) as? NSPersistentHistoryResult,
                   let history = historyResult.result as? [NSPersistentHistoryTransaction] {
                    for transaction in history.reversed() {
                        PersistenceController.shared.container.viewContext.perform {
                            if let userInfo = transaction.objectIDNotification().userInfo {
                                print("transaction.objectIDNotification().userInfo = \(userInfo)")
                                NSManagedObjectContext.mergeChanges(fromRemoteContextSave: userInfo,
                                                                    into: [PersistenceController.shared.container.viewContext])
                            }
                        }
                    }
                }
            } catch {
                print("Could not convert history result to transactions after lastToken = \(String(describing: lastToken)): \(error)")
            }
        }
    }
    
    private var lastToken: NSPersistentHistoryToken? = nil {
        didSet {
            guard let token = lastToken,
                  let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true) else {
                return
            }
            
            do {
                try data.write(to: tokenFile)
            } catch {
                let message = "Could not write token data"
                print("###\(#function): \(message): \(error)")
            }
        }
    }
    
    lazy var tokenFile: URL = {
        let url = NSPersistentContainer.defaultDirectoryURL().appendingPathComponent("BawiBrowser",isDirectory: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.createDirectory(at: url,
                                                        withIntermediateDirectories: true,
                                                        attributes: nil)
            } catch {
                let message = "Could not create persistent container URL"
                print("###\(#function): \(message): \(error)")
            }
        }
        return url.appendingPathComponent("token.data", isDirectory: false)
    }()
}
