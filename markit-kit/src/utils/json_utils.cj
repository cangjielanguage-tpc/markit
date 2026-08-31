package markit_kit.utils

import seajson.*
import std.collection.ArrayList

/**
 * 项目级 JSON 字段读取工具。
 *
 * SeaJson 已经提供了 jsonFieldString/jsonFieldBool/jsonFieldObj 等基础 API；
 * 这里仅保留 markit 配置需要的数组类型收窄逻辑。
 */
public class JsonUtils {
    public static func fieldIntArray(obj: JsonValue, key: String): ?Array<Int> {
        match (jsonField(obj, key)) {
            case Some(JsonArrVal(items)) =>
                let result = ArrayList<Int>()
                for (item in items) {
                    match (item) {
                        case JsonIntVal(value) => result.add(value)
                        case JsonInt32Val(value) => result.add(Int64(value))
                        case _ => return None
                    }
                }
                return Some(result.toArray())
            case _ => return None
        }
    }

    public static func fieldStringArray(obj: JsonValue, key: String): ?Array<String> {
        match (jsonField(obj, key)) {
            case Some(JsonArrVal(items)) =>
                let result = ArrayList<String>()
                for (item in items) {
                    match (item) {
                        case JsonStrVal(value) => result.add(value)
                        case _ => return None
                    }
                }
                return Some(result.toArray())
            case _ => return None
        }
    }
}
