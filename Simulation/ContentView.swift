//
//  ContentView.swift
//  Simulation
//
//  Created by Jaap Wijnen on 24/05/2021.
//

import SwiftUI

struct ContentView: View {
    
    @State var moveSpeed: Float = 2
    @State var turnSpeed: Float = 0.1
    @State var sensorSize: Float = 3
    @State var sensorDistance: Float = 7
    @State var sensorAngle: Float = 0.7
    @State var trailWeight: Float = 0.3
    
    @State var diffuseRate: Float = 0.2
    @State var decayRate: Float = 0.003
    
    var metalView: MetalView
    
    init() {
        self.metalView = MetalView()
        metalView.renderer.antVariables.moveSpeed = moveSpeed
        metalView.renderer.antVariables.turnSpeed = turnSpeed
        metalView.renderer.antVariables.sensorSize = Int32(sensorSize)
        metalView.renderer.antVariables.sensorDistance = sensorDistance
        metalView.renderer.antVariables.sensorAngle = sensorAngle
        metalView.renderer.antVariables.trailWeight = trailWeight
        
        metalView.renderer.trailVariables.diffuseRate = diffuseRate
        metalView.renderer.trailVariables.decayRate = decayRate
    }
    
    var body: some View {
        HStack {
            SwiftUIView {
                metalView
            }.frame(minWidth: 10)
            VStack {
                Slider(
                    value: $moveSpeed,
                    in: 0...15,
                    label: { Text("Move speed \(moveSpeed, specifier: "%.1f")") }
                ).onChange(of: moveSpeed, perform: { value in
                    metalView.renderer.antVariables.moveSpeed = value
                })
                Slider(
                    value: $turnSpeed,
                    in: 0...(.pi),
                    label: { Text("Turn speed \(turnSpeed / .pi, specifier: "%.2f")π") }
                ).onChange(of: turnSpeed, perform: { value in
                    metalView.renderer.antVariables.turnSpeed = value
                })
                Slider(
                    value: $sensorSize,
                    in: 0...5,
                    step: 1,
                    label: { Text("Sensor size \(Int32(sensorSize))") }
                ).onChange(of: sensorSize, perform: { value in
                    metalView.renderer.antVariables.sensorSize = Int32(value)
                })
                Slider(
                    value: $sensorDistance,
                    in: 0...40,
                    label: { Text("Sensor distance \(sensorDistance, specifier: "%.1f")") }
                ).onChange(of: sensorDistance, perform: { value in
                    metalView.renderer.antVariables.sensorDistance = value
                })
                Slider(
                    value: $sensorAngle,
                    in: 0...(.pi),
                    label: { Text("Sensor angle \(sensorAngle / .pi, specifier: "%.2f")π") }
                ).onChange(of: sensorAngle, perform: { value in
                    metalView.renderer.antVariables.sensorAngle = value
                })
                Slider(
                    value: $trailWeight,
                    in: 0...1,
                    label: { Text("Trail weight \(trailWeight, specifier: "%.1f")") }
                ).onChange(of: trailWeight, perform: { value in
                    metalView.renderer.antVariables.trailWeight = value
                })
                Slider(
                    value: $diffuseRate,
                    in: 0...2,
                    label: { Text("Diffuse rate \(diffuseRate, specifier: "%.2f")") }
                ).onChange(of: diffuseRate, perform: { value in
                    metalView.renderer.trailVariables.diffuseRate = value
                })
                Slider(
                    value: $decayRate,
                    in: 0...0.01,
                    label: { Text("Decay rate \(decayRate, specifier: "%.3f")") }
                ).onChange(of: decayRate, perform: { value in
                    metalView.renderer.trailVariables.decayRate = value
                })
                Spacer()
            }
            .padding()
            .frame(minWidth: 290, idealWidth: 290, maxWidth: 290, alignment: .center)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
