//
//  MessageHandling.swift
//  BawiBrowser
//
//  Created by Jae Seung Lee on 10/18/25.
//

protocol MessageHandling: Actor {
    func process() async -> Void
}
