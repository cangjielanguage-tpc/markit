package markit_kit.models

import std.collection.ArrayList

/**
 * 文件树节点类
 * 用于构建层级导航结构
 */
public class FileTreeNode {
    public let children: ArrayList<FileTreeNode>
    
    public FileTreeNode(public let name: String, public let title: String, public let path: String,
        public let isDirectory: Bool) {
        this.children = ArrayList<FileTreeNode>()
    }
}
