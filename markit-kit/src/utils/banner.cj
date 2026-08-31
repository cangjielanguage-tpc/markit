package markit_kit.utils


/**
 * 打印 Markit 的 ASCII 艺术字横幅
 */
public func printBanner(): Unit {
    KitHooks.plain(#"
 _______               __     __  __   
|   |   |.---.-..----.|  |--.|__||  |_ 
|       ||  _  ||   _||    < |  ||   _|
|__|_|__||___._||__|  |__|__||__||____|

"#)
}
