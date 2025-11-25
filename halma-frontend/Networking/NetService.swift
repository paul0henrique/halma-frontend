//
//  NetService.swift
//  halma-frontend
//
//  Created by Paulo Henrique on 26/09/25.
//


import Foundation

/// Abstração da camada de rede usada pela Store.
protocol NetService: AnyObject {
    // Callbacks
    var onEvent: ((AnyServerMsg) -> Void)? { get set }  // mensagens servidor→cliente
    var onState: ((Bool) -> Void)? { get set }          // true = conectado, false = desconectado

    // Conexão
    func connect(host: String, port: UInt16, nick: String)
    func close()

    // Envio
    func sendMove(from: [Int], to: [Int], path: [[Int]]?)
    func sendChat(_ text: String)

    // Fluxos da partida
    func sendReset()                // reset normal 10×10 (somente on-line)
    func sendResign()               // desistir

    // Debug (separado do reset)
    func sendDebugVictorySetup(winner: Int)   // prepara tabuleiro próximo da vitória
    func sendDebugWinNow(winner: Int)         // força WIN imediato (opcional)
}
