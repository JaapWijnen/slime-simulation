import MetalKit
import SwiftUI

class Renderer: NSObject, ObservableObject {
    var device: MTLDevice
    var commandQueue: MTLCommandQueue!
    var library: MTLLibrary!
    var resetAntsPipelineState: MTLComputePipelineState!
    var updateAntsAndTrailPipelineState: MTLComputePipelineState!
    var decayPipelineState: MTLComputePipelineState!
    var combinePipelineState: MTLComputePipelineState!
    var emitter: Emitter!
    var currentTime: Float = 0
    
    @Published var antVariables: AntVariables = {
        var variables = AntVariables()
        variables.count = 1000000
        variables.moveSpeed = 2
        variables.turnSpeed = 0.1
        variables.sensorSize = 3
        variables.sensorDistance = 7.0
        variables.sensorAngle = 0.7
        variables.trailWeight = 0.3
        return variables
    }()
    
    @Published var trailVariables: TrailVariables = {
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
        
        createPipelineStates()
        emitter = Emitter(particleCount: Int(antVariables.count), size: mtkView.drawableSize, device: device, library: library, commandQueue: commandQueue)
        
        
        
        buildTextures(size: mtkView.bounds.size)
    }
    
    //MARK: Builders
    func createPipelineStates() {
        self.library = device.makeDefaultLibrary()
        
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
        commandEncoder.setTexture(texture, index: TextureIndex.ants.rawValue)
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
        emitter.update(size: size, device: device, commandQueue: commandQueue)
        buildTextures(size: size)
    }
    
    func draw(in view: MTKView) {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        
        
        
        let deltaTime: Float = 1 / Float(view.preferredFramesPerSecond)
        currentTime += deltaTime
        
        //antVariables.trailWeight = 0.2 * sin(currentTime / 100) + 0.2
        //antVariables.moveSpeed = 3 * sin(currentTime + 0.1) + 0.1
        //print(antVariables.moveSpeed)
        
        var commandEncoder = commandBuffer.makeComputeCommandEncoder()
        
        // reset ants pass
        commandEncoder?.setComputePipelineState(resetAntsPipelineState)
        commandEncoder?.setTexture(antsTexture, index: TextureIndex.ants.rawValue)
        
        var width = resetAntsPipelineState.threadExecutionWidth
        var height = resetAntsPipelineState.maxTotalThreadsPerThreadgroup / width
        var threadsPerGroup = MTLSizeMake(width, height, 1)
        var threadsPerGrid = MTLSizeMake(Int(view.drawableSize.width), Int(view.drawableSize.height), 1)
        commandEncoder?.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerGroup)
        commandEncoder?.endEncoding()
        
        // decay pass
        commandEncoder = commandBuffer.makeComputeCommandEncoder()
        commandEncoder?.setComputePipelineState(decayPipelineState)
        commandEncoder?.setBytes(&trailVariables, length: MemoryLayout<TrailVariables>.stride, index: BufferIndex.trailVariables.rawValue)
        commandEncoder?.setTexture(currentTrailTexture, index: TextureIndex.currentTrails.rawValue)
        commandEncoder?.setTexture(previousTrailTexture, index: TextureIndex.previousTrails.rawValue)
        
        width = decayPipelineState.threadExecutionWidth
        height = decayPipelineState.maxTotalThreadsPerThreadgroup / width
        threadsPerGroup = MTLSizeMake(width, height, 1)
        var textureWidth = currentTrailTexture.width
        var textureHeight = currentTrailTexture.height
        threadsPerGrid = MTLSizeMake(textureWidth, textureHeight, 1)
        commandEncoder?.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerGroup)
        commandEncoder?.endEncoding()
        
        // update ants and trails pass
        commandEncoder = commandBuffer.makeComputeCommandEncoder()
        commandEncoder?.setComputePipelineState(updateAntsAndTrailPipelineState)
        commandEncoder?.setBuffer(emitter.particleBuffer, offset: 0, index: BufferIndex.particleBuffer.rawValue)
        commandEncoder?.setBytes(&antVariables, length: MemoryLayout<AntVariables>.stride, index: BufferIndex.antVariables.rawValue)
        commandEncoder?.setBytes(&currentTime, length: MemoryLayout<Float>.stride, index: BufferIndex.currentTime.rawValue)
        commandEncoder?.setTexture(currentTrailTexture, index: TextureIndex.currentTrails.rawValue)
        commandEncoder?.setTexture(previousTrailTexture, index: TextureIndex.previousTrails.rawValue)
        commandEncoder?.setTexture(antsTexture, index: TextureIndex.ants.rawValue)
        
        threadsPerGroup = MTLSizeMake(updateAntsAndTrailPipelineState.threadExecutionWidth, 1, 1)
        threadsPerGrid = MTLSizeMake(Int(antVariables.count), 1, 1)
        commandEncoder?.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerGroup)
        commandEncoder?.endEncoding()
                
        guard let drawable = view.currentDrawable else { return }
        
        // combine pass
        commandEncoder = commandBuffer.makeComputeCommandEncoder()
        commandEncoder?.setComputePipelineState(combinePipelineState)
        commandEncoder?.setTexture(drawable.texture, index: TextureIndex.drawable.rawValue)
        commandEncoder?.setTexture(currentTrailTexture, index: TextureIndex.currentTrails.rawValue)
        commandEncoder?.setTexture(antsTexture, index: TextureIndex.ants.rawValue)
        width = decayPipelineState.threadExecutionWidth
        height = decayPipelineState.maxTotalThreadsPerThreadgroup / width
        threadsPerGroup = MTLSizeMake(width, height, 1)
        textureWidth = drawable.texture.width
        textureHeight = drawable.texture.height
        threadsPerGrid = MTLSizeMake(textureWidth, textureHeight, 1)
        commandEncoder?.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerGroup)
                
        trailTextureIndex += 1
        commandEncoder?.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
