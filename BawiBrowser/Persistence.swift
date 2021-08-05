//
//  Persistence.swift
//  BawiBrowser
//
//  Created by Jae Seung Lee on 6/28/21.
//

import CoreData

struct PersistenceController {
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

    var container: NSPersistentCloudKitContainer
    var backgroundContext: NSManagedObjectContext?

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "BawiBrowser")
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        } else {
            
            guard let fileContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.resonance.jlee.BawiBrowser"),
                  let applicationSupportPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).last else {
                       fatalError("Shared file container could not be created.")
            }
            
            //let paths = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true)
            print("applicationSupportPath = \(applicationSupportPath)")
            
            let storeURL = fileContainer.appendingPathComponent("BawiBrowser.sqlite")
            let storeDescription = NSPersistentStoreDescription(url: storeURL)
            storeDescription.configuration = "Default"
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

            let cloudStoreURL = applicationSupportPath.appendingPathComponent("BawiBrowser/BawiBrowser.sqlite")
            let cloudStoreDescription = NSPersistentStoreDescription(url: cloudStoreURL)
            cloudStoreDescription.configuration = "Cloud"
            cloudStoreDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            cloudStoreDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            cloudStoreDescription.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.com.resonance.jlee.BawiBrowser")
            
            container.persistentStoreDescriptions = [cloudStoreDescription]
            
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
        
        container.viewContext.name = "BawiBrowser"
        backgroundContext = container.newBackgroundContext()
        purgeHistory()
        //addObserver()
    }
    
    private func purgeHistory() {
        //let sevenDaysAgo = Date(timeIntervalSinceNow: TimeInterval(exactly: -604_800)!)
        let oneDayAgo = Date(timeIntervalSinceNow: TimeInterval(exactly: -86_400)!)
        let purgeHistoryRequest = NSPersistentHistoryChangeRequest.deleteHistory(before: oneDayAgo)

        do {
            try backgroundContext!.execute(purgeHistoryRequest)
        } catch {
            print("Could not purge history: \(error)")
        }
    }
    
    private func addObserver() {
        let _ = PersistenceHistoryProcess(persistentContainer: container, backgroundContext: backgroundContext!)
    }
    
}
