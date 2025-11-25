//
//  RealNetService.swift
//  halma-frontend
//
//  Created by Paulo Henrique on 26/09/25.
//

import Foundation
import Network

final class RealNetService: NetService {
    var onEvent: ((AnyServerMsg) -> Void)?
    var onState: ((Bool) -> Void)?
    
    private var conn: NWConnection?
    private var recvBuffer = Data()
    private let enc = JSONEncoder()
    private let dec = JSONDecoder()
    
    func connect(host: String, port: UInt16, nick: String) {
        let c = NWConnection(host: NWEndpoint.Host(host),
                             port: NWEndpoint.Port(rawValue: port)!,
                             using: .tcp)
        conn = c
        
        c.stateUpdateHandler = { [weak self] st in
            switch st {
            case .ready:
                DispatchQueue.main.async { self?.onState?(true) }
                // HELLO imediato
                let hello = Hello(type: .HELLO, matchId: "demo", nick: nick)
                self?.send(hello)
                self?.receiveLoop()
            case .waiting(let e):
                // Transiente: a conexão está aguardando rede/servidor.
                print("NW waiting:", e)
            case .failed(let e):
                print("NW failed:", e)
                DispatchQueue.main.async { self?.onState?(false) }
                self?.conn = nil
            case .cancelled:
                DispatchQueue.main.async { self?.onState?(false) }
                self?.conn = nil
            default:
                break
            }
        }
        c.start(queue: .global())
    }
    
    func sendMove(from: [Int], to: [Int], path: [[Int]]?) {
        // sanity checks: esperamos [x,y] e [x,y]
        guard from.count == 2, to.count == 2 else {
            print("sendMove: formato inválido — 'from' e 'to' devem ser [x,y]. from=\(from) to=\(to)")
            return
        }
        let m = MoveMsg(type: .MOVE, matchId: "demo", from: from, to: to, path: path)

        #if DEBUG
        if let data = try? enc.encode(m), let s = String(data: data, encoding: .utf8) {
            print("→ send MOVE:", s)
        }
        #endif
        send(m)
    }
    
    // Overload conveniente: tuplas (x,y) e caminho como [(x,y)]
    func sendMove(from: (Int, Int), to: (Int, Int), path: [(Int, Int)]?) {
        let fromArr = [from.0, from.1]
        let toArr = [to.0, to.1]
        let pathArr = path?.map { [$0.0, $0.1] }
        sendMove(from: fromArr, to: toArr, path: pathArr)
    }
    
    func sendChat(_ text: String) {
        let m = ChatMsg(type: .CHAT, matchId: "demo", text: text)
        send(m)
    }

    /// Solicita RESET ao servidor (reinicia partida com setup padrão 10x10)
    func sendReset() {
        let msg = ResetMsg(type: .RESET)
        send(msg)
    }

    /// DEBUG: prepara tabuleiro em cenário de quase vitória para o jogador indicado
    func sendDebugVictorySetup(winner: Int) {
        let msg = DebugMsg(type: .DEBUG, mode: "victory_setup", winner: winner)
        send(msg)
    }

    /// DEBUG: força emissão imediata de WIN pelo servidor
    func sendDebugWinNow(winner: Int) {
        let msg = DebugMsg(type: .DEBUG, mode: "win_now", winner: winner)
        send(msg)
    }
    
    func sendResign() {
        let msg = ResignMsg(type: .RESIGN)
        send(msg)
    }
    
    func close() {
        conn?.cancel()
        conn = nil
        DispatchQueue.main.async { self.onState?(false) }
    }
    
    // MARK: - Internals
    private func send<T: Encodable>(_ msg: T) {
        guard let c = conn else { return }
        do {
            var data = try enc.encode(msg)
            data.append(0x0A)               // '\n' → NDJSON
            c.send(content: data, completion: .contentProcessed { _ in })
        } catch {
            print("encode error:", error)
        }
    }
    
    private func receiveLoop() {
        conn?.receive(minimumIncompleteLength: 1, maximumLength: 64*1024) { [weak self] data, _, done, err in
            guard let self = self else { return }
            if let d = data, !d.isEmpty {
                self.recvBuffer.append(d)
                // separar por '\n' (NDJSON), usando firstIndex(of:) para evitar ranges inválidos
                while let nl = self.recvBuffer.firstIndex(of: 0x0A) { // 0x0A = '\n'
                    let lineSlice = self.recvBuffer[..<nl]
                    let next = self.recvBuffer.index(after: nl) // posição após o '\n'
                    self.recvBuffer.removeSubrange(..<next)
                    if !lineSlice.isEmpty {
                        let line = Data(lineSlice)
                        do {
                            let msg = try self.dec.decode(AnyServerMsg.self, from: line)
                            DispatchQueue.main.async { self.onEvent?(msg) }
                        } catch {
                            print("json inválido:", String(data: line, encoding: .utf8) ?? "?", "err:", error)
                        }
                    }
                }
            }
            if done == true || err != nil {
                DispatchQueue.main.async { self.onState?(false) }
                return
            }
            if err == nil, done == false {
                self.receiveLoop()
            }
        }
    }
}
