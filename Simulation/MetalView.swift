import MetalKit

class MetalView: MTKView {
    var renderer: Renderer!
    
    init() {
        super.init(frame: .zero, device: MTLCreateSystemDefaultDevice())
        // Make sure we are on a device that can run metal!
        guard let defaultDevice = device else {
            fatalError("Device loading error")
        }
        colorPixelFormat = .bgra8Unorm
        framebufferOnly = false
        // Our clear color, can be set to any color
        clearColor = MTLClearColor(red: 0.1, green: 0.57, blue: 0.25, alpha: 1)
        createRenderer(device: defaultDevice)
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func createRenderer(device: MTLDevice){
        renderer = Renderer(mtkView: self, device: device)
        delegate = renderer
    }
}
