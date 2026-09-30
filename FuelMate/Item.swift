//
//  Item.swift
//  FuelMate
//
//  Created by YAZiTH JY on 2026-09-30.
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
