//
//  File.swift
//  
//
//  Created by Jatinder Sidhu on 2022-10-07.
//

import Foundation

public enum PushError: Error {
    case pushFailed(Message)
    case timeout(event: String, payload: Payload)
}
