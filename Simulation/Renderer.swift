import MetalKit

class Renderer: NSObject {
    var device: MTLDevice
    var commandQueue: MTLCommandQueue!
    var resetAntsPipelineState: MTLComputePipelineState!
    var updateAntsAndTrailPipelineState: MTLComputePipelineState!
    var decayPipelineState: MTLComputePipelineState!
    var combinePipelineState: MTLComputePipelineState!
    var emitter: Emitter!
    var particleCount = 100000
    var currentTime: Float = 0
    
    var antVariables: AntVariables = {
        var variables = AntVariables()
        variables.moveSpeed = 2
        variables.turnSpeed = 0.1
        variables.sensorSize = 3
        variables.sensorDistance = 7.0
        variables.sensorAngle = 0.7
        variables.trailWeight = 0.3
        return variables
    }()
    
    var trailVariables: TrailVariables = {
        var variables = TrailVariables()
        variables.diffuseRate = 0.2
        variables.decayRate = 0.003
        return variables
    }()
    
    var trailTextureIndex = 1
    var maxTrailTextures = 3
    var trailTextures: [MTLTexture] = []
    var currentTrailTexture: MTLTexture {
        trailTextures[trailTextureIndex % maxTrailTextures]
    }
    var previousTrailTexture: MTLTexture {
        trailTextures[(trailTextureIndex - 1) % maxTrailTextures]
    }
    
    var antsTexture: MTLTexture!
    
    init(mtkView: MTKView, device: MTLDevice) {
        self.device = device
        self.commandQueue = device.makeCommandQueue()!
        super.init()
        
        emitter = Emitter(particleCount: particleCount, size: mtkView.drawableSize, device: device)
        
        createPipelineStates()
        
        buildTextures(size: mtkView.bounds.size)
    }
    
    //MARK: Builders
    func createPipelineStates() {
        let library = device.makeDefaultLibrary()
        
        do {
            guard let resetAnts = library?.makeFunction(name: "resetAnts") else { return }
            resetAntsPipelineState = try device.makeComputePipelineState(function: resetAnts)
            guard let updateAntsAndTrail = library?.makeFunction(name: "updateAntsAndTrail") else { return }
            updateAntsAndTrailPipelineState = try device.makeComputePipelineState(function: updateAntsAndTrail)
            guard let decay = library?.makeFunction(name: "decay") else { return }
            decayPipelineState = try device.makeComputePipelineState(function: decay)
            guard let combine = library?.makeFunction(name: "combine") else { return }
            combinePipelineState = try device.makeComputePipelineState(function: combine)
        } catch let error {
            print(error)
        }
    }
    
    func buildTextures(size: CGSize) {
        guard size.width > 0 && size.height > 0 else { return }
        trailTextures = []
        for i in 0..<maxTrailTextures {
            let texture = buildTexture(pixelFormat: .bgra8Unorm, size: size, label: "\(i)")
            makeTextureBlack(texture: texture)
            trailTextures.append(texture)
        }
        antsTexture = buildTexture(pixelFormat: .bgra8Unorm, size: size, label: "ants")
        makeTextureBlack(texture: antsTexture)
    }
    
    func buildTexture(pixelFormat: MTLPixelFormat,
                      size: CGSize,
                      label: String) -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: Int(size.width),
            height: Int(size.height),
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        descriptor.storageMode = .private
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            fatalError()
        }
        texture.label = "\(label) texture"
        
        return texture
    }
    
    func makeTextureBlack(texture: MTLTexture) {
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return
        }
        
        commandEncoder.setComputePipelineState(resetAntsPipelineState)
        commandEncoder.setTexture(texture, index: Int(AntsTexture.rawValue))
        let width = resetAntsPipelineState.threadExecutionWidth
        let height = resetAntsPipelineState.maxTotalThreadsPerThreadgroup / width
        let threadsPerGroup = MTLSizeMake(width, height, 1)
        let threadsPerGrid = MTLSizeMake(Int(texture.width),
                                         Int(texture.height),
                                         1)
        commandEncoder.dispatchThreads(threadsPerGrid,
                                       threadsPerThreadgroup: threadsPerGroup)
        commandEncoder.endEncoding()
        commandBuffer.commit()
    }
}

extension Renderer: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        drawableSizeWillChange(to: size)
    }
    
    func drawableSizeWillChange(to size: CGSize) {
        print("resizing \(size)")
        emitter = Emitter(particleCount: particleCount, size: size, device: device)
        buildTextures(size: size)
    }
    
    func resetAntsPass(view: MTKView, commandEncoder: MTLComputeCommandEncoder) {
        commandEncoder.setComputePipelineState(resetAntsPipelineState)
        let width = resetAntsPipelineState.threadExecutionWidth
        let height = resetAntsPipelineState.maxTotalThreadsPerThreadgroup / width
        let threadsPerGroup = MTLSizeMake(width, height, 1)
        let threadsPerGrid = MTLSizeMake(
            Int(view.drawableSize.width),
            Int(view.drawableSize.height),
            1
        )
        commandEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerGroup)
    }
    
    func decayPass(view: MTKView, commandEncoder: MTLComputeCommandEncoder) {
        commandEncoder.setComputePipelineState(decayPipelineState)
        commandEncoder.setBytes(&trailVariables,
                                length: MemoryLayout<TrailVariables>.stride,
                                index: Int(BufferIndexTrailVariables.rawValue))
        let width = decayPipelineState.threadExecutionWidth
        let height = decayPipelineState.maxTotalThreadsPerThreadgroup / width
        let threadsPerGroup = MTLSizeMake(width, height, 1)
        let textureWidth = currentTrailTexture.width
        let textureHeight = currentTrailTexture.height
        let threadsPerGrid = MTLSizeMake(textureWidth, textureHeight, 1)

        commandEncoder.dispatchThreads(threadsPerGrid,
                                       threadsPerThreadgroup: threadsPerGroup)
    }
    
    func updateAntsAndTrailsPass(view: MTKView, commandEncoder: MTLComputeCommandEncoder) {
        commandEncoder.setComputePipelineState(updateAntsAndTrailPipelineState)
        let threadsPerGroup = MTLSizeMake(1, 1, 1)
        let threadsPerGrid = MTLSizeMake(particleCount, 1, 1)
        commandEncoder.setBuffer(emitter.particleBuffer,
                                 offset: 0,
                                 index: 0)
        commandEncoder.setBytes(&particleCount,
                                length: MemoryLayout<Int>.stride,
                                index: 1)
        commandEncoder.setBytes(&antVariables,
                                length: MemoryLayout<AntVariables>.stride,
                                index: Int(BufferIndexAntVariables.rawValue))
        commandEncoder.setBytes(&currentTime,
                                length: MemoryLayout<Float>.stride,
                                index: 2)
        commandEncoder.dispatchThreads(threadsPerGrid,
                                       threadsPerThreadgroup: threadsPerGroup)
    }
    
    func combinePass(view: MTKView, commandEncoder: MTLComputeCommandEncoder, drawable: CAMetalDrawable) {
        commandEncoder.setComputePipelineState(combinePipelineState)
        let width = decayPipelineState.threadExecutionWidth
        let height = decayPipelineState.maxTotalThreadsPerThreadgroup / width
        let threadsPerGroup = MTLSizeMake(width, height, 1)
        let textureWidth = drawable.texture.width
        let textureHeight = drawable.texture.height
        let threadsPerGrid = MTLSizeMake(textureWidth, textureHeight, 1)
        commandEncoder.dispatchThreads(threadsPerGrid,
                                       threadsPerThreadgroup: threadsPerGroup)
    }
    
    func draw(in view: MTKView) {
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let commandEncoder = commandBuffer.makeComputeCommandEncoder(),
              let drawable = view.currentDrawable else { return }
        
        let deltaTime: Float = 1 / Float(view.preferredFramesPerSecond)
        currentTime += deltaTime
        
        //antVariables.trailWeight = 0.2 * sin(currentTime / 100) + 0.2
        //antVariables.moveSpeed = 3 * sin(currentTime + 0.1) + 0.1
        //print(antVariables.moveSpeed)
        
        commandEncoder.setTexture(drawable.texture, index: Int(DrawableTexture.rawValue))
        commandEncoder.setTexture(antsTexture, index: Int(AntsTexture.rawValue))
        commandEncoder.setTexture(currentTrailTexture, index: Int(CurrentTrailsTexture.rawValue))
        commandEncoder.setTexture(previousTrailTexture, index: Int(PreviousTrailsTexture.rawValue))
        
        resetAntsPass(view: view, commandEncoder: commandEncoder)
        
        decayPass(view: view, commandEncoder: commandEncoder)
        
        updateAntsAndTrailsPass(view: view, commandEncoder: commandEncoder)
        
        combinePass(view: view, commandEncoder: commandEncoder, drawable: drawable)
        
        trailTextureIndex += 1
        
        commandEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
