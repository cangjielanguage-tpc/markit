package dochir.docgen

import stdx.chir.*
import std.collection.ArrayList
import std.fs.{Directory, Path, exists, remove}

/**
 * Walk CHIR packages and emit markdown files.
 * For now, this is a thin coordinator; later it will map elements and members.
 */
public class ChirWalk {
    public static func emitPackage(pkg: Package, outRoot: String): Unit {
        let pkgPath = Pathing.packageNameToPath(pkg.name)
        let outDir = outRoot + "/" + pkgPath

        cleanPackageMarkdown(outDir)
        EmitPackage.emitIndex(pkg, outDir, [])
        EmitProject.emitLanding(parentRoot(outRoot))

        for (d in pkg.classDefs) {
            if (ApiFormat.isDocumentable(d, pkg.name)) {
                EmitElement.emitClassLike(d, outDir)
            }
        }
        for (d in pkg.structDefs) {
            if (ApiFormat.isDocumentable(d, pkg.name)) {
                EmitElement.emitStruct(d, outDir)
            }
        }
        for (d in pkg.enumDefs) {
            if (ApiFormat.isDocumentable(d, pkg.name)) {
                EmitElement.emitEnum(d, outDir)
            }
        }
        for (d in pkg.extendDefs) {
            if (ApiFormat.isDocumentable(d, pkg.name)) {
                EmitElement.emitExtend(d, outDir)
            }
        }
        EmitProject.emitLanding(parentRoot(outRoot))
    }

    public static func emitAll(pkgs: Array<Package>, outRoot: String): Unit {
        // Build a simple package tree from dot-separated names.
        for (pkg in pkgs) {
            let pkgPath = Pathing.packageNameToPath(pkg.name)
            let outDir = outRoot + "/" + pkgPath

            // Direct subpackages: those that start with `${pkg.name}.` and have one extra segment.
            let subsList = ArrayList<Package>()
            let prefix = pkg.name + "."
            for (cand in pkgs) {
                if (!cand.name.startsWith(prefix)) { continue }
                let rest = cand.name[prefix.size..cand.name.size]
                if (!rest.contains(".")) {
                    subsList.add(cand)
                }
            }

            cleanPackageMarkdown(outDir)
            EmitPackage.emitIndex(pkg, outDir, subsList.toArray())

            // Emit element pages into this package folder.
            for (d in pkg.classDefs) {
                if (ApiFormat.isDocumentable(d, pkg.name)) {
                    EmitElement.emitClassLike(d, outDir)
                }
            }
            for (d in pkg.structDefs) {
                if (ApiFormat.isDocumentable(d, pkg.name)) {
                    EmitElement.emitStruct(d, outDir)
                }
            }
            for (d in pkg.enumDefs) {
                if (ApiFormat.isDocumentable(d, pkg.name)) {
                    EmitElement.emitEnum(d, outDir)
                }
            }
            for (d in pkg.extendDefs) {
                if (ApiFormat.isDocumentable(d, pkg.name)) {
                    EmitElement.emitExtend(d, outDir)
                }
            }
        }
        EmitProject.emitLanding(outRoot)
    }

    private static func cleanPackageMarkdown(outDir: String): Unit {
        let dir = Path(outDir)
        if (!exists(dir)) {
            return
        }
        try {
            for (entry in Directory.readFrom(dir)) {
                if (entry.isRegular() && entry.name.endsWith(".md")) {
                    remove(entry.path)
                }
            }
        } catch (e: Exception) {
            ()
        }
    }

    private static func parentRoot(outRoot: String): String {
        if (outRoot.endsWith("/packages")) {
            return outRoot[0..(outRoot.size - 9)]
        }
        return outRoot
    }
}

