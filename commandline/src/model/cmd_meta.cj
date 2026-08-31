package commandline.model

import std.collection.ArrayList

/**
 * 命令元数据类
 * 存储命令的基本信息和配置
 */
public class CmdMeta {
    public CmdMeta(
        public let name: String,
        public let description: String,
        public let usage: String,
        public let function: String,
        public let examples!: ArrayList<String> = ArrayList<String>(),
        public let arguments!: ArrayList<String> = ArrayList<String>(),
        public let options!: ArrayList<String> = ArrayList<String>()
    ) {}
}