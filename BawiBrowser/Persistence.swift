//
//  Persistence.swift
//  BawiBrowser
//
//  Created by Jae Seung Lee on 6/28/21.
//

import CoreData

class PersistenceController {
    static let shared = PersistenceController()

    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        for _ in 0..<10 {
            let newItem = Note(context: viewContext)
            newItem.created = Date()
        }
        do {
            try viewContext.save()
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentContainer
    let backgroundContext: NSManagedObjectContext

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "BawiBrowser")
        container.viewContext.name = "BawiBrowser"
        backgroundContext = container.newBackgroundContext()
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        } else {
            guard let fileContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.resonance.jlee.BawiBrowser") else {
                       fatalError("Shared file container could not be created.")
            }
            
            let storeURL = fileContainer.appendingPathComponent("BawiBrowser.sqlite")
            let storeDescription = NSPersistentStoreDescription(url: storeURL)
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

            container.persistentStoreDescriptions = [storeDescription]
            
            purgeHistory()
            addObserver()
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.

                /*
                Typical reasons for an error here include:
                * The parent directory does not exist, cannot be created, or disallows writing.
                * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                * The device is out of space.
                * The store could not be migrated to the current model version.
                Check the error message to determine what the actual problem was.
                */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
    }
    
    private func purgeHistory() {
        let sevenDaysAgo = Date(timeIntervalSinceNow: TimeInterval(exactly: -604_800)!)
        let purgeHistoryRequest = NSPersistentHistoryChangeRequest.deleteHistory(before: sevenDaysAgo)

        do {
            try backgroundContext.execute(purgeHistoryRequest)
        } catch {
            print("Could not purge history: \(error)")
        }
    }
    
    private func addObserver() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(fetchChanges),
                                               name: NSNotification.Name.NSPersistentStoreRemoteChange,
                                               object: container.persistentStoreCoordinator)
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
