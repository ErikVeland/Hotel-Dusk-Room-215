import SwiftUI
import SceneKit

#if os(macOS)
import AppKit
public typealias PlatformColor = NSColor
#else
import UIKit
public typealias PlatformColor = UIColor
#endif

/// Generates and manages the 3D SceneKit environment for Hotel Dusk exploration
public final class HotelScene3DManager: ObservableObject, @unchecked Sendable {
    public let scene: SCNScene
    public let cameraNode: SCNNode
    private static let corridorNearZ: SCNScalar = 2
    private static let corridorFarZ: SCNScalar = -14
    private static let cameraClearance: SCNScalar = 0.5

    public init() {
        let scn = SCNScene()
        // SceneView can otherwise expose its white backing beyond the geometry.
        scn.background.contents = PlatformColor(red: 0.035, green: 0.03, blue: 0.025, alpha: 1)

        // 1. Camera Node
        let cam = SCNCamera()
        cam.zNear = 0.1
        cam.zFar = 100.0
        cam.fieldOfView = 65

        let camNode = SCNNode()
        camNode.camera = cam
        camNode.position = SCNVector3(x: 0, y: 1.5, z: 1.5)
        scn.rootNode.addChildNode(camNode)
        self.cameraNode = camNode
        self.scene = scn

        setupEnvironment(scn)
    }

    private func setupEnvironment(_ scn: SCNScene) {
        // Ambient Light
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.color = PlatformColor(white: 0.25, alpha: 1.0)
        let ambientNode = SCNNode()
        ambientNode.light = ambientLight
        scn.rootNode.addChildNode(ambientNode)

        // Point Light (Vintage hotel sconce)
        let pointLight = SCNLight()
        pointLight.type = .omni
        pointLight.color = PlatformColor(red: 1.0, green: 0.85, blue: 0.65, alpha: 1.0)
        pointLight.intensity = 800
        let lightNode = SCNNode()
        lightNode.light = pointLight
        lightNode.position = SCNVector3(x: 0, y: 2.4, z: -2.0)
        scn.rootNode.addChildNode(lightNode)

        // Corridor Floor (Wood + Carpet runner)
        let floorGeo = SCNFloor()
        floorGeo.reflectivity = 0.05
        let floorMat = SCNMaterial()
        floorMat.diffuse.contents = PlatformColor(red: 0.18, green: 0.12, blue: 0.08, alpha: 1.0)
        floorGeo.materials = [floorMat]
        let floorNode = SCNNode(geometry: floorGeo)
        scn.rootNode.addChildNode(floorNode)

        // Carpet Runner (Hotel Dusk red carpet)
        let carpetGeo = SCNBox(width: 1.4, height: 0.01, length: 16.0, chamferRadius: 0)
        let carpetMat = SCNMaterial()
        carpetMat.diffuse.contents = PlatformColor(red: 0.52, green: 0.14, blue: 0.12, alpha: 1.0)
        carpetGeo.materials = [carpetMat]
        let carpetNode = SCNNode(geometry: carpetGeo)
        carpetNode.position = SCNVector3(x: 0, y: 0.005, z: -6.0)
        scn.rootNode.addChildNode(carpetNode)

        // Ceiling
        let ceilingGeo = SCNBox(width: 4.0, height: 0.05, length: 16.0, chamferRadius: 0)
        let ceilingMat = SCNMaterial()
        ceilingMat.diffuse.contents = PlatformColor(red: 0.15, green: 0.14, blue: 0.12, alpha: 1.0)
        ceilingGeo.materials = [ceilingMat]
        let ceilingNode = SCNNode(geometry: ceilingGeo)
        ceilingNode.position = SCNVector3(x: 0, y: 2.8, z: -6.0)
        scn.rootNode.addChildNode(ceilingNode)

        // Left Wall
        let leftWallGeo = SCNBox(width: 0.1, height: 2.8, length: 16.0, chamferRadius: 0)
        let wallMat = SCNMaterial()
        wallMat.diffuse.contents = PlatformColor(red: 0.22, green: 0.20, blue: 0.18, alpha: 1.0)
        leftWallGeo.materials = [wallMat]
        let leftWallNode = SCNNode(geometry: leftWallGeo)
        leftWallNode.position = SCNVector3(x: -1.8, y: 1.4, z: -6.0)
        scn.rootNode.addChildNode(leftWallNode)

        // Right Wall
        let rightWallNode = SCNNode(geometry: leftWallGeo)
        rightWallNode.position = SCNVector3(x: 1.8, y: 1.4, z: -6.0)
        scn.rootNode.addChildNode(rightWallNode)

        // Close both ends of this provisional corridor. Empty openings exposed
        // the render surface as bright rectangles when walking or turning.
        for (name, z) in [("corridor-near-wall", Self.corridorNearZ),
                          ("corridor-far-wall", Self.corridorFarZ)] {
            let endWall = SCNBox(width: 3.7, height: 2.8, length: 0.1, chamferRadius: 0)
            endWall.materials = [wallMat]
            let endNode = SCNNode(geometry: endWall)
            endNode.name = name
            endNode.position = SCNVector3(x: 0, y: 1.4, z: z)
            scn.rootNode.addChildNode(endNode)
        }

        // Add Doors along hallway: Room 215, 213, 211
        addDoor(scn, position: SCNVector3(x: -1.74, y: 1.0, z: 0.0), roomLabel: "215", isLeftWall: true)
        addDoor(scn, position: SCNVector3(x: 1.74, y: 1.0, z: -3.0), roomLabel: "214", isLeftWall: false)
        addDoor(scn, position: SCNVector3(x: -1.74, y: 1.0, z: -6.0), roomLabel: "213", isLeftWall: true)
    }

    private func addDoor(_ scn: SCNScene, position: SCNVector3, roomLabel: String, isLeftWall: Bool) {
        let doorGeo = SCNBox(width: 0.05, height: 2.0, length: 1.0, chamferRadius: 0.02)
        let doorMat = SCNMaterial()
        doorMat.diffuse.contents = PlatformColor(red: 0.28, green: 0.18, blue: 0.12, alpha: 1.0)
        doorGeo.materials = [doorMat]
        let doorNode = SCNNode(geometry: doorGeo)
        doorNode.position = position
        scn.rootNode.addChildNode(doorNode)

        // Brass Plate Sign
        let textGeo = SCNText(string: roomLabel, extrusionDepth: 0.02)
        #if os(macOS)
        textGeo.font = NSFont(name: "Baskerville-SemiBold", size: 0.18) ?? NSFont.systemFont(ofSize: 0.18)
        #else
        textGeo.font = UIFont(name: "Baskerville-SemiBold", size: 0.18) ?? UIFont.systemFont(ofSize: 0.18)
        #endif
        let textMat = SCNMaterial()
        textMat.diffuse.contents = PlatformColor(red: 0.9, green: 0.8, blue: 0.3, alpha: 1.0)
        textGeo.materials = [textMat]
        let textNode = SCNNode(geometry: textGeo)
        textNode.scale = SCNVector3(0.5, 0.5, 0.5)

        if isLeftWall {
            textNode.position = SCNVector3(position.x + 0.04, position.y + 0.4, position.z + 0.2)
            textNode.eulerAngles = SCNVector3(0, CGFloat.pi / 2, 0)
        } else {
            textNode.position = SCNVector3(position.x - 0.04, position.y + 0.4, position.z - 0.2)
            textNode.eulerAngles = SCNVector3(0, -CGFloat.pi / 2, 0)
        }
        scn.rootNode.addChildNode(textNode)
    }

    public func panCamera(deltaYaw: CGFloat, deltaZ: CGFloat) {
        // SCNVector3 components are CGFloat on macOS but Float on iOS.
        let yaw = SCNScalar(deltaYaw)
        let dz = SCNScalar(deltaZ)
        cameraNode.eulerAngles.y += yaw
        let forwardZ = dz * cos(cameraNode.eulerAngles.y)
        let forwardX = dz * sin(cameraNode.eulerAngles.y)

        cameraNode.position.z = max(Self.corridorFarZ + Self.cameraClearance,
                                    min(Self.corridorNearZ - Self.cameraClearance,
                                        cameraNode.position.z + forwardZ))
        cameraNode.position.x = max(-1.2, min(1.2, cameraNode.position.x - forwardX))
    }

    #if os(macOS)
    typealias SCNScalar = CGFloat
    #else
    typealias SCNScalar = Float
    #endif

    public func resetToRoom215() {
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.8
        cameraNode.position = SCNVector3(x: 0, y: 1.5, z: 1.5)
        cameraNode.eulerAngles = SCNVector3(0, 0, 0)
        SCNTransaction.commit()
    }
}
