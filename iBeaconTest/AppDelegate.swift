//
//  AppDelegate.swift
//  iBeaconTest
//
//  Created by Dmitry Tsurkan on 05.08.2018.
//  Copyright © 2018 Dmitry Tsurkan. All rights reserved.
//

import UIKit
import CoreLocation
import UserNotifications

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, CLLocationManagerDelegate, UNUserNotificationCenterDelegate {

    var window: UIWindow?
    var locationManager: CLLocationManager?
    var backgroundTask: UIBackgroundTaskIdentifier = UIBackgroundTaskInvalid
    var isInBeaconRegion: Bool {
        get {
            return UserDefaults.standard.bool(forKey: #function)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: #function)
        }
    }
    var beaconRegion: CLBeaconRegion? {
        didSet {
            if let region = beaconRegion {
                if UIApplication.shared.applicationState == .background {
                    registerBackgroundTask()
                }
                isInBeaconRegion = true
                let title = "Hey you have entered region: \(region.identifier)"
                notify(title)
                rangeBeaconsIn(region)
            } else {
                isInBeaconRegion = false
                let title = "Hey you have exited region: \(oldValue!.identifier)"
                notify(title)
                locationManager?.stopRangingBeacons(in: oldValue!)
                endBackgroundTask()
                debugPrint("didStopRanging")
            }
        }
    }
    
    enum bars: Int {
        case Bartka = 1, Subrosa
        
        var name: String {
            switch self.rawValue {
            case 1:
                return "Bartka"
            case 2:
                return "Subrosa"
            default:
                return ""
            }
        }
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { (didAllow, error) in
            UNUserNotificationCenter.current().delegate = self
        }
        
        locationManager = CLLocationManager()
        enableLocationServices()
        monitorBeacons()
        
        debugPrint("didFinishLaunchingWithOptions")
        return true
    }
    
    fileprivate func enableLocationServices() {
        locationManager?.delegate = self
        locationManager?.requestAlwaysAuthorization()
    }
    
    fileprivate func monitorBeacons() {
        if CLLocationManager.isMonitoringAvailable(for: CLBeaconRegion.self) {
            // Match all beacons with the specified UUID
            let proximityUUID = UUID(uuidString: "04668CB3-755B-4BAB-8EC6-3151A152DB48")
            let beaconID = "com.dlink.iBeaconTest"
            
            let region = CLBeaconRegion(proximityUUID: proximityUUID!,
                                        identifier: beaconID)
            region.notifyOnEntry = true
            region.notifyOnExit = true
            
            locationManager?.startMonitoring(for: region)
            debugPrint("didStartMonitoring")
        }
    }
    
    fileprivate func rangeBeaconsIn(_ region: CLRegion) {
        if region is CLBeaconRegion {
            if CLLocationManager.isRangingAvailable() {
                locationManager?.startRangingBeacons(in: region as! CLBeaconRegion)
                debugPrint("didStartRanging")
            }
        }
    }
    
    fileprivate func registerBackgroundTask() {
        let title = "Background task started."
        debugPrint(title)
        notify(title)
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
        assert(backgroundTask != UIBackgroundTaskInvalid)
    }

    fileprivate func endBackgroundTask() {
        guard backgroundTask != UIBackgroundTaskInvalid else {
            let title = "Background task is already invalid."
            debugPrint(title)
            notify(title)
            return
        }
        let title = "Our app is sleeping now."
        debugPrint(title)
        notify(title)
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = UIBackgroundTaskInvalid
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        debugPrint("didEnterRegion region: \(region.identifier)")
        beaconRegion = region as? CLBeaconRegion
        
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        debugPrint("didExitRegion region: \(region.identifier)")
        beaconRegion = nil
    }
    
    func locationManager(_ manager: CLLocationManager, didRangeBeacons beacons: [CLBeacon], in region: CLBeaconRegion) {
        debugPrint(beacons)
        
        if let nearestBeacon = beacons.first {
            
            switch nearestBeacon.proximity {
            case .immediate:
                debugPrint("immediate")
                notify("immediate")
            case .near:
                debugPrint("near")
                notify("near")
            case .far:
                debugPrint("far")
                notify("far")
            case .unknown:
                debugPrint("unknown")
                notify("unknown")
            }
        }
        
//        if let bar = bars(rawValue: nearestBeacon.major.intValue) {
//            let title = "You have been in range of \(bar.name)"
//            notify(title)
//        }
    }

    fileprivate func notify(_ title: String, subtitle: String? = nil, body: String? = nil) {
        
        switch UIApplication.shared.applicationState {
        case .active:
            sendAlert(title, subtitle: subtitle, body: body)
        default:
            sendNotification(title, subtitle: subtitle, body: body)
        }
    }
    
    fileprivate func sendAlert(_ title: String, subtitle: String? = nil, body: String? = nil) {
        let alertController = UIAlertController(title: title, message: body, preferredStyle: .alert)
        
        if window?.rootViewController?.presentedViewController == nil {
            window?.rootViewController?.present(alertController, animated: true, completion: nil)
        } else {
            window?.rootViewController?.dismiss(animated: false) { () -> Void in
                self.window?.rootViewController?.present(alertController, animated: true, completion: nil)
            }
        }
    }
    
    fileprivate func sendNotification(_ title: String, subtitle: String? = nil, body: String? = nil) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.subtitle = subtitle ?? ""
        content.body = body ?? ""
        
        //getting the notification trigger, it will be called after 1 second
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "SimplifiedIOSNotification", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
        if isInBeaconRegion {
            registerBackgroundTask()
        }
        debugPrint("applicationWillResignActive")
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        debugPrint("applicationDidEnterBackground")
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
        endBackgroundTask()
        debugPrint("applicationWillEnterForeground")
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        debugPrint("applicationDidBecomeActive")
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        debugPrint("applicationWillTerminate")
    }

}

