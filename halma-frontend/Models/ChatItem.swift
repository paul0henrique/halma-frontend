//
//   ChatItem.swift
//  halma-frontend
//
//  Created by Paulo Henrique on 29/09/25.
//

import Foundation

struct ChatItem: Identifiable, Equatable {
    let id = UUID()
    let player: Int?
    let text: String
    let timestamp: Date
}
