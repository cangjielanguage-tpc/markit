package mermaid4cj.layout.dagre

import std.collection.ArrayList
import std.math.sqrt

public func outsideNode(node: DagreNode, point: DagrePoint): Bool {
    let x = node.x ?? 0.0
    let y = node.y ?? 0.0
    let dx = absFloat(point.x - x)
    let dy = absFloat(point.y - y)
    let w = (node.width ?? 0.0) / 2.0
    let h = (node.height ?? 0.0) / 2.0
    return dx >= w || dy >= h
}

public func intersection(node: DagreNode, outsidePoint: DagrePoint, insidePoint: DagrePoint): DagrePoint {
    let x = node.x ?? 0.0
    let y = node.y ?? 0.0
    let dx = absFloat(x - insidePoint.x)
    let w = (node.width ?? 0.0) / 2.0
    let h = (node.height ?? 0.0) / 2.0
    let q = absFloat(outsidePoint.y - insidePoint.y)
    let r = absFloat(outsidePoint.x - insidePoint.x)

    if (absFloat(y - outsidePoint.y) * w > absFloat(x - outsidePoint.x) * h) {
        let localQ = if (insidePoint.y < outsidePoint.y) { outsidePoint.y - h - y } else { y - h - outsidePoint.y }
        var localR = (r * localQ) / q
        var resultX = if (insidePoint.x < outsidePoint.x) { insidePoint.x + localR } else { insidePoint.x - r + localR }
        var resultY = if (insidePoint.y < outsidePoint.y) { insidePoint.y + q - localQ } else { insidePoint.y - q + localQ }
        if (localR == 0.0) {
            resultX = outsidePoint.x
            resultY = outsidePoint.y
        }
        if (r == 0.0) {
            resultX = outsidePoint.x
        }
        if (q == 0.0) {
            resultY = outsidePoint.y
        }
        return DagrePoint(resultX, resultY)
    }

    let localR = if (insidePoint.x < outsidePoint.x) { outsidePoint.x - w - x } else { x - w - outsidePoint.x }
    let localQ = (q * localR) / r
    var resultX = if (insidePoint.x < outsidePoint.x) { insidePoint.x + r - localR } else { insidePoint.x - r + localR }
    var resultY = if (insidePoint.y < outsidePoint.y) { insidePoint.y + localQ } else { insidePoint.y - localQ }
    if (localR == 0.0) {
        resultX = outsidePoint.x
        resultY = outsidePoint.y
    }
    if (r == 0.0) {
        resultX = outsidePoint.x
    }
    if (q == 0.0) {
        resultY = outsidePoint.y
    }
    return DagrePoint(resultX, resultY)
}

public func intersectRect(node: DagreNode, point: DagrePoint): DagrePoint {
    let x = node.x ?? 0.0
    let y = node.y ?? 0.0
    let dx = point.x - x
    let dy = point.y - y
    var w = (node.width ?? 0.0) / 2.0
    var h = (node.height ?? 0.0) / 2.0
    var sx = 0.0
    var sy = 0.0

    if (absFloat(dy) * w > absFloat(dx) * h) {
        if (dy < 0.0) {
            h = -h
        }
        sx = if (dy == 0.0) { 0.0 } else { (h * dx) / dy }
        sy = h
    } else {
        if (dx < 0.0) {
            w = -w
        }
        sx = w
        sy = if (dx == 0.0) { 0.0 } else { (w * dy) / dx }
    }

    return DagrePoint(x + sx, y + sy)
}

public func intersectEllipse(node: DagreNode, rx: Float64, ry: Float64, point: DagrePoint): DagrePoint {
    let cx = node.x ?? 0.0
    let cy = node.y ?? 0.0
    let px = cx - point.x
    let py = cy - point.y
    let det = sqrt(rx * rx * py * py + ry * ry * px * px)
    if (det == 0.0) {
        return DagrePoint(cx, cy)
    }

    var dx = absFloat((rx * ry * px) / det)
    if (point.x < cx) {
        dx = -dx
    }
    var dy = absFloat((rx * ry * py) / det)
    if (point.y < cy) {
        dy = -dy
    }
    return DagrePoint(cx + dx, cy + dy)
}

public func intersectCylinder(node: DagreNode, point: DagrePoint): DagrePoint {
    let pos = intersectRect(node, point)
    let width = node.width ?? 0.0
    let height = node.height ?? 0.0
    let rx = width / 2.0
    let ry = rx / (2.5 + width / 50.0)
    let nodeX = node.x ?? 0.0
    let nodeY = node.y ?? 0.0
    let x = pos.x - nodeX

    if (rx != 0.0 && (absFloat(x) < width / 2.0 || (absFloat(x) == width / 2.0 && absFloat(pos.y - nodeY) > height / 2.0 - ry))) {
        var y = ry * ry * (1.0 - (x * x) / (rx * rx))
        if (y > 0.0) {
            y = sqrt(y)
        }
        y = ry - y
        if (point.y - nodeY > 0.0) {
            y = -y
        }
        return DagrePoint(pos.x, pos.y + y)
    }
    return pos
}

public func intersectLine(p1: DagrePoint, p2: DagrePoint, q1: DagrePoint, q2: DagrePoint): ?DagrePoint {
    let a1 = p2.y - p1.y
    let b1 = p1.x - p2.x
    let c1 = p2.x * p1.y - p1.x * p2.y
    let r3 = a1 * q1.x + b1 * q1.y + c1
    let r4 = a1 * q2.x + b1 * q2.y + c1
    if (r3 != 0.0 && r4 != 0.0 && sameSign(r3, r4)) {
        return None
    }

    let a2 = q2.y - q1.y
    let b2 = q1.x - q2.x
    let c2 = q2.x * q1.y - q1.x * q2.y
    let r1 = a2 * p1.x + b2 * p1.y + c2
    let r2 = a2 * p2.x + b2 * p2.y + c2
    if (r1 != 0.0 && r2 != 0.0 && sameSign(r1, r2)) {
        return None
    }

    let denom = a1 * b2 - a2 * b1
    if (denom == 0.0) {
        return None
    }

    let offset = absFloat(denom / 2.0)
    var num = b1 * c2 - b2 * c1
    let x = if (num < 0.0) { (num - offset) / denom } else { (num + offset) / denom }
    num = a2 * c1 - a1 * c2
    let y = if (num < 0.0) { (num - offset) / denom } else { (num + offset) / denom }
    return Some(DagrePoint(x, y))
}

public func intersectPolygon(node: DagreNode, polyPoints: Array<DagrePoint>, point: DagrePoint): DagrePoint {
    if (polyPoints.isEmpty()) {
        return DagrePoint(node.x ?? 0.0, node.y ?? 0.0)
    }
    var minX = polyPoints[0].x
    var minY = polyPoints[0].y
    for (entry in polyPoints) {
        minX = minFloat(minX, entry.x)
        minY = minFloat(minY, entry.y)
    }

    let x = node.x ?? 0.0
    let y = node.y ?? 0.0
    let left = x - (node.width ?? 0.0) / 2.0 - minX
    let top = y - (node.height ?? 0.0) / 2.0 - minY
    let intersections = ArrayList<DagrePoint>()
    for (i in 0..polyPoints.size) {
        let p1 = polyPoints[i]
        let p2 = polyPoints[if (i < polyPoints.size - 1) { i + 1 } else { 0 }]
        if (let Some(found) <- intersectLine(
            DagrePoint(x, y),
            point,
            DagrePoint(left + p1.x, top + p1.y),
            DagrePoint(left + p2.x, top + p2.y)
        )) {
            intersections.add(found)
        }
    }

    if (intersections.isEmpty()) {
        return DagrePoint(x, y)
    }
    if (intersections.size > 1) {
        var best = intersections[0]
        var bestDistance = distanceSquared(best, point)
        for (entry in intersections) {
            let currentDistance = distanceSquared(entry, point)
            if (currentDistance < bestDistance) {
                best = entry
                bestDistance = currentDistance
            }
        }
        return best
    }
    return intersections[0]
}

public func cutPathAtIntersect(points: Array<DagrePoint>, boundaryNode: DagreNode): Array<DagrePoint> {
    if (points.isEmpty()) {
        return []
    }
    let out = ArrayList<DagrePoint>()
    var lastPointOutside = points[0]
    var isInside = false
    for (point in points) {
        if (!outsideNode(boundaryNode, point) && !isInside) {
            let inter = intersection(boundaryNode, lastPointOutside, point)
            if (!containsPoint(out, inter)) {
                out.add(inter)
            }
            isInside = true
        } else if (outsideNode(boundaryNode, point)) {
            lastPointOutside = point
            if (isInside) {
                out.add(point)
            }
            isInside = false
        } else if (!isInside) {
            out.add(point)
        }
    }
    return out.toArray()
}

func sameSign(left: Float64, right: Float64): Bool {
    return left * right > 0.0
}

func distanceSquared(left: DagrePoint, right: DagrePoint): Float64 {
    let dx = left.x - right.x
    let dy = left.y - right.y
    return dx * dx + dy * dy
}

func containsPoint(points: ArrayList<DagrePoint>, point: DagrePoint): Bool {
    for (entry in points) {
        if (entry.x == point.x && entry.y == point.y) {
            return true
        }
    }
    return false
}
