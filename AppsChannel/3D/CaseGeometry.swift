import SceneKit
import AppKit

public final class CaseGeometry {
    public static func makeCardNode(image: NSImage, title: String, width: CGFloat = 2.4, height: CGFloat = 3.2, length: CGFloat = 0.08) -> SCNNode {
        let box = SCNBox(width: width, height: height, length: length, chamferRadius: 0.12)
        box.chamferSegmentCount = 6

        // Front material (Cover Artwork)
        let frontMaterial = SCNMaterial()
        frontMaterial.diffuse.contents = image
        frontMaterial.roughness.contents = 0.15
        frontMaterial.metalness.contents = 0.05
        frontMaterial.lightingModel = .physicallyBased

        // Glossy liquid glass body material
        let glassBodyMaterial = SCNMaterial()
        glassBodyMaterial.diffuse.contents = NSColor(white: 0.95, alpha: 0.9)
        glassBodyMaterial.roughness.contents = 0.08
        glassBodyMaterial.metalness.contents = 0.1
        glassBodyMaterial.specular.contents = NSColor.white
        glassBodyMaterial.lightingModel = .physicallyBased

        // Bevel edge material
        let edgeMaterial = SCNMaterial()
        edgeMaterial.diffuse.contents = NSColor(white: 1.0, alpha: 0.95)
        edgeMaterial.roughness.contents = 0.05
        edgeMaterial.specular.contents = NSColor.white

        box.materials = [
            frontMaterial,       // Front
            glassBodyMaterial,   // Right
            glassBodyMaterial,   // Back
            glassBodyMaterial,   // Left
            edgeMaterial,        // Top
            edgeMaterial         // Bottom
        ]

        let node = SCNNode(geometry: box)
        node.castsShadow = true
        return node
    }
}
