//
//  DualFitApp.swift
//  DualFit
//
//  A daily exercise challenge app for small groups of friends.
//  Uses CloudKit for sync and storage.
//

import SwiftUI

@main
struct DualFitApp: App {
    @StateObject private var appViewModel = AppViewModel()
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appViewModel)
        }
    }
}

