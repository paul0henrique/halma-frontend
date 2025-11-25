//
//  NetMessage.swift
//  halma-frontend
//
//  Created by Paulo Henrique on 26/09/25.
//

import Foundation

enum MsgType: String, Codable { case HELLO, WELCOME, START, MOVE, MOVE_OK, MOVE_ERR, CHAT, ERROR, END, WIN, RESIGN, RESET, DEBUG }

struct Hello: Codable {
    let type: MsgType
    let matchId: String
    let nick: String
}

struct Welcome: Codable {
    let type: MsgType
    let matchId: String?
    let player: Int
    let starts: Int?
}

struct BoardDTO: Codable { let size: Int; let pieces: [PieceDTO] }
struct PieceDTO: Codable { let player: Int; let x: Int; let y: Int }

struct MovesDTO: Codable {
    let p1: Int
    let p2: Int
}

struct Start: Codable {
    let type: MsgType
    let matchId: String?
    let turn: Int
    let board: BoardDTO
    let moves: MovesDTO?   // opcional para compatibilidade retroativa
}

struct MoveMsg: Codable {
    let type: MsgType
    let matchId: String
    let from: [Int]
    let to: [Int]
    let path: [[Int]]?
}
struct MoveOk: Codable {
    let type: MsgType
    let applied: Applied
    let turn: Int
    let moves: MovesDTO?   // opcional para compatibilidade retroativa
    struct Applied: Codable { let from: [Int]; let to: [Int]; let path: [[Int]] }
}

struct ChatMsg: Codable {
    let type: MsgType
    let matchId: String
    let text: String
    let player: Int?
    
    init(type: MsgType, matchId: String, text: String, player: Int? = nil) {
        self.type = type
        self.matchId = matchId
        self.text = text
        self.player = player
    }
}

struct MoveErr: Codable {
    let type: MsgType
    let reason: String
}

struct ErrorMsg: Codable {
    let type: MsgType
    let reason: String
}

struct End: Codable {
    let type: MsgType
    let reason: String
}

struct WinMsg: Codable {
    let type: MsgType
    let winner: Int
    let reason: String
}

struct ResetMsg: Codable {
    let type: MsgType
}

struct ResignMsg: Codable {
    let type: MsgType
}

struct DebugMsg: Codable {
    let type: MsgType
    let mode: String
    let winner: Int?
}

enum AnyServerMsg: Codable {
    case welcome(Welcome)
    case start(Start)
    case moveOk(MoveOk)
    case chat(ChatMsg)
    case moveErr(MoveErr)
    case error(ErrorMsg)
    case end(End)
    case win(WinMsg)

    private enum CodingKeys: String, CodingKey { case type }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let t = try c.decode(MsgType.self, forKey: .type)

        switch t {
        case .WELCOME: self = .welcome(try Welcome(from: decoder))
        case .START:   self = .start(try Start(from: decoder))
        case .MOVE_OK: self = .moveOk(try MoveOk(from: decoder))
        case .CHAT:    self = .chat(try ChatMsg(from: decoder))
        case .MOVE_ERR:self = .moveErr(try MoveErr(from: decoder))
        case .ERROR:   self = .error(try ErrorMsg(from: decoder))
        case .END:     self = .end(try End(from: decoder))
        case .WIN:     self = .win(try WinMsg(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: c, debugDescription: "unsupported type: \(t)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .welcome(let v): try v.encode(to: encoder)
        case .start(let v):   try v.encode(to: encoder)
        case .moveOk(let v):  try v.encode(to: encoder)
        case .chat(let v):    try v.encode(to: encoder)
        case .moveErr(let v): try v.encode(to: encoder)
        case .error(let v):   try v.encode(to: encoder)
        case .end(let v):     try v.encode(to: encoder)
        case .win(let v): try v.encode(to: encoder)
        }
    }
}
