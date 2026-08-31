package mermaid4cj.layout.dagre

import mermaid4cj.core.{FlowDirection, FlowchartDiagram}

public func buildFlowchartDagreGraph(diagram: FlowchartDiagram): MermaidDagreGraph {
    let graph = MermaidDagreGraph().setGraph(rankdir: Some(directionName(diagram.direction)))
    for (subgraph in diagram.subgraphDefs) {
        graph.setNode(
            subgraph.id,
            DagreNode(
                subgraph.id,
                dir: directionOptionName(subgraph.dir),
                explicitDir: subgraph.explicitDir
            )
        )
        if (let Some(parentId) <- subgraph.parentId) {
            graph.setParent(subgraph.id, parentId)
        }
    }
    for (node in diagram.nodes) {
        graph.setNode(node.id, DagreNode(node.id))
        if (let Some(parentId) <- diagram.nodeParents.get(node.id)) {
            graph.setParent(node.id, parentId)
        }
    }
    for (edge in diagram.edges) {
        let id = edge.id ?? ("L_" + edge.source + "_" + edge.target)
        if (edge.source == edge.target) {
            addSelfLoopDagreEdges(graph, edge.source, id)
        } else {
            graph.setEdge(edge.source, edge.target, DagreEdge(id, edge.source, edge.target, length: edge.length), id)
        }
    }
    adjustClustersAndEdges(graph)
    return graph
}

func addSelfLoopDagreEdges(graph: MermaidDagreGraph, nodeId: String, edgeId: String): Unit {
    let specialId1 = nodeId + "---" + nodeId + "---1"
    let specialId2 = nodeId + "---" + nodeId + "---2"
    let parentId = graph.parent(nodeId)
    graph.setNode(specialId1, DagreNode(specialId1, width: Some(10.0), height: Some(10.0)))
    graph.setNode(specialId2, DagreNode(specialId2, width: Some(10.0), height: Some(10.0)))
    if (let Some(parent) <- parentId) {
        graph.setParent(specialId1, parent)
        graph.setParent(specialId2, parent)
    }

    let originalEdge = DagreEdge(edgeId, nodeId, nodeId)
    graph.setEdge(
        nodeId,
        specialId1,
        DagreEdge(nodeId + "-cyclic-special-1", nodeId, nodeId, selfLoop: Some(DagreSelfLoop(edgeId, 0)), originalEdge: Some(originalEdge)),
        nodeId + "-cyclic-special-0"
    )
    graph.setEdge(
        specialId1,
        specialId2,
        DagreEdge(nodeId + "-cyclic-special-mid", nodeId, nodeId, selfLoop: Some(DagreSelfLoop(edgeId, 1)), originalEdge: Some(originalEdge)),
        nodeId + "-cyclic-special-1"
    )
    graph.setEdge(
        specialId2,
        nodeId,
        DagreEdge(nodeId + "-cyclic-special-2", nodeId, nodeId, selfLoop: Some(DagreSelfLoop(edgeId, 2)), originalEdge: Some(originalEdge)),
        nodeId + "-cyclic-special-2"
    )
}

func directionOptionName(direction: ?FlowDirection): ?String {
    if (let Some(value) <- direction) {
        return Some(directionName(value))
    }
    return None
}

func directionName(direction: FlowDirection): String {
    match (direction) {
        case FlowDirection.TD => return "TD"
        case FlowDirection.TB => return "TB"
        case FlowDirection.BT => return "BT"
        case FlowDirection.LR => return "LR"
        case FlowDirection.RL => return "RL"
    }
}
