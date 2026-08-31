package dochir.plugin

import dochir.docgen.DocCollector
import dochir.model.DocModelStore
import stdx.chir.*
import stdx.plugin.*

@CHIRPlugin
public class DocChirPlugin {
    public override func run(pkg: Package): Bool {
        let config = DocModelStore.readPluginConfig()
        for (language in config.languages) {
            DocCollector.configure(language: language, defaultLang: config.defaultLang)
            DocModelStore.writePackage(
                DocModelStore.languageModelDir(config.modelDir, language),
                DocCollector.collectPackage(pkg)
            )
        }
        return true
    }
}
