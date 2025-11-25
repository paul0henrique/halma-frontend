//
//  ChatView.swift
//  halma-frontend
//
//  Created by Paulo Henrique on 29/09/25.
//

import SwiftUI

struct ChatView: View {
    @EnvironmentObject var store: GameStore
    @State private var draft = ""

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                List {
                    ForEach(store.chat) { msg in
                        let mine = isMine(msg)
                        HStack(alignment: .bottom) {
                            if mine { Spacer(minLength: 40) }
                            VStack(alignment: mine ? .trailing : .leading, spacing: 4) {
                                Text(header(for: msg))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: mine ? .trailing : .leading)
                                    .opacity(0.9)
                                Text(msg.text)
                                    .font(.body)
                                    .foregroundStyle(mine ? .white : .primary)
                                    .padding(10)
                                    .background(mine ? Color.accentColor : Color(.secondarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            if !mine { Spacer(minLength: 40) }
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .id(msg.id)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color(.systemGroupedBackground))
                .onChange(of: store.chat.count) { _ in
                    if let last = store.chat.last { proxy.scrollTo(last.id, anchor: .bottom) }
                }
                .onAppear {
                    if let last = store.chat.last { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }

            HStack(spacing: 8) {
                TextField("Mensagem…", text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(send)
                Button("Enviar") { send() }
                    .buttonStyle(.borderedProminent)
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
            .background(.thinMaterial)
        }
        .navigationTitle("Chat")
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        store.sendChat(text)
        draft = ""
    }

    private func isMine(_ msg: ChatItem) -> Bool {
        guard let me = store.myPlayer else { return false }
        return msg.player == me
    }

    private func header(for msg: ChatItem) -> String {
        if let p = msg.player, let me = store.myPlayer {
            return p == me ? "Você (J\(p))" : "J\(p)"
        }
        return "Mensagem"
    }
}

#Preview {
    let s = GameStore.mock()
    s.chat = [
        ChatItem(player: 1, text: "Olá!", timestamp: .init()),
        ChatItem(player: 2, text: "Oi!", timestamp: .init())
    ]
    return NavigationStack { ChatView().environmentObject(s) }
}
