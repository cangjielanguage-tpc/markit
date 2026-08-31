package markit.core.source

public enum SourceRetentionMode <: ToString {
    |None
    |Essential
    |Full

    public override func toString(): String {
        match (this) {
            case None => return "None"
            case Essential => return "Essential"
            case Full => return "Full"
        }
    }

    public operator func ==(right: SourceRetentionMode): Bool {
        return this.toString() == right.toString()
    }
}
