package dochir.docgen

import markit.dsl.*
import std.collection.ArrayList
import std.fs.{Directory, Path, exists}

public class EmitProject {
    public static func emitLanding(outRoot: String): Unit {
        let blocks = ArrayList<BlockSpec>()
        let rows = ArrayList<TableRowSpec>()
        let packagesRoot = Path(outRoot).join("packages")

        if (exists(packagesRoot)) {
            collectPackages(packagesRoot, "", rows)
        }

        blocks.add(h1("API Reference"))
        blocks.add(divider())
        blocks.add(h2("Packages"))
        if (rows.isEmpty()) {
            blocks.add(p("No public packages were documented."))
        } else {
            blocks.add(table(
                header("Package", "Link"),
                rows.toArray()
            ))
        }

        EmitMarkdown.document(blocks.toArray()).dumpMarkdown(outRoot, filename: Pathing.packageIndexFile())
    }

    private static func collectPackages(root: Path, relative: String, rows: ArrayList<TableRowSpec>): Unit {
        let indexPath = root.join(Pathing.packageIndexFile())
        if (!relative.isEmpty() && exists(indexPath)) {
            let packageName = relative.replace("/", ".")
            rows.add(row(
                cell(packageName),
                cell(link("packages/" + relative + "/" + Pathing.packageIndexFile(), "index"))
            ))
        }

        try {
            for (entry in Directory.readFrom(root)) {
                if (entry.isDirectory()) {
                    let next = if (relative.isEmpty()) { entry.name } else { relative + "/" + entry.name }
                    collectPackages(entry.path, next, rows)
                }
            }
        } catch (e: Exception) {
            ()
        }
    }
}
