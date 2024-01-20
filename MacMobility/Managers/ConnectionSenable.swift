//
//  ConnectionSenable.swift
//  MagicTrackpad
//
//  Created by Mariusz Jakowienko on 22/07/2023.
//

import SwiftUI
import MultipeerConnectivity
import os
import Foundation
import Combine

protocol ConnectionSenable {
    var session: MCSession { get }
    func send(_ data: Data)
}

extension ConnectionSenable {
    func send(_ data: Data) {
        do {
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
        } catch {
            Logger().error("Error for sending: \(String(describing: error))")
        }
    }
}
