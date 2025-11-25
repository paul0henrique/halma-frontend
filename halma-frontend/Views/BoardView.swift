//
//  BoardView.swift
//  halma-frontend
//
//  Created by Paulo Henrique on 26/09/25.
//

import SwiftUI

struct BoardView: View {
    @EnvironmentObject var store: GameStore
    @State private var showChat = false
    @State private var showWinAlert = false
    @State private var showResignConfirm = false
    @State private var showDebugDialog = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                header
                boardGrid
                footer
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(role: .destructive) {
                        showResignConfirm = true
                    } label: {
                        Label("Desistir", systemImage: "flag.slash")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showChat = true
                    } label: {
                        Image(systemName: "bubble.left.and.bubble.right")
                    }
                    .accessibilityLabel("Abrir chat")
                }
            }
            .confirmationDialog("Deseja realmente desistir?",
                                isPresented: $showResignConfirm,
                                titleVisibility: .visible) {
                Button("Desistir", role: .destructive) {
                    store.resign()
                }
                Button("Cancelar", role: .cancel) {}
            }
                                .sheet(isPresented: $showChat) {
                                    NavigationStack {
                                        ChatView()
                                            .environmentObject(store)
                                            .presentationDragIndicator(.visible)
                                        
                                    }
                                }
                                .onReceive(store.$winInfo) { info in
                                    showWinAlert = (info != nil)
                                }
                                .alert("Fim de jogo", isPresented: $showWinAlert) {
                                    Button("Reconectar") {
                                        store.close()
                                    }
                                } message: {
                                    if let info = store.winInfo {
                                        if let reason = info.reason, !reason.isEmpty {
                                            Text("Jogador J\(info.winner) venceu (\(reason)).")
                                        } else {
                                            Text("Jogador J\(info.winner) venceu.")
                                        }
                                    } else {
                                        Text("Partida encerrada.")
                                    }
                                }
                                .navigationTitle("Halma")
                                .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - Header
    private var header: some View {
        HStack {
            VStack(alignment: .center, spacing: 2) {
                HStack(spacing: 8) {
                    Text("Turno: J\(store.turn)")
                        .font(.headline)
                    if let me = store.myPlayer {
                        Text(me == store.turn ? "• sua vez" : "• aguardando")
                            .font(.subheadline)
                            .foregroundStyle(me == store.turn ? .green : .secondary)
                            .transition(.opacity)
                    }
                }
                // Contadores de jogadas
                HStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Circle()
                            .frame(width: 8, height: 8)
                            .foregroundStyle(.blue)
                        Text("J1: \(store.moveCountP1)")
                    }
                    HStack(spacing: 6) {
                        Circle()
                            .frame(width: 8, height: 8)
                            .foregroundStyle(.red)
                        Text("J2: \(store.moveCountP2)")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                
            }
        }
    }
    
    // MARK: - Grid
    private var boardGrid: some View {
        let n = store.board.size
        return VStack(spacing: 4) {
            ForEach(0..<n, id: \.self) { x in
                HStack(spacing: 4) {
                    ForEach(0..<n, id: \.self) { y in
                        cellView(x: x, y: y)
                    }
                }
            }
        }
        .background(Color.secondary.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .animation(.default, value: (store.hintTargets + store.stepTargets).map { "\($0.0),\($0.1)" })
    }
    
    private func cellView(x: Int, y: Int) -> some View {
        let cell = store.board.grid[x][y]
        let isSel = store.selected?.x == x && store.selected?.y == y
        let isHint = store.hintTargets.contains { $0.0 == x && $0.1 == y }
        let isStep = store.stepTargets.contains { $0.0 == x && $0.1 == y }
        
        return Button {
            store.tapCell(x: x, y: y)
        } label: {
            ZStack {
                // tabuleiro com padrão quadriculado
                Rectangle()
                    .fill(((x + y) % 2 == 0) ? Color.gray.opacity(0.18) : Color.gray.opacity(0.06))
                
                // peça
                if cell != .empty {
                    Circle()
                        .frame(width: 26, height: 26)
                        .overlay(Circle().strokeBorder(.primary.opacity(0.2)))
                        .foregroundStyle(cell == .p1 ? .blue : .red)
                        .shadow(radius: 0.8)
                }
                
                // dicas de salto (pré-visualização)
                if isHint {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(style: StrokeStyle(lineWidth: 3, dash: [6,4]))
                        .foregroundStyle(.blue.opacity(0.85))
                        .padding(3)
                }
                
                // dicas de PASSO (adjacente): ponto verde discreto
                if isStep {
                    Circle()
                        .frame(width: 8, height: 8)
                        .foregroundStyle(.green.opacity(0.9))
                }
                
                // seleção
                if isSel {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(.yellow, lineWidth: 2)
                        .padding(2)
                }
            }
            .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .accessibilityLabel("(\(x),\(y))")
    }
    
    // MARK: - Footer
    private var footer: some View {
        VStack {
            HStack {
                Button("Reset") {
                    store.requestResetNormal()
                }
                .disabled(!store.isConnected)
                .foregroundStyle(Color(UIColor.label))
                .font(.headline)

                Button("Debug") { showDebugDialog = true }
                    .disabled(!store.isConnected)
                    .foregroundStyle(Color(UIColor.label))
                    .font(.headline)
                    .confirmationDialog("Debug",
                                        isPresented: $showDebugDialog,
                                        titleVisibility: .visible) {
                        Button("Preparar vitória (J1)") {
                            store.requestDebugVictorySetup(winner: 1)
                        }
                        Button("Cancelar", role: .cancel) {}
                    }
            }
            .padding()
            Text("**Log:** \(store.lastStatus)")
                .font(.subheadline)
        }
    }
}

#Preview {
    BoardView()
        .environmentObject(GameStore.mock())
}
