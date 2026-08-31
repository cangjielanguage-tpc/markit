package markit_kit.utils

import std.collection.ArrayList
import markit_kit.models.GlobalContext
import std.fs.{Path, exists}

/**
 * Resolves bundled resources from the asset root provided by the upstream caller.
 */
public class ResourceResolver {
    public static func resolveResourcePath(relativePath: String): Path {
        let candidates = getResourceCandidates(relativePath)
        for (candidate in candidates) {
            if (exists(candidate)) {
                return candidate
            }
        }
        return candidates[0]
    }

    public static func resolveResourcePathString(relativePath: String): String {
        return resolveResourcePath(relativePath).toString()
    }

    public static func resourceExists(relativePath: String): Bool {
        for (candidate in getResourceCandidates(relativePath)) {
            if (exists(candidate)) {
                return true
            }
        }
        return false
    }

    public static func getResourceCandidates(relativePath: String): Array<Path> {
        let path = Path(relativePath)
        if (path.isAbsolute()) {
            return [path.normalize()]
        }

        let assetRoot = GlobalContext.assetRoot
        if (assetRoot.isEmpty()) {
            throw Exception("Asset root is not configured by upstream caller")
        }

        let candidates = ArrayList<Path>()
        addCandidate(candidates, Path(assetRoot).join(stripAssetsPrefix(relativePath)).normalize())

        return candidates.toArray()
    }

    private static func addCandidate(candidates: ArrayList<Path>, path: Path): Unit {
        if (!candidates.contains(path)) {
            candidates.add(path)
        }
    }

    private static func stripAssetsPrefix(relativePath: String): String {
        if (relativePath == "assets") {
            return ""
        }
        if (relativePath.startsWith("assets/")) {
            return relativePath[7..]
        }
        if (relativePath.startsWith("assets\\")) {
            return relativePath[7..]
        }
        return relativePath
    }
}
