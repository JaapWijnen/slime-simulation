import MetalKit

struct Particle {
    var position: SIMD2<Float>
    var angle: Float
}

class Emitter {
    var particleBuffer: MTLBuffer!
  
    init(particleCount: Int, size: CGSize, device: MTLDevice) {
        let bufferSize = MemoryLayout<Particle>.stride * particleCount
        particleBuffer = device.makeBuffer(length: bufferSize)
        var pointer = particleBuffer.contents().bindMemory(to: Particle.self,
                                                           capacity: particleCount)
        for _ in 0..<particleCount {
            let distance = Float(size.height) / 4//Float.random(in: 0..<(Float(size.height) / 4))
            let angle = Float.random(in: 0..<(2 * Float.pi))
            let x = cos(angle) * distance + Float(size.width) / 2
            let y = sin(angle) * distance + Float(size.height) / 2
            pointer.pointee.position = SIMD2<Float>(x, y)
            pointer.pointee.angle = angle
            
            
//            let width = random(Int(size.width) / 2) + Float(size.width) / Float(4)
//            let height = random(Int(size.height) / 2) + Float(size.height) / Float(4)
//            let position = SIMD2<Float>(width, height)
//            pointer.pointee.position = position
//            pointer.pointee.angle = Float.random(in: 0..<2 * Float.pi)
            pointer = pointer.advanced(by: 1)
        }
    }
    
    func random(_ max: Int) -> Float {
        if max == 0 { return 0 }
        return Float.random(in: 0..<Float(max))
    }
    
    private func makeRotationMatrix(angle: Float) -> simd_float2x2 {
        let rows = [
            simd_float2(cos(angle), -sin(angle)),
            simd_float2(sin(angle), cos(angle)),
        ]
        
        return float2x2(rows: rows)
    }
}
