//
//  Common.swift
//  Simulation
//
//  Created by Jaap Wijnen on 31/05/2021.
//

import Foundation

extension AntVariables {
    var sensorSizeFloat: Float {
        get {
            Float(sensorSize)
        }
        set {
            sensorSize = Int32(newValue)
        }
    }
    
    var countFloat: Float {
        get {
            Float(count)
        }
        set {
            count = Int32(newValue)
        }
    }
}
