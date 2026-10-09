import SceneKit
import AppKit

public final class CoverFlowScene {
    public let scene: SCNScene
    public let cameraNode: SCNNode
    public let rootCardNode: SCNNode

    public init() {
        scene = SCNScene()
        rootCardNode = SCNNode()
        scene.rootNode.addChildNode(rootCardNode)

        // Camera setup
        cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.zNear = 0.1
        cameraNode.camera?.zFar = 100.0
        cameraNode.camera?.fieldOfView = 50.0
        cameraNode.position = SCNVector3(x: 0, y: 0.2, z: 6.5)
        scene.rootNode.addChildNode(cameraNode)

        // Reflection floor
        let floor = SCNFloor()
        floor.reflectivity = 0.25
        floor.reflectionFalloffEnd = 4.0
        let floorMaterial = SCNMaterial()
        floorMaterial.diffuse.contents = NSColor(calibratedRed: 0.05, green: 0.08, blue: 0.12, alpha: 0.0)
        floor.materials = [floorMaterial]
        let floorNode = SCNNode(geometry: floor)
        floorNode.position = SCNVector3(x: 0, y: -1.7, z: 0)
        scene.rootNode.addChildNode(floorNode)

        // Ambient lighting
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.color = NSColor(white: 0.35, alpha: 1.0)
        let ambientNode = SCNNode()
        ambientNode.light = ambientLight
        scene.rootNode.addChildNode(ambientNode)

        // Key spotlight with subtle blue tint
        let keyLight = SCNLight()
        keyLight.type = .directional
        keyLight.color = NSColor(calibratedRed: 0.85, green: 0.92, blue: 1.0, alpha: 1.0)
        keyLight.castsShadow = true
        let keyNode = SCNNode()
        keyNode.light = keyLight
        keyNode.position = SCNVector3(x: 2.0, y: 5.0, z: 5.0)
        keyNode.look(at: SCNVector3(x: 0, y: 0, z: 0))
        scene.rootNode.addChildNode(keyNode)
    }
}
