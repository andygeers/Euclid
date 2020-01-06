//
//  SceneViewController.swift
//  Example
//
//  Created by Nick Lockwood on 11/12/2018.
//  Copyright © 2018 Nick Lockwood. All rights reserved.
//

import Euclid
import SceneKit
import UIKit

class SceneViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        // create a new scene
        let scene = SCNScene()

        // create and add a camera to the scene
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        scene.rootNode.addChildNode(cameraNode)

        // place the camera
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 3)

        // create some geometry using Euclid
        let start = CFAbsoluteTimeGetCurrent()
        
        var texture = Mesh(resourceName: "01_bricks")!.scaled(by: 0.01)
        let textureBounds = texture.bounds
        texture = texture.translated(by: -textureBounds.min)
        
        var wall = texture.translated(by: Vector(-0.50,0.00,0.40))
        wall = wall.union(texture.translated(by: Vector(0.46,0.00,0.40)))
        
        let hole = createHole()
        let mesh = wall.intersect(hole)
            
        print("Time:", CFAbsoluteTimeGetCurrent() - start)
        print("Polys:", mesh.polygons.count)

        // create SCNNode
        let geometry = SCNGeometry(mesh) {
            let material = SCNMaterial()
            material.diffuse.contents = $0 as? UIColor
            return material
        }
        let node = SCNNode(geometry: geometry)
        scene.rootNode.addChildNode(node)

        // configure the SCNView
        let scnView = view as! SCNView
        scnView.scene = scene
        scnView.autoenablesDefaultLighting = true
        scnView.allowsCameraControl = true
        scnView.showsStatistics = true
        scnView.backgroundColor = .white
    }
    
    private func createHole() -> Mesh {
        let points =
            [
                Vector( 0.4, 0.5,0.40),
                Vector(-0.4, 0.5,0.40),
                Vector(-0.4, 0.0,0.40),
                Vector( 0.4, 0.0,0.40)
            ]
        
        // Extrude that outline
        let outlinePath = Path(points.map { PathPoint($0, isCurved: false) })
        let mesh = Mesh.extrude(outlinePath.closed(), depth: 70.0, material: UIColor.blue)
        
        return mesh
    }

    override var shouldAutorotate: Bool {
        return true
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}
