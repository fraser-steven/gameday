//
//  SettingsView.swift
//  gameday
//
//  Created by Fraser Steven on 22/05/2026.
//

import SwiftUI

import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    Text("Signed in as Guest")
                }
                
                Section("AI Model") {
                    Text("Current Model: v0.1")
                    Text("Last Updated: Recently")
                }
                
                Section("Preferences") {
                    Toggle("Enable Notifications", isOn: .constant(true))
                    
                    Picker("Favourite League", selection: .constant("Premier League")) {
                        Text("Premier League").tag("Premier League")
                        Text("La Liga").tag("La Liga")
                        Text("Champions League").tag("Champions League")
                    }
                }
                
                Section("About") {
                    Text("GameDay AI")
                    Text("Version 0.1")
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
}
