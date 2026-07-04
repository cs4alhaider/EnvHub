//
//  Item.swift
//  EnvHub
//
//  Created by 16Root24 on 04/07/2026.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
