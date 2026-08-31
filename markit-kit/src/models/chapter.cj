package markit_kit.models

import std.collection.ArrayList

/**
 * 章节
 * 表示导航中的一个章节，可以包含子章节
 */
public struct Chapter {
    public Chapter(
        public let displayName: String,
        public let filePath: String,
        public let icon: String,
        public let isDraft: Bool,
        public let children: Array<Chapter>,
        public let order: Int
    ) {}
}
