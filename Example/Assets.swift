//
//  Assets.swift
//  Euclid
//
//  Created by Andy Geers on 06/01/2020.
//  Copyright © 2020 Nick Lockwood. All rights reserved.
//

import Foundation
import SceneKit
import SceneKit.ModelIO
import Euclid

extension Mesh {
    
    init?(resourceName: String) {
        let mdlAsset = Mesh.loadResource(resourceName)
        self.init(mdlAsset: mdlAsset);
    }
    
    init?(mdlAsset: MDLAsset) {
        NSLog("Asset contains %d object(s)", mdlAsset.count);
        var object = mdlAsset.object(at: 0)
        if #available(iOS 11.0, *) {
            while ((!(object is MDLMesh)) && (object.children.count > 0)) {
                var wasMeshFound = false
                for child in object.children.objects {
                    if (child is MDLMesh) {
                        object = child
                        wasMeshFound = true
                        break
                    }
                }
                if (!wasMeshFound) {
                    object = object.children.objects.first!
                }
            }
        } else {
            // Fallback on earlier versions
        }
        if (object is MDLMesh) {
            let geometry = SCNGeometry(mdlMesh: object as! MDLMesh)
            self.init(scnGeometry: geometry, materialLookup: { (material: SCNMaterial) in
                return UIColor.blue //material.diffuse.contents as! Polygon.Material
            })
            return
        }
        return nil
    }
    
    static internal func loadResource(_ resourceName: String) -> MDLAsset {
        let fileURL = Bundle.main.url(forResource: resourceName, withExtension: "usdz")
        return MDLAsset(url: fileURL!)
    }
    
}
