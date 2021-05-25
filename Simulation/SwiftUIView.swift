import SwiftUI

public struct SwiftUIView: NSViewRepresentable {
    public var wrappedView: NSView
    
    private var handleUpdateNSView: ((NSView, Context) -> Void)?
    private var handleMakeNSView: ((Context) -> NSView)?
    
    public init(closure: () -> NSView) {
        wrappedView = closure()
    }
    
    public func makeNSView(context: Context) -> NSView {
        guard let handler = handleMakeNSView else {
            return wrappedView
        }
        
        return handler(context)
    }
    
    public func updateNSView(_ nsView: NSView, context: Context) {
        handleUpdateNSView?(nsView, context)
    }
}

public extension SwiftUIView {
    mutating func setMakeNSView(handler: @escaping (Context) -> NSView) -> Self {
        handleMakeNSView = handler
        
        return self
    }
    
    mutating func setUpdateNSView(handler: @escaping (NSView, Context) -> Void) -> Self {
        handleUpdateNSView = handler
        
        return self
    }
}
