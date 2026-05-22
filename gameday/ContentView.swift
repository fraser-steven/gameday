//
//  ContentView.swift
//  gameday
//
//  Created by Fraser Steven on 22/05/2026.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Home", systemImage: "house") {
                HomeView()
            }
            
            Tab("Tips", systemImage: "lightbulb") {
                TipsView()
            }
            
            Tab("Settings", systemImage: "gearshape") {
                SettingsView()
            }
        }
        .accentColor(.red)
    }
}

#Preview {
    ContentView()
}
