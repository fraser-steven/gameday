//
//  HomeView.swift
//  gameday
//
//  Created by Fraser Steven on 22/05/2026.
//

import SwiftUI

import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    HStack {
                        Text("GameDay AI")
                            .font(.largeTitle.bold())
                        Text("⚽")
                            .font(.title)
                    }
                    .padding(.horizontal)
                    
                    // Placeholder sections
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Featured Match")
                            .font(.headline)
                            .padding(.horizontal)
                        Text("Featured match will go here")
                            .frame(maxWidth: .infinity)
                            .frame(height: 160)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(12)
                            .padding(.horizontal)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Upcoming Matches")
                            .font(.headline)
                            .padding(.horizontal)
                        Text("List of upcoming matches will go here")
                            .frame(maxWidth: .infinity)
                            .frame(height: 300)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(12)
                            .padding(.horizontal)
                    }
                }
            }
        }
    }
}

#Preview {
    HomeView()
}
