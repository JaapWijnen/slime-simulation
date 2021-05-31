//
//  ContentView.swift
//  Simulation
//
//  Created by Jaap Wijnen on 24/05/2021.
//

import SwiftUI
import Combine

struct ContentView: View {
    var metalView: MetalView
    @ObservedObject var renderer: Renderer
        
    init() {
        self.metalView = MetalView()
        self.renderer = metalView.renderer
    }
    
    var body: some View {
        HStack {
            SwiftUIView {
                metalView
            }.frame(minWidth: 10)
            VStack {
                Slider(
                    value: $renderer.antVariables.moveSpeed,
                    in: 0...15,
                    label: { Text("Move speed \(renderer.antVariables.moveSpeed, specifier: "%.1f")") }
                )
                Slider(
                    value: $renderer.antVariables.turnSpeed,
                    in: 0...(.pi),
                    label: { Text("Turn speed \(renderer.antVariables.turnSpeed / .pi, specifier: "%.2f")π") }
                )
                Slider(
                    value: $renderer.antVariables.sensorSizeFloat,
                    in: 0...5,
                    step: 1,
                    label: { Text("Sensor size \(renderer.antVariables.sensorSize)") }
                )
                Slider(
                    value: $renderer.antVariables.sensorDistance,
                    in: 0...40,
                    label: { Text("Sensor distance \(renderer.antVariables.sensorDistance, specifier: "%.1f")") }
                )
                Slider(
                    value: $renderer.antVariables.sensorAngle,
                    in: 0...(.pi),
                    label: { Text("Sensor angle \(renderer.antVariables.sensorAngle / .pi, specifier: "%.2f")π") }
                )
                Slider(
                    value: $renderer.antVariables.trailWeight,
                    in: 0...1,
                    label: { Text("Trail weight \(renderer.antVariables.trailWeight, specifier: "%.1f")") }
                )
                Slider(
                    value: $renderer.trailVariables.diffuseRate,
                    in: 0...2,
                    label: { Text("Diffuse rate \(renderer.trailVariables.diffuseRate, specifier: "%.2f")") }
                )
                Slider(
                    value: $renderer.trailVariables.decayRate,
                    in: 0...0.01,
                    label: { Text("Decay rate \(renderer.trailVariables.decayRate, specifier: "%.3f")") }
                )
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
