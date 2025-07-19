/*
 AppDelegate.swift
 Menubar RunCat

 Created by Takuto Nakamura on 2019/08/06.
 Modified by Jonghoon Park on 2025/07/19
 Copyright © 2019 Takuto Nakamura. All rights reserved.
*/

import Cocoa
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private lazy var statusItem: NSStatusItem = {
        return NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    }()
    private let menu = NSMenu()
    private lazy var frames: [NSImage] = {
        return (0 ..< 5).map { n in
            let image = NSImage(named: "cat_page\(n)")!
            image.size = NSSize(width: 28, height: 18)
            return image
        }
    }()
    private var index: Int = 0
    private var interval: Double = 1.0
    private let cpu = CPU()
    private var cpuUsage: CPUInfo = CPU.default
    private let memory = Memory()
    private var memoryUsage: MemoryInfo = Memory.default
    private var usageUpdateTimer: Timer? = nil
    private var runnerTimer: Timer? = nil
    private var isShowCpuUsage: Bool = false
    private var isShowMemoryUsage: Bool = false
    private var isEnabledRunOnLogin: Bool = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        isShowCpuUsage = UserDefaults.standard.bool(forKey: "isShowCpuUsage")
        isShowMemoryUsage = UserDefaults.standard.bool(forKey: "isShowMemoryUsage")
        isEnabledRunOnLogin = (SMAppService.mainApp.status == .enabled)

        setupStatusItem()
        startRunning()
    }

    func applicationWillTerminate(_ notification: Notification) {
        stopRunning()
    }

    private func updateUsageDescription() {
        let title: String = {
            switch (isShowCpuUsage, isShowMemoryUsage) {
            case (true, true):
                return "\(cpuUsage.description) / \(memoryUsage.description)"
            case (true, false):
                return cpuUsage.description
            case (false, true):
                return memoryUsage.description
            case (false, false):
                return ""
            }
        }()

        statusItem.button?.title = title
    }

    @objc func toggleShowCpuUsage(_ sender: NSMenuItem) {
        isShowCpuUsage = (sender.state == .off)
        sender.state = isShowCpuUsage ? .on : .off
        UserDefaults.standard.set(isShowCpuUsage, forKey: "isShowCpuUsage")
        updateUsageDescription()
    }

    @objc func toggleShowMemoryUsage(_ sender: NSMenuItem) {
        isShowMemoryUsage = (sender.state == .off)
        sender.state = isShowMemoryUsage ? .on : .off
        UserDefaults.standard.set(isShowMemoryUsage, forKey: "isShowMemoryUsage")
        updateUsageDescription()
    }

    @objc func toggleRunOnLogin(_ sender: NSMenuItem) {
        do {
            let currentStatus = SMAppService.mainApp.status
            isEnabledRunOnLogin = (currentStatus != .enabled)
            
            if isEnabledRunOnLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            sender.state = isEnabledRunOnLogin ? .on : .off
            UserDefaults.standard.set(isEnabledRunOnLogin, forKey: "isEnabledRunOnLogin")
        } catch {
            // Unexpected error
        }
    }

    @objc func openAbout(_ sender: Any?) {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc func terminateApp(_ sender: Any?) {
        NSApp.terminate(nil)
    }

    private func setupStatusItem() {
        statusItem.button?.imagePosition = .imageTrailing
        statusItem.button?.image = frames.first
        if #available(macOS 10.15, *) {
            let font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
            statusItem.button?.font = font
        } else {
            let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
            statusItem.button?.font = font
        }
        
        let cpuMenuItem = NSMenuItem(title: "Show CPU Usage",
                                      action: #selector(toggleShowCpuUsage(_:)),
                                      keyEquivalent: "")
        cpuMenuItem.state = isShowCpuUsage ? .on : .off
        menu.addItem(cpuMenuItem)
        
        let memoryMenuItem = NSMenuItem(title: "Show Memory Usage",
                                      action: #selector(toggleShowMemoryUsage(_:)),
                                      keyEquivalent: "")
        memoryMenuItem.state = isShowMemoryUsage ? .on : .off
        menu.addItem(memoryMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let runOnLoginMenuItem = NSMenuItem(title: "Run on login",
                                      action: #selector(toggleRunOnLogin(_:)),
                                      keyEquivalent: "")
        runOnLoginMenuItem.state = isEnabledRunOnLogin ? .on : .off
        menu.addItem(runOnLoginMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(withTitle: "About Menubar RunCat",
                     action: #selector(openAbout(_:)),
                     keyEquivalent: "")
        menu.addItem(withTitle: "Quit Menubar RunCat",
                     action: #selector(terminateApp(_:)),
                     keyEquivalent: "")
        statusItem.menu = menu
    }

    @objc func receiveSleep(_ notification: NSNotification) {
        stopRunning()
    }

    @objc func receiveWakeUp(_ notification: NSNotification) {
        startRunning()
    }

    private func setNotifications() {
        NSWorkspace.shared.notificationCenter
            .addObserver(self, selector: #selector(receiveSleep(_:)),
                         name: NSWorkspace.willSleepNotification,
                         object: nil)
        NSWorkspace.shared.notificationCenter
            .addObserver(self, selector: #selector(receiveWakeUp(_:)),
                         name: NSWorkspace.didWakeNotification,
                         object: nil)
    }

    private func updateUsage() {
        cpuUsage = cpu.currentUsage()
        memoryUsage = memory.currentUsage()
        interval = max(0.03, 0.45 / max(1.0, min(20.0, self.cpuUsage.value / 5.0)))
        updateUsageDescription()
        runnerTimer?.invalidate()
        runnerTimer = Timer(timeInterval: self.interval, repeats: true, block: { [weak self] _ in
            self?.next()
        })
        RunLoop.main.add(runnerTimer!, forMode: .common)
    }

    private func next() {
        index = (index + 1) % frames.count
        statusItem.button?.image = frames[index]
    }

    private func startRunning() {
        usageUpdateTimer = Timer(timeInterval: 5.0, repeats: true, block: { [weak self] _ in
            self?.updateUsage()
        })
        RunLoop.main.add(usageUpdateTimer!, forMode: .common)
        usageUpdateTimer?.fire()
    }
    
    private func stopRunning() {
        runnerTimer?.invalidate()
        usageUpdateTimer?.invalidate()
    }
}
