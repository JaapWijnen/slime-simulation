import MetalKit

struct Particle {
    var position: SIMD2<Float>
    var angle: Float
}

class Emitter {
    let particlePipelineState: MTLComputePipelineState
    var particleCount: Int
    var particleUniforms: ParticleUniforms
    var particleBuffer: MTLBuffer!
    
    init(particleCount: Int, size: CGSize, device: MTLDevice, library: MTLLibrary, commandQueue: MTLCommandQueue) {
        self.particleCount = particleCount
        self.particleUniforms = ParticleUniforms(width: Float(size.width), height: Float(size.height))
        
        self.particleCount = particleCount
        self.particleBuffer = device.makeBuffer(length: MemoryLayout<Particle>.stride * particleCount, options: .storageModePrivate)
        self.particleBuffer.label = "Ant Buffer"
        
        let particleFunction = library.makeFunction(name: "generateAnts")!
        self.particlePipelineState = try! device.makeComputePipelineState(function: particleFunction)
        
        update(size: size, device: device, commandQueue: commandQueue)
    }
    
    func update(size: CGSize, device: MTLDevice, commandQueue: MTLCommandQueue) {
        particleUniforms = ParticleUniforms(width: Float(size.width), height: Float(size.height))
        
        //triggerProgrammaticCapture(device: device)
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let commandEncoder = commandBuffer.makeComputeCommandEncoder()!
        commandEncoder.setComputePipelineState(particlePipelineState)
        commandEncoder.setBuffer(particleBuffer, offset: 0, index: BufferIndex.particleBuffer.rawValue)
        commandEncoder.setBytes(&particleUniforms, length: MemoryLayout<ParticleUniforms>.stride, index: BufferIndex.antsUniforms.rawValue)
        let width = particlePipelineState.threadExecutionWidth
        let height = particlePipelineState.maxTotalThreadsPerThreadgroup / width
        let threadsPerGroup = MTLSizeMake(width, 1, 1)
        let threadsPerGrid = MTLSizeMake(self.particleCount, 1, 1)
        commandEncoder.dispatchThreads(threadsPerGrid,
                                       threadsPerThreadgroup: threadsPerGroup)
        commandEncoder.endEncoding()
        commandBuffer.commit()
        
//        let captureManager = MTLCaptureManager.shared()
//        captureManager.stopCapture()
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
    
    func triggerProgrammaticCapture(device: MTLDevice) {
        let captureManager = MTLCaptureManager.shared()
        let captureDescriptor = MTLCaptureDescriptor()
        captureDescriptor.captureObject = device
        do {
            try captureManager.startCapture(with: captureDescriptor)
        }
        catch
        {
            fatalError("error when trying to capture: \(error)")
        }
    }

}
