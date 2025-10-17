//
//  AppDelegate.swift
//  BawiBrowser
//
//  Created by Jae Seung Lee on 6/13/22.
//

import Foundation
import os
import CloudKit
import CoreData
import Persistence
@preconcurrency import UserNotifications
import AppKit
import CoreSpotlight

@MainActor
class AppDelegate: NSObject {
    private let logger = Logger()
    
    private let subscriptionID = "article-updated"
    private let didCreateArticleSubscription = "didCreateArticleSubscription"
    private let recordType = "CD_Article"
    private let recordValueKey = "CD_articleTitle"
    
    private let databaseOperationHelper = DatabaseOperationHelper(appName: BawiBrowserConstants.appName.rawValue)
    
    private var database: CKDatabase {
        CKContainer(identifier: BawiBrowserConstants.iCloudIdentifier.rawValue).privateCloudDatabase
    }
    
    let persistence: Persistence
    let viewModel: BawiBrowserViewModel
    
    override init() {
        self.persistence = Persistence(name: BawiBrowserConstants.appName.rawValue, identifier: BawiBrowserConstants.iCloudIdentifier.rawValue)
        self.viewModel = BawiBrowserViewModel(persistence: persistence)
        
        super.init()
    }
    
    private func registerForPushNotifications() {
        Task {
            do {
                try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
                getNotificationSettings()
            } catch {
                logger.log("Error whie requesting notification authorization: \(error.localizedDescription)")
            }
        }
    }

    private func getNotificationSettings() {
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            
            if settings.authorizationStatus == .authorized {
#if os(macOS)
                NSApplication.shared.registerForRemoteNotifications()
#else
                UIApplication.shared.registerForRemoteNotifications()
#endif
            }
        }
    }
    
    private func subscribe() {
        guard !UserDefaults.standard.bool(forKey: didCreateArticleSubscription) else {
            logger.log("alredy true: didCreateArticleSubscription=\(UserDefaults.standard.bool(forKey: self.didCreateArticleSubscription))")
            return
        }
        
        let subscriber = Subscriber(database: database, subscriptionID: subscriptionID, recordType: recordType)
        subscriber.subscribe { result in
            switch result {
            case .success(let subscription):
                self.logger.log("Subscribed to \(subscription, privacy: .public)")
                UserDefaults.standard.setValue(true, forKey: self.didCreateArticleSubscription)
                self.logger.log("set: didCreateArticleSubscription=\(UserDefaults.standard.bool(forKey: self.didCreateArticleSubscription))")
            case .failure(let error):
                self.logger.log("Failed to modify subscription: \(error.localizedDescription, privacy: .public)")
                UserDefaults.standard.setValue(false, forKey: self.didCreateArticleSubscription)
            }
        }
    }
    
    private func processRemoteNotification() {
        databaseOperationHelper.addDatabaseChangesOperation(database: database) { result in
            switch result {
            case .success(let record):
                self.processRecord(record)
            case .failure(let error):
                self.logger.log("Failed to process remote notification: error=\(error.localizedDescription, privacy: .public)")
            }
        }
    }
    
    private func processRecord(_ record: CKRecord) {
        guard record.recordType == recordType else {
            return
        }
        
        guard let title = record.value(forKey: recordValueKey) as? String else {
            return
        }

        logger.log("Processing \(record)")
        
        let content = UNMutableNotificationContent()
        content.title = BawiBrowserConstants.appName.rawValue
        content.body = title
        content.sound = UNNotificationSound.default
        
        content.userInfo = ["articleId": record.value(forKey: "CD_articleId") as? Int64 ?? Int64(-1),
                            "boardId": record.value(forKey: "CD_boardId") as? Int64 ?? Int64(-1)]
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
        
        logger.log("Processed \(record)")
    }

}

extension AppDelegate: NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.log("didFinishLaunchingWithOptions")
        UNUserNotificationCenter.current().delegate = self
        
        registerForPushNotifications()
        
        // TODO: - Remove or comment out after testing
        //UserDefaults.standard.setValue(false, forKey: "didArticleItemSubscription")
        
        subscribe()
    }
    
    func application(_ application: NSApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenParts = deviceToken.map { String(format: "%02.2hhx", $0) }
        let token = tokenParts.joined()
        logger.log("Device Token: \(token)")
    }
    
    func application(_ application: NSApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        logger.log("Failed to register: \(String(describing: error))")
    }

    func application(_ application: NSApplication, didReceiveRemoteNotification userInfo: [String : Any]) {
        guard let notification = CKNotification(fromRemoteNotificationDictionary: userInfo) else {
            logger.log("notification=failed")
            return
        }
        logger.log("notification=\(String(describing: notification))")
        if !notification.isPruned && notification.notificationType == .database {
            if let databaseNotification = notification as? CKDatabaseNotification, databaseNotification.subscriptionID == subscriptionID {
                logger.log("databaseNotification=\(String(describing: databaseNotification.subscriptionID))")
                processRemoteNotification()
            }
        }
    }
    
    func application(_ application: NSApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([NSUserActivityRestoring]) -> Void) -> Bool {
        guard let info = userActivity.userInfo, let _ = info[CSSearchableItemActivityIdentifier] as? String else {
            return false
        }
        
        viewModel.continueActivity(userActivity)
        
        return true
    }
    
}

extension AppDelegate: @preconcurrency UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        return [.banner, .sound]
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        logger.info("userNotificationCenter: response=\(response, privacy: .public)")
        let title = response.notification.request.content.body
        
        let userInfo = response.notification.request.content.userInfo
        logger.info("userNotificationCenter: response=\(userInfo, privacy: .public)")
        
        let articleId = userInfo["articleId"] as! Int64
        let boardId = userInfo["boardId"] as! Int64
        viewModel.selectArticle(title: title, articleId: articleId, boradId: boardId)
    }
    
}
