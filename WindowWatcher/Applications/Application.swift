//
//  Application.swift
//  Automatically Move Mouse Pointer To Default Button in a dialog box for mac
//
//  Created by kyo ago on 2018/07/09.
//  Copyright © 2018 kyo ago. All rights reserved.
//

import Cocoa
import Foundation

fileprivate func getAXUIElementCopyAttributeValue(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
    var result: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attribute as CFString, &result) == .success else {
        return nil
    }
    return result
}

fileprivate func getAXObserverCreate(_ application: pid_t, _ callback: @escaping ApplicationServices.AXObserverCallback) -> AXObserver? {
    var observer: AXObserver?
    guard AXObserverCreate(application, callback, &observer) == .success else {
        print("AXObserverCreate error: \(application)")
        return nil
    }
    return observer
}

fileprivate func getAXPointValue(_ value: AXValue) -> CGPoint {
    var val = CGPoint.zero
    AXValueGetValue(value, .cgPoint, &val)
    return val
}

fileprivate func getAXUIElementPointValue(_ element: AXUIElement) -> CGPoint? {
    guard let attr = getAXUIElementCopyAttributeValue(element, kAXPositionAttribute) else {
        return nil
    }
    return getAXPointValue(attr as! AXValue)
}

fileprivate func getAXSizeValue(_ value: AXValue) -> CGSize {
    var val = CGSize.zero
    AXValueGetValue(value, .cgSize, &val)
    return val
}

fileprivate func getAXUIElementSizeValue(_ element: AXUIElement) -> CGSize? {
    guard let attr = getAXUIElementCopyAttributeValue(element, kAXSizeAttribute) else {
        return nil
    }
    return getAXSizeValue(attr as! AXValue)
}

fileprivate func addCFRunLoopSource(_ observer: AXObserver) {
    CFRunLoopAddSource(
        RunLoop.current.getCFRunLoop(),
        AXObserverGetRunLoopSource(observer),
        CFRunLoopMode.defaultMode)
}

fileprivate func removeCFRunLoopSource(_ observer: AXObserver) {
    CFRunLoopRemoveSource(
        RunLoop.current.getCFRunLoop(),
        AXObserverGetRunLoopSource(observer),
        CFRunLoopMode.defaultMode)
}

fileprivate func addAXObserverNotification(_ observer: AXObserver, _ element: AXUIElement, _ notification: String, _ refcon: UnsafeMutableRawPointer?) {
    let error = AXObserverAddNotification(observer, element, notification as CFString, refcon)
    guard error == .success || error == .notificationAlreadyRegistered else {
        print("AXObserverAddNotification error: \(notification)")
        return
    }
}

fileprivate func removeAXObserverAddNotification(_ observer: AXObserver, _ element: AXUIElement, _ notification: String) {
    let error = AXObserverRemoveNotification(observer, element, notification as CFString)
    guard error == .success || error == .notificationNotRegistered else {
        print("AXObserverRemoveNotification error: \(notification)")
        return
    }
}

class Application {
    var axObserver: AXObserver!
    let pid: pid_t

    init(_ pid: pid_t) {
        self.pid = pid
    }

    func isPid(_ pid: pid_t) -> Bool {
        return self.pid == pid
    }

    func start() {
        let app_ref = AXUIElementCreateApplication(pid)
        
        axObserver = getAXObserverCreate(pid, {(_ axObserver: AXObserver,
                                                axElement: AXUIElement,
                                                notification: CFString,
                                                userData: UnsafeMutableRawPointer?) -> Void in
            guard let userData = userData else {
                print("Missing userData")
                return
            }
            let application = Unmanaged<Application>.fromOpaque(userData).takeUnretainedValue()
            application.callback(axObserver, axElement: axElement, notification: notification)
        })
        
        addCFRunLoopSource(axObserver!)

        let selfPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        addAXObserverNotification(axObserver!, app_ref, kAXApplicationActivatedNotification, selfPtr)
        addAXObserverNotification(axObserver!, app_ref, kAXFocusedWindowChangedNotification, selfPtr)
    }
    
    @discardableResult
    private func shell(_ args: String) -> String {
        var outstr = ""
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", args]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8) {
            outstr = output as String
        }
        task.waitUntilExit()
        return outstr
    }
    
    func send(_ msg : String) {
        shell("if [ -e /dev/cu.usbmodemCkbio01E1 ] ; then echo " + msg + " > /dev/cu.usbmodemCkbio01E1; fi")
    }
    
    func includes(_ s1:String, _ s2:String) -> Bool {
        return s1.range(of: s2) != nil
    }

    func callback(_ axObserver: AXObserver,
                  axElement: AXUIElement,
                  notification: CFString) {

        // print(notification as String)
        
        var title : AnyObject?
        AXUIElementCopyAttributeValue(axElement, kAXTitleAttribute as CFString, &title)
        if title == nil { return }
        
        let t = title as! String
        if includes(t, "Firefox") || includes(t, "Chrome") {
            send("browser")
            return
        }
        if includes(t, "Emacs") {
            send("emacs")
            return
        }

        // shell("if [ -e /dev/cu.usbmodemCkbio01E1 ] ; then echo yes > /dev/cu.usbmodemCkbio01E1; fi")
        
        //            guard AXUIElementPerformAction(button as! AXUIElement, kAXPressAction as CFString) == .success else {
        //                print("AXUIElementPerformAction")
        //                return
        //            }
    }
}
