package markit.plugins.gfm.block.table

public enum TableAlignment <: ToString {
    |Left
    |Center
    |Right
    |None

    public func toString(): String {
        match (this) {
            case Left => return "Left"
            case Center => return "Center"
            case Right => return "Right"
            case None => return "None"
        }
    }
}
