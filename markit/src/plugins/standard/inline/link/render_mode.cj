package markit.plugins.standard.inline.link

public enum RenderMode {
    | Normal
    | Flat

    public operator func ==(right: RenderMode): Bool {
        match (this) {
            case Normal =>
                match (right) {
                    case Normal => true
                    case Flat => false
                }
            case Flat =>
                match (right) {
                    case Normal => false
                    case Flat => true
                }
        }
    }
}
