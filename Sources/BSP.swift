//
//  BSP.swift
//  Euclid
//
//  Created by Nick Lockwood on 20/01/2020.
//  Copyright © 2020 Nick Lockwood. All rights reserved.
//

struct BSP {
    private var root: BSPNode?

    enum ClipRule {
        case greaterThan
        case greaterThanEqual
        case lessThan
        case lessThanEqual
    }

    init(_ mesh: Mesh) {
        self.root = BSPNode(mesh.polygons, isConvex: mesh.isConvex)
    }

    func clip(_ polygons: [Polygon], _ keeping: ClipRule) -> [Polygon] {
        var id = 0
        var polygons = polygons
        for (i, p) in polygons.enumerated() where p.id != 0 {
            polygons[i].id = 0
        }
        return root?.clip(polygons, keeping, &id) ?? polygons
    }
}

internal extension BSP {
    private init(root: BSPNode) {
        self.root = root
    }
    
    func duplicate() -> BSP {
        return self.translated(by: Vector.zero)
    }
    
    fileprivate struct BSPIterator: Sequence, IteratorProtocol {
        var stack: [BSPNode] = []
        var currentNode: BSPNode?
        var polygonIndex = 0
        
        init(node: BSPNode?) {
            currentNode = node
            pushChildren()
        }
        
        mutating func pushChildren() {
            guard let node = currentNode else { return }
            
            if (node.front != nil) {
                stack.append(node.front!)
            }
            if (node.back != nil) {
                stack.append(node.back!)
            }
        }
        
        mutating func next() -> Polygon? {
            guard let node = currentNode else { return nil }
            
            while (polygonIndex >= node.polygons.count) {
                if (stack.isEmpty) {
                    return nil
                } else {
                    currentNode = stack.popLast()!
                    polygonIndex = 0
                    pushChildren()
                }
            }
            
            let polygon = node.polygons[polygonIndex]
            polygonIndex += 1
            return polygon
        }
        
        func makeIterator() -> BSPIterator {
            return self
        }
    }
    
    fileprivate var polygons: BSPIterator {
        return BSPIterator(node: root)
    }
    
    func merged(with bsp: BSP) -> BSP {
        guard root != nil else {
            return bsp.duplicate()
        }
        
        let result = self.duplicate()
        
        //for polygon in bsp.polygons {
            result.root!.insert(Array(bsp.polygons))
        //}
        
        return result
    }
    
    func translated(by translation: Vector) -> BSP {
        guard root != nil else { return self }
                
        return BSP(root: root!.translated(by: translation))
    }
    
    func scaled(by v: Vector) -> BSP {
        guard root != nil else { return self }
                
        return BSP(root: root!.scaled(by: v))
    }
    
    func rotated(by m: Rotation) -> BSP {
        guard root != nil else { return self }
                
        return BSP(root: root!.rotated(by: m))
    }
}

private struct DeterministicRNG: RandomNumberGenerator {
    private let modulus = 233_280
    private let multiplier = 9301
    private let increment = 49297

    private var seed = 0

    mutating func next() -> UInt64 {
        seed = (seed * multiplier + increment) % modulus
        return UInt64(seed)
    }
}

private class BSPNode {
    private weak var parent: BSPNode?
    fileprivate var front: BSPNode?
    fileprivate var back: BSPNode?
    fileprivate var polygons = [Polygon]()
    private let plane: Plane

    public init?(_ polygons: [Polygon], isConvex: Bool) {
        guard !polygons.isEmpty else {
            return nil
        }
        guard isConvex else {
            self.plane = polygons[0].plane
            insert(polygons)
            return
        }

        // Randomly shuffle polygons to reduce average number of splits
        var rng = DeterministicRNG()
        var polygons = polygons.shuffled(using: &rng)

        // Sort polygons by plane
        let count = polygons.count
        for i in 0 ..< count - 2 {
            let p = polygons[i]
            let plane = p.plane
            var k = i + 1
            for j in k ..< count where k < j && polygons[j].plane.isEqual(to: plane) {
                polygons.swapAt(j, k)
                k += 1
            }
        }

        // Use fast bsp construction
        self.plane = polygons[0].plane
        var parent = self
        parent.polygons = [polygons[0]]
        for polygon in polygons.dropFirst() {
            if polygon.plane.isEqual(to: parent.plane) {
                parent.polygons.append(polygon)
                continue
            }
            let node = BSPNode(plane: polygon.plane, parent: parent)
            node.polygons = [polygon]
            parent.back = node
            parent = node
        }
    }

    private init(plane: Plane, parent: BSPNode?) {
        self.parent = parent
        self.plane = plane
    }
    
    func translated(by translation: Vector, parent: BSPNode? = nil) -> BSPNode {
        let translated = BSPNode(plane: self.plane.translated(by: translation), parent: parent)
        translated.polygons.append(contentsOf: polygons.map { $0.translated(by: translation) })
        if (front != nil) {
            translated.front = front!.translated(by: translation, parent: translated)
        }
        if (back != nil) {
            translated.back = back!.translated(by: translation, parent: translated)
        }
        return translated
    }
    
    func scaled(by v: Vector, parent: BSPNode? = nil) -> BSPNode {
        let scaled = BSPNode(plane: self.plane.scaled(by: v), parent: parent)
        scaled.polygons.append(contentsOf: polygons.map { $0.scaled(by: v) })
        if (front != nil) {
            scaled.front = front!.scaled(by: v, parent: scaled)
        }
        if (back != nil) {
            scaled.back = back!.scaled(by: v, parent: scaled)
        }
        return scaled
    }
    
    func rotated(by m: Rotation, parent: BSPNode? = nil) -> BSPNode {
        let rotated = BSPNode(plane: self.plane.rotated(by: m), parent: parent)
        rotated.polygons.append(contentsOf: polygons.map { $0.rotated(by: m) })
        if (front != nil) {
            rotated.front = front!.rotated(by: m, parent: rotated)
        }
        if (back != nil) {
            rotated.back = back!.rotated(by: m, parent: rotated)
        }
        return rotated
    }        

    public func clip(
        _ polygons: [Polygon],
        _ keeping: BSP.ClipRule,
        _ id: inout Int
    ) -> [Polygon] {
        var polygons = polygons
        var node = self
        var total = [Polygon]()
        func addPolygons(_ polygons: [Polygon]) {
            for a in polygons {
                guard a.id != 0 else {
                    total.append(a)
                    continue
                }
                var a = a
                for i in total.indices.reversed() {
                    let b = total[i]
                    if a.id == b.id, let c = a.join(unchecked: b, ensureConvex: true) {
                        a = c
                        total.remove(at: i)
                    }
                }
                total.append(a)
            }
        }
        let keepFront = [.greaterThan, .greaterThanEqual].contains(keeping)
        while !polygons.isEmpty {
            var coplanar = [Polygon](), front = [Polygon](), back = [Polygon]()
            for polygon in polygons {
                polygon.split(along: node.plane, &coplanar, &front, &back, &id)
            }
            for polygon in coplanar {
                switch keeping {
                case .greaterThan, .lessThanEqual:
                    polygon.clip(to: node.polygons, &back, &front, &id)
                case .greaterThanEqual, .lessThan:
                    if node.plane.normal.dot(polygon.plane.normal) > 0 {
                        front.append(polygon)
                    } else {
                        polygon.clip(to: node.polygons, &back, &front, &id)
                    }
                }
            }
            if front.count > back.count {
                addPolygons(node.back?.clip(back, keeping, &id) ?? (keepFront ? [] : back))
                if node.front == nil {
                    addPolygons(keepFront ? front : [])
                    return total
                }
                polygons = front
                node = node.front!
            } else {
                addPolygons(node.front?.clip(front, keeping, &id) ?? (keepFront ? front : []))
                if node.back == nil {
                    addPolygons(keepFront ? [] : back)
                    return total
                }
                polygons = back
                node = node.back!
            }
        }
        return total
    }

    fileprivate func insert(_ polygons: [Polygon]) {
        var polygons = polygons
        var node = self
        while !polygons.isEmpty {
            var front = [Polygon](), back = [Polygon]()
            for polygon in polygons {
                switch polygon.compare(with: node.plane) {
                case .coplanar:
                    if node.plane.normal.dot(polygon.plane.normal) > 0 {
                        node.polygons.append(polygon)
                    } else {
                        back.append(polygon)
                    }
                case .front:
                    front.append(polygon)
                case .back:
                    back.append(polygon)
                case .spanning:
                    var id = 0
                    polygon.split(spanning: node.plane, &front, &back, &id)
                }
            }

            node.front = node.front ?? front.first.map {
                BSPNode(plane: $0.plane, parent: node)
            }
            node.back = node.back ?? back.first.map {
                BSPNode(plane: $0.plane, parent: node)
            }

            if front.count > back.count {
                node.back?.insert(back)
                polygons = front
                node = node.front!
            } else {
                node.front?.insert(front)
                polygons = back
                node = node.back ?? node
            }
        }
    }
}
