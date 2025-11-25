//
//  MowApp.swift
//  mow-ios
//
//  Created by James Smith on 11/22/25.
//

import Combine
import SwiftUI

@main
struct MowApp: App {
    @StateObject private var coordinator: AppCoordinator

    init() {
        let dependencies = AppDependencies.live()
        _coordinator = StateObject(wrappedValue: AppCoordinator(dependencies: dependencies))
    }

    var body: some Scene {
        WindowGroup {
            AppCoordinatorView(coordinator: coordinator)
        }
    }
}
