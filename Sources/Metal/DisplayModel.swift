//
//  DisplayModel.swift
//  KSPlayer-iOS
//
//  Created by kintan on 2020/1/11.
//

import Foundation
import Metal
import simd
#if canImport(UIKit)
import UIKit
import ModelIO
import MetalKit
#endif

extension DisplayEnum {
    private static var planeDisplay = PlaneMeshDisplayModel()
    private static var sphereDisplay = SphereMeshDisplayModel()
    private static var domeDisplay = DomeMeshDisplayModel()
    private static var cubeHDisplay = CubeHMeshDisplayModel()
    private static var cubeVDisplay = CubeVMeshDisplayModel()
    private static var fisheye180Display = Fisheye180MeshDisplayModel()
    private static var fisheye190Display = Fisheye190MeshDisplayModel()
    private static var fisheye200Display = Fisheye200MeshDisplayModel()

    func set(encoder: MTLRenderCommandEncoder, size: CGSize) {
        switch self {
        case .plane:
            DisplayEnum.planeDisplay.set(encoder: encoder, size: size)
        case .sphere:
            DisplayEnum.sphereDisplay.set(encoder: encoder, size: size)
        case .dome:
            DisplayEnum.domeDisplay.set(encoder: encoder, size: size)
        case .cubeH:
            DisplayEnum.cubeHDisplay.set(encoder: encoder, size: size)
        case .cubeV:
            DisplayEnum.cubeVDisplay.set(encoder: encoder, size: size)
        case .fisheye180:
            DisplayEnum.fisheye180Display.set(encoder: encoder, size: size)
        case .fisheye190:
            DisplayEnum.fisheye190Display.set(encoder: encoder, size: size)
        case .fisheye200:
            DisplayEnum.fisheye200Display.set(encoder: encoder, size: size)
        }
    }

    func pipeline(planeCount: Int, bitDepth: Int32) -> MTLRenderPipelineState {
        switch self {
        case .plane:
            return DisplayEnum.planeDisplay.pipeline(planeCount: planeCount, bitDepth: bitDepth)
        case .sphere:
            return DisplayEnum.sphereDisplay.pipeline(planeCount: planeCount, bitDepth: bitDepth)
        case .dome:
            return DisplayEnum.domeDisplay.pipeline(planeCount: planeCount, bitDepth: bitDepth)
        case .cubeH:
            return DisplayEnum.cubeHDisplay.pipeline(planeCount: planeCount, bitDepth: bitDepth)
        case .cubeV:
            return DisplayEnum.cubeVDisplay.pipeline(planeCount: planeCount, bitDepth: bitDepth)
        case .fisheye180:
            return DisplayEnum.fisheye180Display.pipeline(planeCount: planeCount, bitDepth: bitDepth)
        case .fisheye190:
            return DisplayEnum.fisheye190Display.pipeline(planeCount: planeCount, bitDepth: bitDepth)
        case .fisheye200:
            return DisplayEnum.fisheye200Display.pipeline(planeCount: planeCount, bitDepth: bitDepth)
        }
    }
}

private class PlaneDisplayModel {
    private lazy var yuv = MetalRender.makePipelineState(fragmentFunction: "displayYUVTexture")
    private lazy var yuvp010LE = MetalRender.makePipelineState(fragmentFunction: "displayYUVTexture", bitDepth: 10)
    private lazy var nv12 = MetalRender.makePipelineState(fragmentFunction: "displayNV12Texture")
    private lazy var p010LE = MetalRender.makePipelineState(fragmentFunction: "displayNV12Texture", bitDepth: 10)
    private lazy var bgra = MetalRender.makePipelineState(fragmentFunction: "displayTexture")
    let indexCount: Int
    let indexType = MTLIndexType.uint16
    let primitiveType = MTLPrimitiveType.triangleStrip
    let indexBuffer: MTLBuffer
    let posBuffer: MTLBuffer?
    let uvBuffer: MTLBuffer?
    fileprivate var modelViewMatrix = matrix_identity_float4x4

    fileprivate init() {
        let (indices, positions, uvs) = PlaneDisplayModel.genPlane()
        let device = MetalRender.device
        indexCount = indices.count
        indexBuffer = device.makeBuffer(bytes: indices, length: MemoryLayout<UInt16>.size * indexCount)!
        posBuffer = device.makeBuffer(bytes: positions, length: MemoryLayout<simd_float3>.size * positions.count)
        uvBuffer = device.makeBuffer(bytes: uvs, length: MemoryLayout<simd_float2>.size * uvs.count)
    }
    

    private static func genPlane() -> ([UInt16], [simd_float3], [simd_float2]) {
        let indices: [UInt16] = [0, 1, 2, 3]
        let positions: [simd_float3] = [
            [-2.0, -1.0, -5.0],
            [-2.0, 3.0, -5.0],
            [2.0, -1.0, -5.0],
            [2.0, 3.0, -5.0],
        ]
        let uvs: [simd_float2] = [
            [0.0, 1.0],
            [0.0, 0.0],
            [1.0, 1.0],
            [1.0, 0.0],
        ]
        return (indices, positions, uvs)
    }

    func set(encoder: MTLRenderCommandEncoder, size: CGSize) {
        encoder.setFrontFacing(.clockwise)
        encoder.setVertexBuffer(posBuffer, offset: 0, index: 0)
        encoder.setVertexBuffer(uvBuffer, offset: 0, index: 1)
        //encoder.drawIndexedPrimitives(type: primitiveType, indexCount: indexCount, indexType: indexType, indexBuffer: indexBuffer, indexBufferOffset: 0)
    }

    func pipeline(planeCount: Int, bitDepth: Int32) -> MTLRenderPipelineState {
        switch planeCount {
        case 3:
            if bitDepth == 10 {
                return yuvp010LE
            } else {
                return yuv
            }
        case 2:
            if bitDepth == 10 {
                return p010LE
            } else {
                return nv12
            }
        case 1:
            return bgra
        default:
            return bgra
        }
    }
}

private class SphereDisplayModel {
    private lazy var yuv = MetalRender.makePipelineState(fragmentFunction: "displayYUVTexture", isSphere: true)
    private lazy var yuvp010LE = MetalRender.makePipelineState(fragmentFunction: "displayYUVTexture", isSphere: true, bitDepth: 10)
    private lazy var nv12 = MetalRender.makePipelineState(fragmentFunction: "displayNV12Texture", isSphere: true)
    private lazy var p010LE = MetalRender.makePipelineState(fragmentFunction: "displayNV12Texture", isSphere: true, bitDepth: 10)
    private lazy var bgra = MetalRender.makePipelineState(fragmentFunction: "displayTexture", isSphere: true)
    private var fingerRotationX = Float(0)
    private var fingerRotationY = Float(0)
    fileprivate var modelViewMatrix = matrix_identity_float4x4
    let indexCount: Int
    let indexType = MTLIndexType.uint16
    let primitiveType = MTLPrimitiveType.triangle
    let indexBuffer: MTLBuffer
    let posBuffer: MTLBuffer?
    let uvBuffer: MTLBuffer?
    fileprivate init() {
        let (indices, positions, uvs) = SphereDisplayModel.genSphere()
        let device = MetalRender.device
        indexCount = indices.count
        indexBuffer = device.makeBuffer(bytes: indices, length: MemoryLayout<UInt16>.size * indexCount)!
        posBuffer = device.makeBuffer(bytes: positions, length: MemoryLayout<simd_float3>.size * positions.count)
        uvBuffer = device.makeBuffer(bytes: uvs, length: MemoryLayout<simd_float2>.size * uvs.count)
    }

    func set(encoder: MTLRenderCommandEncoder, size: CGSize) {
        encoder.setFrontFacing(.clockwise)
        encoder.setVertexBuffer(posBuffer, offset: 0, index: 0)
        encoder.setVertexBuffer(uvBuffer, offset: 0, index: 1)
    }

    func reset() {
        fingerRotationX = 0
        fingerRotationY = 0
        modelViewMatrix = matrix_identity_float4x4
    }

    private static func genSphere() -> ([UInt16], [simd_float3], [simd_float2]) {
        let slicesCount = UInt16(200)
        let parallelsCount = slicesCount / 2
        let indicesCount = Int(slicesCount) * Int(parallelsCount) * 6
        var indices = [UInt16](repeating: 0, count: indicesCount)
        var positions = [simd_float3]()
        var uvs = [simd_float2]()
        var runCount = 0
        let radius = Float(5.0)
        let step = (2.0 * Float.pi) / Float(slicesCount)
        var i = UInt16(0)
        while i <= parallelsCount {
            var j = UInt16(0)
            while j <= slicesCount {
                let vertex0 = radius * sinf(step * Float(i)) * cosf(step * Float(j))
                let vertex1 = radius * cosf(step * Float(i))
                let vertex2 = radius * sinf(step * Float(i)) * sinf(step * Float(j))
                //let vertex3 = Float(1.0)
                let vertex4 = Float(j) / Float(slicesCount)
                let vertex5 = Float(i) / Float(parallelsCount)
                //positions.append([vertex0, vertex1, vertex2, vertex3])
                positions.append([vertex0, vertex1, vertex2])
                uvs.append([vertex4, vertex5])
                if i < parallelsCount, j < slicesCount {
                    indices[runCount] = i * (slicesCount + 1) + j
                    runCount += 1
                    indices[runCount] = UInt16((i + 1) * (slicesCount + 1) + j)
                    runCount += 1
                    indices[runCount] = UInt16((i + 1) * (slicesCount + 1) + (j + 1))
                    runCount += 1
                    indices[runCount] = UInt16(i * (slicesCount + 1) + j)
                    runCount += 1
                    indices[runCount] = UInt16((i + 1) * (slicesCount + 1) + (j + 1))
                    runCount += 1
                    indices[runCount] = UInt16(i * (slicesCount + 1) + (j + 1))
                    runCount += 1
                }
                j += 1
            }
            i += 1
        }
        return (indices, positions, uvs)
    }

    func pipeline(planeCount: Int, bitDepth: Int32) -> MTLRenderPipelineState {
        switch planeCount {
        case 3:
            if bitDepth == 10 {
                return yuvp010LE
            } else {
                return yuv
            }
        case 2:
            if bitDepth == 10 {
                return p010LE
            } else {
                return nv12
            }
        case 1:
            return bgra
        default:
            return bgra
        }
    }
}

private class DomeDisplayModel {
    private lazy var yuv = MetalRender.makePipelineState(fragmentFunction: "displayYUVTexture", isSphere: true)
    private lazy var yuvp010LE = MetalRender.makePipelineState(fragmentFunction: "displayYUVTexture", isSphere: true, bitDepth: 10)
    private lazy var nv12 = MetalRender.makePipelineState(fragmentFunction: "displayNV12Texture", isSphere: true)
    private lazy var p010LE = MetalRender.makePipelineState(fragmentFunction: "displayNV12Texture", isSphere: true, bitDepth: 10)
    private lazy var bgra = MetalRender.makePipelineState(fragmentFunction: "displayTexture", isSphere: true)
    private var fingerRotationX = Float(0)
    private var fingerRotationY = Float(0)
    fileprivate var modelViewMatrix = matrix_identity_float4x4
    let indexCount: Int
    let indexType = MTLIndexType.uint16
    let primitiveType = MTLPrimitiveType.triangle
    let indexBuffer: MTLBuffer
    let posBuffer: MTLBuffer?
    let uvBuffer: MTLBuffer?
    fileprivate init() {
        let (indices, positions, uvs) = DomeDisplayModel.genDome()
        let device = MetalRender.device
        indexCount = indices.count
        indexBuffer = device.makeBuffer(bytes: indices, length: MemoryLayout<UInt16>.size * indexCount)!
        posBuffer = device.makeBuffer(bytes: positions, length: MemoryLayout<simd_float3>.size * positions.count)
        uvBuffer = device.makeBuffer(bytes: uvs, length: MemoryLayout<simd_float2>.size * uvs.count)
    }

    func set(encoder: MTLRenderCommandEncoder, size: CGSize) {
        encoder.setFrontFacing(.clockwise)
        encoder.setVertexBuffer(posBuffer, offset: 0, index: 0)
        encoder.setVertexBuffer(uvBuffer, offset: 0, index: 1)
    }

    func reset() {
        fingerRotationX = 0
        fingerRotationY = 0
        modelViewMatrix = matrix_identity_float4x4
    }

    private static func genDome() -> ([UInt16], [simd_float3], [simd_float2]) {
        let slicesCount = UInt16(200)
        let parallelsCount = slicesCount / 2
        let indicesCount = Int(slicesCount) * Int(parallelsCount) * 6 / 2
        var indices = [UInt16](repeating: 0, count: indicesCount)
        var positions = [simd_float3]()
        var uvs = [simd_float2]()
        var runCount = 0
        let radius = Float(5.0)
        let step = (2 * Float.pi) / Float(slicesCount)
        var i = UInt16(0)
        while i <= parallelsCount {
            var j = UInt16(0)
            while j <= slicesCount / 2 {
                let vertex0 = radius * sinf(step * Float(i)) * cosf(step * Float(j) + Float.pi)
                let vertex1 = radius * cosf(step * Float(i))
                let vertex2 = radius * sinf(step * Float(i)) * sinf(step * Float(j) + Float.pi)
                //let vertex3 = Float(1.0)
                let vertex4 = Float(j) / Float(slicesCount / 2)
                let vertex5 = Float(i) / Float(parallelsCount)
                //positions.append([vertex0, vertex1, vertex2, vertex3])
                positions.append([vertex0, vertex1, vertex2])
                uvs.append([vertex4, vertex5])
                if i < parallelsCount, j < slicesCount / 2 {
                    indices[runCount] = i * (slicesCount / 2 + 1) + j
                    runCount += 1
                    indices[runCount] = UInt16((i + 1) * (slicesCount / 2 + 1) + j)
                    runCount += 1
                    indices[runCount] = UInt16((i + 1) * (slicesCount / 2 + 1) + (j + 1))
                    runCount += 1
                    indices[runCount] = UInt16(i * (slicesCount / 2 + 1) + j)
                    runCount += 1
                    indices[runCount] = UInt16((i + 1) * (slicesCount / 2 + 1) + (j + 1))
                    runCount += 1
                    indices[runCount] = UInt16(i * (slicesCount / 2 + 1) + (j + 1))
                    runCount += 1
                }
                j += 1
            }
            i += 1
        }
        return (indices, positions, uvs)
    }

    func pipeline(planeCount: Int, bitDepth: Int32) -> MTLRenderPipelineState {
        switch planeCount {
        case 3:
            if bitDepth == 10 {
                return yuvp010LE
            } else {
                return yuv
            }
        case 2:
            if bitDepth == 10 {
                return p010LE
            } else {
                return nv12
            }
        case 1:
            return bgra
        default:
            return bgra
        }
    }
}

private class VRPlaneDisplayModel: PlaneDisplayModel {
    private let modelViewProjectionMatrix: simd_float4x4
    override required init() {
        let size = MoonOptions.sceneSize
        let aspect = Float(size.width / size.height)
        let projectionMatrix = simd_float4x4(perspective: Float.pi / 3, aspect: aspect, nearZ: 0.1, farZ: 400.0)
        let viewMatrix = simd_float4x4(lookAt: SIMD3<Float>.zero, center: [0, 0, -1000], up: [0, 1, 0])
        modelViewProjectionMatrix = projectionMatrix * viewMatrix
        super.init()
    }

    override func set(encoder: MTLRenderCommandEncoder, size: CGSize) {
        super.set(encoder: encoder, size: size)
        let aspect = Float(size.width) / Float(size.height)
        var matrix = simd_float4x4(scale: aspect, y: 1, z: 1)
        let matrixBuffer = MetalRender.device.makeBuffer(bytes: &matrix, length: MemoryLayout<simd_float4x4>.size)
        encoder.setVertexBuffer(matrixBuffer, offset: 0, index: 2)
        encoder.drawIndexedPrimitives(type: primitiveType, indexCount: indexCount, indexType: indexType, indexBuffer: indexBuffer, indexBufferOffset: 0)
    }
}

private class VRDisplayModel: SphereDisplayModel {
    private let modelViewProjectionMatrix: simd_float4x4
    override required init() {
        let size = MoonOptions.sceneSize
        let aspect = Float(size.width / size.height)
        let projectionMatrix = simd_float4x4(perspective: Float.pi / 3, aspect: aspect, nearZ: 0.1, farZ: 400.0)
        let viewMatrix = simd_float4x4(lookAt: SIMD3<Float>.zero, center: [0, 0, -1000], up: [0, 1, 0])
        modelViewProjectionMatrix = projectionMatrix * viewMatrix
        super.init()
    }

    override func set(encoder: MTLRenderCommandEncoder, size: CGSize) {
        super.set(encoder: encoder, size: size)
        var matrix = modelViewProjectionMatrix * modelViewMatrix
        let matrixBuffer = MetalRender.device.makeBuffer(bytes: &matrix, length: MemoryLayout<simd_float4x4>.size)
        encoder.setVertexBuffer(matrixBuffer, offset: 0, index: 2)
        encoder.drawIndexedPrimitives(type: primitiveType, indexCount: indexCount, indexType: indexType, indexBuffer: indexBuffer, indexBufferOffset: 0)
    }
}

private class VRDomeDisplayModel: DomeDisplayModel {
    private let modelViewProjectionMatrix: simd_float4x4
    override required init() {
        let size = MoonOptions.sceneSize
        let aspect = Float(size.width / size.height)
        let projectionMatrix = simd_float4x4(perspective: Float.pi / 3, aspect: aspect, nearZ: 0.1, farZ: 400.0)
        let viewMatrix = simd_float4x4(lookAt: SIMD3<Float>.zero, center: [0, 0, -1000], up: [0, 1, 0])
        modelViewProjectionMatrix = projectionMatrix * viewMatrix
        super.init()
    }

    override func set(encoder: MTLRenderCommandEncoder, size: CGSize) {
        super.set(encoder: encoder, size: size)
        var matrix = modelViewProjectionMatrix * modelViewMatrix
        let matrixBuffer = MetalRender.device.makeBuffer(bytes: &matrix, length: MemoryLayout<simd_float4x4>.size)
        encoder.setVertexBuffer(matrixBuffer, offset: 0, index: 2)
        encoder.drawIndexedPrimitives(type: primitiveType, indexCount: indexCount, indexType: indexType, indexBuffer: indexBuffer, indexBufferOffset: 0)
    }
}

private class MeshDisplayModel {
    private lazy var yuv = MetalRender.makePipelineState(fragmentFunction: "displayYUVTexture", isSphere: true)
    private lazy var yuvp010LE = MetalRender.makePipelineState(fragmentFunction: "displayYUVTexture", isSphere: true, bitDepth: 10)
    private lazy var nv12 = MetalRender.makePipelineState(fragmentFunction: "displayNV12Texture", isSphere: true)
    private lazy var p010LE = MetalRender.makePipelineState(fragmentFunction: "displayNV12Texture", isSphere: true, bitDepth: 10)
    private lazy var bgra = MetalRender.makePipelineState(fragmentFunction: "displayTexture", isSphere: true)
    let mesh: MTKMesh?
    fileprivate var modelViewMatrix = matrix_identity_float4x4
    
    fileprivate init() {
        mesh = nil
    }
    
    fileprivate init(modelName: String) {
        let mtlVertexDescriptor = MeshDisplayModel.buildMetalVertexDescriptor()
        let device = MetalRender.device
        mesh = MeshDisplayModel.buildMesh(device: device, mtlVertexDescriptor: mtlVertexDescriptor, modelName: modelName)
    }
    
    class func buildMesh(device: MTLDevice, mtlVertexDescriptor: MTLVertexDescriptor, modelName: String) -> MTKMesh? {
        let bundle = Bundle.module
        guard let modelURL = bundle.url(forResource: modelName, withExtension: nil) else {
            return nil
        }
        
        let mdlVertexDescriptor = MTKModelIOVertexDescriptorFromMetal(mtlVertexDescriptor)

        guard let attributes = mdlVertexDescriptor.attributes as? [MDLVertexAttribute] else {
            return nil
        }
        attributes[0].name = MDLVertexAttributePosition
        attributes[1].name = MDLVertexAttributeTextureCoordinate
        
        let allocator = MTKMeshBufferAllocator(device: device)
        
        let asset = MDLAsset(url: modelURL, vertexDescriptor: mdlVertexDescriptor, bufferAllocator: allocator)
        do {
            let (mdlMeshes, mtkMeshes) = try MTKMesh.newMeshes(asset: asset, device: device)
            guard let mesh = mdlMeshes.first else {
                return nil
            }
            let mtkMesh = try MTKMesh(mesh: mesh, device: device)
            return mtkMesh
        } catch {
            print(error)
            return nil
        }
    }
    
    func set(encoder: MTLRenderCommandEncoder, size: CGSize) {
        encoder.setFrontFacing(.clockwise)
        guard let mesh = mesh else {
            return
        }
        
        for (index, element) in mesh.vertexDescriptor.layouts.enumerated() {
            guard let layout = element as? MDLVertexBufferLayout else {
                return
            }
            
            if layout.stride != 0 {
                let buffer = mesh.vertexBuffers[index]
                encoder.setVertexBuffer(buffer.buffer, offset:buffer.offset, index: index)
            }
        }
        
        var matrix = matrix_identity_float4x4
        let matrixBuffer = MetalRender.device.makeBuffer(bytes: &matrix, length: MemoryLayout<simd_float4x4>.size)
        encoder.setVertexBuffer(matrixBuffer, offset: 0, index: 2)
        for submesh in mesh.submeshes {
            encoder.drawIndexedPrimitives(type: submesh.primitiveType,
                                                indexCount: submesh.indexCount,
                                                indexType: submesh.indexType,
                                                indexBuffer: submesh.indexBuffer.buffer,
                                                indexBufferOffset: submesh.indexBuffer.offset)
            
        }
    }
    
    func pipeline(planeCount: Int, bitDepth: Int32) -> MTLRenderPipelineState {
        switch planeCount {
        case 3:
            if bitDepth == 10 {
                return yuvp010LE
            } else {
                return yuv
            }
        case 2:
            if bitDepth == 10 {
                return p010LE
            } else {
                return nv12
            }
        case 1:
            return bgra
        default:
            return bgra
        }
    }
    
    class func buildMetalVertexDescriptor() -> MTLVertexDescriptor {
        // Create a Metal vertex descriptor specifying how vertices will by laid out for input into our render
        //   pipeline and how we'll layout our Model IO vertices

        let mtlVertexDescriptor = MTLVertexDescriptor()

        mtlVertexDescriptor.attributes[0].format = MTLVertexFormat.float3
        mtlVertexDescriptor.attributes[0].offset = 0
        mtlVertexDescriptor.attributes[0].bufferIndex = 0

        mtlVertexDescriptor.attributes[1].format = MTLVertexFormat.float2
        mtlVertexDescriptor.attributes[1].offset = 0
        mtlVertexDescriptor.attributes[1].bufferIndex = 1

        mtlVertexDescriptor.layouts[0].stride = 12
        mtlVertexDescriptor.layouts[0].stepRate = 1
        mtlVertexDescriptor.layouts[0].stepFunction = MTLVertexStepFunction.perVertex

        mtlVertexDescriptor.layouts[1].stride = 8
        mtlVertexDescriptor.layouts[1].stepRate = 1
        mtlVertexDescriptor.layouts[1].stepFunction = MTLVertexStepFunction.perVertex

        return mtlVertexDescriptor
    }
}

private class PlaneMeshDisplayModel {
    private lazy var yuv = MetalRender.makePipelineState(fragmentFunction: "displayYUVTexture")
    private lazy var yuvp010LE = MetalRender.makePipelineState(fragmentFunction: "displayYUVTexture", bitDepth: 10)
    private lazy var nv12 = MetalRender.makePipelineState(fragmentFunction: "displayNV12Texture")
    private lazy var p010LE = MetalRender.makePipelineState(fragmentFunction: "displayNV12Texture", bitDepth: 10)
    private lazy var bgra = MetalRender.makePipelineState(fragmentFunction: "displayTexture")
    let mesh: MTKMesh?
    fileprivate var modelViewMatrix = matrix_identity_float4x4
    
    required init() {
        let mtlVertexDescriptor = MeshDisplayModel.buildMetalVertexDescriptor()
        let device = MetalRender.device
        mesh = MeshDisplayModel.buildMesh(device: device, mtlVertexDescriptor: mtlVertexDescriptor, modelName: "Plane.obj")
    }
    
    func set(encoder: MTLRenderCommandEncoder, size: CGSize) {
        
        encoder.setFrontFacing(.clockwise)
        guard let mesh = mesh else {
            return
        }
        
        for (index, element) in mesh.vertexDescriptor.layouts.enumerated() {
            guard let layout = element as? MDLVertexBufferLayout else {
                return
            }
            
            if layout.stride != 0 {
                let buffer = mesh.vertexBuffers[index]
                encoder.setVertexBuffer(buffer.buffer, offset:buffer.offset, index: index)
            }
        }
        
        let aspect = Float(size.width) / Float(size.height)
        var matrix = simd_float4x4(scale: aspect, y: 1, z: 1)
        let matrixBuffer = MetalRender.device.makeBuffer(bytes: &matrix, length: MemoryLayout<simd_float4x4>.size)
        encoder.setVertexBuffer(matrixBuffer, offset: 0, index: 2)
        for submesh in mesh.submeshes {
            encoder.drawIndexedPrimitives(type: submesh.primitiveType,
                                                indexCount: submesh.indexCount,
                                                indexType: submesh.indexType,
                                                indexBuffer: submesh.indexBuffer.buffer,
                                                indexBufferOffset: submesh.indexBuffer.offset)
            
        }
    }
    
    func pipeline(planeCount: Int, bitDepth: Int32) -> MTLRenderPipelineState {
        switch planeCount {
        case 3:
            if bitDepth == 10 {
                return yuvp010LE
            } else {
                return yuv
            }
        case 2:
            if bitDepth == 10 {
                return p010LE
            } else {
                return nv12
            }
        case 1:
            return bgra
        default:
            return bgra
        }
    }
}

private class DomeMeshDisplayModel : MeshDisplayModel {
    override required init() {
        super.init(modelName: "Dome180.obj")
    }
}

private class SphereMeshDisplayModel : MeshDisplayModel {
    override required init() {
        super.init(modelName: "Sphere360.obj")
    }
}

private class CubeHMeshDisplayModel : MeshDisplayModel {
    override required init() {
        super.init(modelName: "CubeH.obj")
    }
}

private class CubeVMeshDisplayModel : MeshDisplayModel {
    override required init() {
        super.init(modelName: "CubeV.obj")
    }
}

private class Fisheye180MeshDisplayModel : MeshDisplayModel {
    override required init() {
        super.init(modelName: "Fisheye180.obj")
    }
}

private class Fisheye190MeshDisplayModel : MeshDisplayModel {
    override required init() {
        super.init(modelName: "Fisheye190.obj")
    }
}

private class Fisheye200MeshDisplayModel : MeshDisplayModel {
    override required init() {
        super.init(modelName: "Fisheye200.obj")
    }
}
