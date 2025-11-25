//
//  ConnectSheet.swift
//  halma-frontend
//
//  Created by Paulo Henrique on 29/09/25.
//

import SwiftUI

struct ConnectSheet: View {
    @State private var nick: String
    @State private var host: String
    @State private var port: String

    let onConnect: (_ nick: String, _ host: String, _ port: Int) -> Void

    init(initialNick: String, initialHost: String, initialPort: Int, onConnect: @escaping (String, String, Int) -> Void) {
        _nick = State(initialValue: initialNick)
        _host = State(initialValue: initialHost)
        _port = State(initialValue: String(initialPort))
        self.onConnect = onConnect
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Identificação")) {
                    TextField("Nick", text: $nick)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Section(header: Text("Servidor")) {
                    TextField("Host", text: $host)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Porta", text: $port)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("Nova partida")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Conectar") {
                        guard let p = Int(port), p > 0 && p < 65536, !nick.isEmpty, !host.isEmpty else { return }
                        onConnect(nick, host, p)
                    }
                }
            }
        }
    }
}

//#Preview {
//    ConnectSheet()
//}
