import Metal
import UIKit
import SwiftUI

private let shaderSource = """
#include <metal_stdlib>
using namespace metal;

struct Uniforms {
    float4 color;
};

vertex float4 hdr_vertex(uint vid [[vertex_id]]) {
    float2 pos[3] = { float2(-1, -3), float2(-1, 1), float2(3, 1) };
    return float4(pos[vid], 0, 1);
}

fragment float4 hdr_fragment(constant Uniforms& u [[buffer(0)]]) {
    return u.color;
}
"""

struct HDRMetalView: UIViewRepresentable {
    let red: Double
    let green: Double
    let blue: Double

    init(red: Double = 1.1, green: Double = 1.1, blue: Double = 1.1) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    func makeUIView(context: Context) -> HDRView {
        let view = HDRView()
        view.color = SIMD4<Double>(red, green, blue, 1.0)
        return view
    }

    func updateUIView(_ uiView: HDRView, context: Context) {
        uiView.color = SIMD4<Double>(red, green, blue, 1.0)
        uiView.render()
    }
}

final class HDRView: UIView {
    private var _metalLayer: CAMetalLayer?
    private var metalLayer: CAMetalLayer {
        if let existing = _metalLayer { return existing }
        let ml = CAMetalLayer()
        ml.device = device
        ml.pixelFormat = .rgba16Float
        ml.wantsExtendedDynamicRangeContent = true
        ml.isOpaque = true
        ml.frame = bounds
        _metalLayer = ml
        layer.addSublayer(ml)
        return ml
    }
    private let device = MTLCreateSystemDefaultDevice()
    private var commandQueue: MTLCommandQueue?
    private var renderPipeline: MTLRenderPipelineState?
    var color: SIMD4<Double> = SIMD4<Double>(1.1, 1.1, 1.1, 1.0)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        guard let device else { return }
        commandQueue = device.makeCommandQueue()

        guard let library = try? device.makeLibrary(source: shaderSource, options: nil),
              let vertex = library.makeFunction(name: "hdr_vertex"),
              let fragment = library.makeFunction(name: "hdr_fragment") else {
            print("[HDR] Metal shader compilation failed")
            return
        }

        let desc = MTLRenderPipelineDescriptor()
        desc.vertexFunction = vertex
        desc.fragmentFunction = fragment
        desc.colorAttachments[0].pixelFormat = .rgba16Float
        renderPipeline = try? device.makeRenderPipelineState(descriptor: desc)
        if renderPipeline == nil {
            print("[HDR] Pipeline creation failed")
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        metalLayer.frame = bounds
        if bounds.width > 0, bounds.height > 0 {
            render()
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            render()
        }
    }

    fileprivate func render() {
        guard bounds.width > 0, bounds.height > 0,
              let device,
              let drawable = metalLayer.nextDrawable(),
              let queue = commandQueue,
              let pipeline = renderPipeline else { return }

        let c = color
        var uniforms = SIMD4<Float>(Float(c.x), Float(c.y), Float(c.z), Float(c.w))

        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = drawable.texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].clearColor = MTLClearColor(red: c.x, green: c.y, blue: c.z, alpha: c.w)
        pass.colorAttachments[0].storeAction = .store

        guard let buf = queue.makeCommandBuffer(),
              let enc = buf.makeRenderCommandEncoder(descriptor: pass) else { return }
        enc.setRenderPipelineState(pipeline)
        enc.setFragmentBytes(&uniforms, length: MemoryLayout<SIMD4<Float>>.size, index: 0)
        enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        enc.endEncoding()
        buf.present(drawable)
        buf.commit()
    }
}
