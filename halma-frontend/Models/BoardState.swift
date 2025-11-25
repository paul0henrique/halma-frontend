//
//  BoardState.swift
//  halma-frontend
//
//  Created by Paulo Henrique on 26/09/25.
//

import Foundation

struct BoardState: Codable, Equatable {
    let size: Int
    var grid: [[Cell]] // [linha][coluna]
}

extension BoardState {
    static func empty(size: Int = 8) -> BoardState {
        let grid = Array(repeating: Array(repeating: Cell.empty, count: size), count: size)
        return BoardState(size: size, grid: grid)
    }
}
