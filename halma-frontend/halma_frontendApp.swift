//
//  halma_frontendApp.swift
//  halma-frontend
//
//  Created by Paulo Henrique on 26/09/25.
//

import SwiftUI

@main
struct halma_frontendApp: App {
    @StateObject private var store = GameStore(board: .empty())
    private let net = RealNetService()
    
    private let defaultHost = "127.0.0.1"
    private let defaultPort: UInt16 = 9090
    
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var showConnect = true
    
    
    var body: some Scene {
        WindowGroup {
            BoardView()
                .environmentObject(store)
                .sheet(isPresented: $showConnect) {
                    ConnectSheet(
                        initialNick: loadNick(),
                        initialHost: UserDefaults.standard.string(forKey: "host") ?? defaultHost,
                        initialPort: UInt(UserDefaults.standard.integer(forKey: "port")).nonZeroOr(default: Int(defaultPort)),
                        onConnect: { nick, host, port in
                            // persistir
                            UserDefaults.standard.set(nick, forKey: "nick")
                            UserDefaults.standard.set(host, forKey: "host")
                            UserDefaults.standard.set(port, forKey: "port")
                            // plugar rede e conectar
                            store.attach(service: net)
                            store.connect(host: host, port: UInt16(port), nick: nick)
                            showConnect = false
                        }
                    )
                    .presentationDetents([.medium, .large])
                    .interactiveDismissDisabled(true)
                }
            
                .onChange(of: scenePhase) {
                    if scenePhase == .inactive {
                        net.close()
                    }
                }
            
                .onChange(of: store.isConnected) { _, ok in
                    if !ok {
                        showConnect = true
                    }
                }
        }
    }
    
    private func loadNick() -> String {
        if let saved = UserDefaults.standard.string(forKey: "nick"), !saved.isEmpty {
            return saved
        }
        let nick = "Paulo-\(UUID().uuidString.prefix(4))"
        UserDefaults.standard.set(nick, forKey: "nick")
        return nick
    }
}

private extension UInt {
    func nonZeroOr(default def: Int) -> Int { self == 0 ? def : Int(self) }
}
