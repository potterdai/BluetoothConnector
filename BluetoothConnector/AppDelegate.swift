// AppDelegate.swift
// Bluesnooze
//
// Created by Potter Dai on 07/04/2020.
// Copyright © 2020 Oliver Peate. All rights reserved.

import Cocoa
import IOBluetooth
import LaunchAtLogin

@NSApplicationMain
class AppDelegate: NSObject, NSMenuDelegate, NSApplicationDelegate {
    
    @IBOutlet weak var statusMenu: NSMenu!
    @IBOutlet weak var launchAtLoginMenuItem: NSMenuItem!
    
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var deviceMenuItems: [String: NSMenuItem] = [:]
    private var timer: Timer! = nil

    // MARK: - App Lifecycle

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        loadDeviceMenuItems()
        initStatusItem()
        setLaunchAtLoginState()
        setupNotificationHandlers()
        setupTimer()
    }

    // MARK: - UI Actions

    @IBAction func launchAtLoginClicked(_ sender: NSMenuItem) {
        LaunchAtLogin.isEnabled.toggle()
        setLaunchAtLoginState()
    }

    @IBAction func quitClicked(_ sender: NSMenuItem) {
        NSApplication.shared.terminate(self)
    }

    // MARK: - Notification Handlers

    func setupNotificationHandlers() {
        [
            NSWorkspace.willSleepNotification: #selector(onPowerDown(note:)),
            NSWorkspace.willPowerOffNotification: #selector(onPowerDown(note:)),
            NSWorkspace.didWakeNotification: #selector(onPowerUp(note:))
        ].forEach { NSWorkspace.shared.notificationCenter.addObserver(self, selector: $1, name: $0, object: nil) }
    }

    @objc func onPowerDown(note: Notification) {}

    @objc func onPowerUp(note: Notification) {
        connect()
    }

    // MARK: - Timer Setup

    func setupTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { _ in
            self.connect()
        }
    }

    // MARK: - UI Updates

    private func initStatusItem() {
        if UserDefaults.standard.bool(forKey: "hideIcon") { return }

        if let icon = NSImage(named: "bluesnooze") {
            icon.isTemplate = true
            statusItem.button?.image = icon
        } else {
            statusItem.button?.title = "Bluesnooze"
        }

        statusMenu.delegate = self
        statusItem.menu = statusMenu
    }

    private func setLaunchAtLoginState() {
        launchAtLoginMenuItem.state = LaunchAtLogin.isEnabled ? .on : .off
    }

    func menuWillOpen(_ menu: NSMenu) {
        updateDeviceList(in: menu)
    }

    @objc private func menuItemClick(_ menuItem: NSMenuItem) {
        menuItem.state = menuItem.state == .off ? .on : .off
    }
    
    // MARK: - UserDefaults Operations

    func saveDeviceMenuItems() {
        var serializableItems: [String: [String: Any]] = [:]
        
        // Convert NSMenuItem values to serializable format (including title and state)
        for (key, menuItem) in deviceMenuItems {
            serializableItems[key] = [
                "title": menuItem.title,
                "state": menuItem.state.rawValue
            ]
        }
        
        UserDefaults.standard.set(serializableItems, forKey: "deviceMenuItems")
    }

    func loadDeviceMenuItems() {
        if let savedItems = UserDefaults.standard.dictionary(forKey: "deviceMenuItems") as? [String: [String: Any]] {
            for (key, itemData) in savedItems {
                if let title = itemData["title"] as? String, let stateRaw = itemData["state"] as? Int {
                    let state = NSControl.StateValue(rawValue: stateRaw)
                    let menuItem = NSMenuItem(title: title, action: #selector(menuItemClick(_:)), keyEquivalent: "")
                    menuItem.state = state
                    deviceMenuItems[key] = menuItem
                    statusMenu.insertItem(menuItem, at: 0)
                }
            }
        }
    }

    // MARK: - Device Management

    private func getDeviceList() -> [String: (name: String, connected: Bool)] {
        // Simplified the function to improve readability
        var devices: [String: (name: String, connected: Bool)] = [:]

        IOBluetoothDevice.pairedDevices().forEach { device in
            guard let device = device as? IOBluetoothDevice, let addressString = device.addressString, let deviceName = device.name else { return }
            devices[addressString] = (name: deviceName, connected: device.isConnected())
        }

        return devices
    }

    private func updateDeviceList(in menu: NSMenu) {
        let devices = getDeviceList()

        // Update existing devices and remove stale ones
        for deviceID in deviceMenuItems.keys {
            guard let deviceStatus = devices[deviceID] else {
                menu.removeItem(deviceMenuItems[deviceID]!)
                deviceMenuItems.removeValue(forKey: deviceID)
                continue
            }
            let statusIndicator = deviceStatus.connected ? " 🟢" : ""
            deviceMenuItems[deviceID]?.title = deviceStatus.name + statusIndicator
        }

        // Add new devices
        devices.forEach { deviceID, deviceStatus in
            if deviceMenuItems[deviceID] == nil {
                let statusIndicator = deviceStatus.connected ? " 🟢" : ""
                let menuItem = NSMenuItem(title: deviceStatus.name + statusIndicator, action: #selector(menuItemClick(_:)), keyEquivalent: "")
                deviceMenuItems[deviceID] = menuItem
                menu.insertItem(menuItem, at: 0)
            }
        }
        
        saveDeviceMenuItems()
    }

    private func connect() {
        for (deviceID, menuItem) in deviceMenuItems where menuItem.state == .on {
            executeConnection(for: deviceID)
        }
    }

    // MARK: - Bluetooth Operations

    private func executeConnection(for macAddress: String) {
        // Simplified the function to focus only on connection
        guard let bluetoothDevice = IOBluetoothDevice(addressString: macAddress), bluetoothDevice.isPaired() else { return }
        if !bluetoothDevice.isConnected() {
            turnOnBluetoothIfNeeded()
            bluetoothDevice.openConnection()
        }
    }

    private func turnOnBluetoothIfNeeded() {
        // Simplified the function to improve readability
        guard let bluetoothHost = IOBluetoothHostController.default(), bluetoothHost.powerState != kBluetoothHCIPowerStateON else { return }

        if let iobluetoothClass = NSClassFromString("IOBluetoothPreferences") as? NSObject.Type {
            let obj = iobluetoothClass.init()
            obj.perform(NSSelectorFromString("setPoweredOn:"), with: 1)
        }
    }
}
