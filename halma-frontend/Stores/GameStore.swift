//
//  GameStore.swift
//  halma-frontend
//
//  Created by Paulo Henrique on 26/09/25.
//

import Foundation
import Combine

final class GameStore: ObservableObject {
    @Published var board: BoardState = .empty()
    @Published var isConnected: Bool = false
    @Published var turn: Int = 1
    @Published var selected: (x: Int, y: Int)? = nil
    @Published var lastStatus: String = "Pronto"
    @Published var myPlayer: Int?
    @Published var matchId: String?
    @Published var log: [String] = []
    @Published var chat: [ChatItem] = []
    @Published var hintTargets: [(Int, Int)] = []
    @Published var stepTargets: [(Int, Int)] = []
    @Published var winInfo: (winner: Int, reason: String?)? = nil
    @Published var moveCountP1: Int = 0
    @Published var moveCountP2: Int = 0


    private var service: NetService?   // RealNetService

    init(board: BoardState) { self.board = board }

    // Injetar rede real
    func attach(service: NetService) {
        self.service = service
        service.onEvent = { [weak self] msg in self?.handle(msg) }
        service.onState = { [weak self] ok in
            DispatchQueue.main.async {
                self?.isConnected = ok
                if !ok {
                    self?.lastStatus = "Desconectado"
                    self?.selected = nil
                    self?.hintTargets = []
                    self?.stepTargets = []
                }
            }
        }
    }

    func connect(host: String, port: UInt16, nick: String) {
        service?.connect(host: host, port: port, nick: nick)
    }
    
    func resign() {
         service?.sendResign()
         // limpar estados locais visuais
         selected = nil
         hintTargets = []
         stepTargets = []
         lastStatus = "Você desistiu — aguardando veredito do servidor…"
     }
    
    func close() {
        service?.close()                   // encerra a conexão TCP
        DispatchQueue.main.async {
            self.isConnected = false       // App apresenta a ConnectSheet ao ver false
            self.selected = nil
            self.hintTargets = []
            self.stepTargets = []
            self.winInfo = nil
            self.chat.removeAll()
            self.lastStatus = "Conexão encerrada"

            self.board = .empty()
            self.turn = 1
        }
    }

    // MARK: - Eventos do servidor
    private func handle(_ msg: AnyServerMsg) {
        switch msg {
        case .welcome(let w):
            if myPlayer == nil { myPlayer = w.player }
            if let mid = w.matchId { matchId = mid }
            lastStatus = "Você é J\(myPlayer ?? 0)"
            isConnected = true

        case .start(let s):
            if let mid = s.matchId { matchId = mid }
            var grid = Array(repeating: Array(repeating: Cell.empty, count: s.board.size), count: s.board.size)
            for p in s.board.pieces { grid[p.x][p.y] = (p.player == 1 ? .p1 : .p2) }
            board = BoardState(size: s.board.size, grid: grid)
            turn = s.turn
            if let me = myPlayer {
                lastStatus = "START recebido. Turno: J\(turn) — Você: J\(me)"
            } else {
                lastStatus = "START recebido. Turno: J\(turn)"
            }
            selected = nil
            hintTargets = []
            stepTargets = []
            isConnected = true
            if let m = s.moves {
                moveCountP1 = m.p1
                moveCountP2 = m.p2
            } else {
                moveCountP1 = 0
                moveCountP2 = 0
            }

        case .moveOk(let ok):
            let f = ok.applied.from, t = ok.applied.to
            let cell = board.grid[f[0]][f[1]]
            board.grid[f[0]][f[1]] = .empty
            board.grid[t[0]][t[1]] = cell
            turn = ok.turn
            selected = nil
            hintTargets = []
            stepTargets = []
            lastStatus = "MOVE_OK \(f)->\(t). Turno J\(turn)"
            if let m = ok.moves {
                moveCountP1 = m.p1
                moveCountP2 = m.p2
            }

        case .chat(let c):
            chat.append(ChatItem(player: c.player, text: c.text, timestamp: Date()))
            
        case .moveErr(let e):
            lastStatus = "MOVE_ERR: \(e.reason)"
            selected = nil
            hintTargets = []
            stepTargets = []

        case .end(let e):
            // Partida encerrada pelo servidor (ex.: oponente desconectou)
            lastStatus = "Partida encerrada: \(e.reason)"
            isConnected = false
            selected = nil
            hintTargets = []
            stepTargets = []

        case .error(let e):
            lastStatus = "ERROR: \(e.reason)"
            selected = nil
            hintTargets = []
            stepTargets = []
            
        case .win(let w):
            lastStatus = "Vitória: J\(w.winner) (\(w.reason))"
            selected = nil
            hintTargets = []
            
            DispatchQueue.main.async {
                 self.winInfo = (winner: w.winner, reason: w.reason)
             }
        }
        
    }

    /// Envia uma mensagem de chat para o servidor (ignora mensagens vazias)
    func sendChat(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        service?.sendChat(trimmed)
    }

    /// Reset normal (10×10). Se online, pede ao servidor; se offline, faz local.
    func requestResetNormal() {
        guard isConnected else {
            return // Sheet de conexão cobre este caso; não poluir a UI
        }
        service?.sendReset()
        selected = nil
        hintTargets = []
        stepTargets = []
        lastStatus = "Solicitado reset 10×10"
    }

    /// DEBUG: prepara um tabuleiro próximo da vitória para o jogador indicado (requer conexão)
    func requestDebugVictorySetup(winner: Int) {
        guard isConnected else {
            lastStatus = "Debug exige conexão"
            return
        }
        service?.sendDebugVictorySetup(winner: winner)
        selected = nil
        hintTargets = []
        stepTargets = []
        lastStatus = "Debug: vitória preparada para J\(winner)"
    }

    /// (Opcional) DEBUG: força WIN imediato para o jogador indicado (requer conexão)
    func requestDebugWinNow(winner: Int) {
        guard isConnected else {
            lastStatus = "Debug exige conexão"
            return
        }
        service?.sendDebugWinNow(winner: winner)
        selected = nil
        hintTargets = []
        stepTargets = []
        lastStatus = "Debug: WIN imediato para J\(winner)"
    }

    /// Reset local (fallback para quando estiver offline)
    func resetLocalToTen() {
        let n = board.size
        var grid = Array(repeating: Array(repeating: Cell.empty, count: n), count: n)
        let tri: [(Int,Int)] = [
            (0,0),(0,1),(0,2),(0,3),
            (1,0),(1,1),(1,2),
            (2,0),(2,1),
            (3,0),
        ]
        for (x,y) in tri { grid[x][y] = .p1 }
        for (x,y) in tri { grid[n-1-x][n-1-y] = .p2 }
        board = BoardState(size: n, grid: grid)
        turn = 1
        selected = nil
        hintTargets = []
        stepTargets = []
        lastStatus = "Reset local 10×10"
    }

    // MARK: - Ações da UI (agora pedem ao servidor)
    func tapCell(x: Int, y: Int) {
        guard let me = myPlayer else {
            lastStatus = "Aguardando WELCOME..."
            return
        }

        // Bloqueia seleção/hints se não for meu turno
        if turn != me {
            lastStatus = "Não é seu turno"
            selected = nil
            hintTargets = []
            stepTargets = []
            return
        }

        if let sel = selected {
            // precisa ser minha peça
            guard board.grid[sel.x][sel.y].rawValue == me else {
                selected = nil
                lastStatus = "Selecione sua peça (Você: J\(me))"
                return
            }
            // precisa ser meu turno
            guard turn == me else {
                lastStatus = "Não é seu turno"
                return
            }

            // tentativa de passo simples (servidor valida de fato)
            if canStep(from: sel, to: (x, y)) && board.grid[x][y] == .empty {
                service?.sendMove(from: [sel.x, sel.y], to: [x, y], path: nil)
                hintTargets = []
                stepTargets = []
                lastStatus = "Enviando passo (\(sel.x),\(sel.y))→(\(x),\(y))…"
            }
            // tentativa de salto simples (2 casas com peça no meio)
            else if canJump1(from: sel, to: (x, y)) {
                let path = [[sel.x, sel.y], [x, y]]
                service?.sendMove(from: [sel.x, sel.y], to: [x, y], path: path)
                hintTargets = []
                stepTargets = []
                lastStatus = "Enviando salto (\(sel.x),\(sel.y))→(\(x),\(y))…"
            } else {
                // Se tocou em outra peça sua, troca seleção e recalcula dicas
                if board.grid[x][y].rawValue == me {
                    selected = (x, y)
                    hintTargets = allJumpTargets(from: (x, y))
                    stepTargets = simpleStepTargets(from: (x, y))
                    lastStatus = "Selecionado (\(x),\(y))"
                } else {
                    selected = nil
                    hintTargets = []
                    stepTargets = []
                    lastStatus = "Movimento inválido"
                }
            }

        } else {
            // selecionar peça do meu jogador
            if board.grid[x][y].rawValue == me {
                selected = (x, y)
                hintTargets = allJumpTargets(from: (x, y))
                stepTargets = simpleStepTargets(from: (x, y))
                lastStatus = "Selecionado (\(x),\(y)) — Você: J\(me)"
            } else {
                lastStatus = "Selecione uma peça sua (Você: J\(me))"
            }
        }
    }

    private func canStep(from: (x: Int, y: Int), to: (x: Int, y: Int)) -> Bool {
        let dx = abs(to.x - from.x), dy = abs(to.y - from.y)
        return (dx <= 1 && dy <= 1 && (dx + dy) > 0)
    }
    
    /// Verifica salto simples: 2 casas em qualquer direção com peça no meio e destino vazio.
    private func canJump1(from: (x: Int, y: Int), to: (x: Int, y: Int)) -> Bool {
        let dx = to.x - from.x
        let dy = to.y - from.y
        let valid = [(2,0),(-2,0),(0,2),(0,-2),(2,2),(-2,-2),(2,-2),(-2,2)]
        guard valid.contains(where: { $0.0 == dx && $0.1 == dy }) else { return false }
        guard (0..<board.size).contains(to.x),
              (0..<board.size).contains(to.y) else { return false }
        let mx = from.x + dx/2
        let my = from.y + dy/2
        guard (0..<board.size).contains(mx),
              (0..<board.size).contains(my) else { return false }
        return board.grid[mx][my] != .empty && board.grid[to.x][to.y] == .empty
    }
    
    /// Alvos de PASSO simples (vizinhos vazios em 8 direções)
    func simpleStepTargets(from start: (x: Int, y: Int)) -> [(Int, Int)] {
        let dirs = [(-1,0),(1,0),(0,-1),(0,1),(-1,-1),(1,1),(-1,1),(1,-1)]
        let n = board.size
        return dirs.compactMap { dx, dy in
            let nx = start.x + dx, ny = start.y + dy
            guard (0..<n).contains(nx), (0..<n).contains(ny) else { return nil }
            return board.grid[nx][ny] == .empty ? (nx, ny) : nil
        }
    }
    
    // ---------- Hints de saltos (multi-hop) ----------
    /// Retorna todos os destinos alcançáveis via saltos encadeados (multi-hop) a partir de `start`.
    /// Não retorna o caminho, apenas as casas finais possíveis. O servidor valida a jogada completa.
    func allJumpTargets(from start: (x: Int, y: Int)) -> [(Int, Int)] {
        // 8 direções unitárias (ortogonais + diagonais)
        let dirs: [(Int, Int)] = [
            (1,0), (-1,0), (0,1), (0,-1),
            (1,1), (-1,-1), (1,-1), (-1,1)
        ]
        func inside(_ x: Int, _ y: Int) -> Bool {
            (0..<board.size).contains(x) && (0..<board.size).contains(y)
        }
        func empty(_ x: Int, _ y: Int) -> Bool {
            board.grid[x][y] == .empty
        }
        // usamos Set<String> para deduplicar posições alcançadas
        var seen = Set<String>()
        var results: [(Int, Int)] = []
        func key(_ p: (Int, Int)) -> String { "\(p.0),\(p.1)" }
        
        func dfs(from p: (Int, Int)) {
            let (fx, fy) = p
            for (dx, dy) in dirs {
                let mx = fx + dx, my = fy + dy             // casa da peça a ser pulada
                let lx = fx + 2*dx, ly = fy + 2*dy         // casa de aterrissagem
                guard inside(mx, my), inside(lx, ly) else { continue }
                // precisa ter peça no meio e destino vazio
                guard board.grid[mx][my] != .empty, empty(lx, ly) else { continue }
                let landing = (lx, ly)
                if !seen.contains(key(landing)) {
                    seen.insert(key(landing))
                    results.append(landing)
                    // a partir da nova posição, pode haver mais saltos
                    dfs(from: landing)
                }
            }
        }
        dfs(from: (start.x, start.y))
        return results
    }

    // Mock só para Preview
    static func mock(size: Int = 8) -> GameStore {
        var grid = Array(repeating: Array(repeating: Cell.empty, count: size), count: size)
        grid[0][0] = .p1; grid[0][1] = .p1
        grid[size-1][size-2] = .p2; grid[size-1][size-1] = .p2
        return GameStore(board: BoardState(size: size, grid: grid))
    }
}
