package commandline.terminal

import std.collection.ArrayList

public interface TerminalBackend {
    func supportsKeyNavigation(): Bool
    func enterKeyMode(): Bool
    func leaveKeyMode(): Unit
    func readKey(): TerminalKey
}

public class SelectMenuState {
    public let optionCount: Int
    public var cursor: Int = 0

    public init(optionCount: Int, defaultIndex!: ?Int = None) {
        if (optionCount <= 0) {
            throw Exception("SelectMenuState requires at least one option")
        }

        this.optionCount = optionCount
        this.cursor = match (defaultIndex) {
            case Some(index) => if (index >= 0 && index < optionCount) { index } else { 0 }
            case None => 0
        }
    }

    public func moveUp(): Unit {
        cursor = if (cursor == 0) { optionCount - 1 } else { cursor - 1 }
    }

    public func moveDown(): Unit {
        cursor = (cursor + 1) % optionCount
    }

    public func result(): SelectResult {
        return SelectResult.Selected(cursor)
    }
}

public class MultiSelectMenuState {
    public let optionCount: Int
    public var cursor: Int = 0
    private let selected: ArrayList<Int>

    public init(optionCount: Int, defaultIndices!: Array<Int> = []) {
        if (optionCount <= 0) {
            throw Exception("MultiSelectMenuState requires at least one option")
        }

        this.optionCount = optionCount
        this.selected = ArrayList<Int>()

        for (index in defaultIndices) {
            if (index >= 0 && index < optionCount && !selected.contains(index)) {
                selected.add(index)
            }
        }

        this.cursor = if (!defaultIndices.isEmpty() && defaultIndices[0] >= 0 && defaultIndices[0] < optionCount) {
            defaultIndices[0]
        } else {
            0
        }
    }

    public func moveUp(): Unit {
        cursor = if (cursor == 0) { optionCount - 1 } else { cursor - 1 }
    }

    public func moveDown(): Unit {
        cursor = (cursor + 1) % optionCount
    }

    public func isSelected(index: Int): Bool {
        return selected.contains(index)
    }

    public func toggleCurrent(): Unit {
        toggleSelection(cursor)
    }

    public func selectAll(): Unit {
        clearAll()
        for (i in 0..optionCount) {
            selected.add(i)
        }
    }

    public func clearAll(): Unit {
        while (selected.size > 0) {
            selected.remove(0..1)
        }
    }

    public func selectedIndices(): Array<Int> {
        let result = selected.toArray()
        var i = 0
        while (i < result.size) {
            var j = i + 1
            while (j < result.size) {
                if (result[j] < result[i]) {
                    let temp = result[i]
                    result[i] = result[j]
                    result[j] = temp
                }
                j += 1
            }
            i += 1
        }
        return result
    }

    public func confirm(): ?MultiSelectResult {
        let result = selectedIndices()
        if (result.isEmpty()) {
            return None<MultiSelectResult>
        }
        return Some(MultiSelectResult.Selected(result))
    }

    private func toggleSelection(index: Int): Unit {
        if (selected.contains(index)) {
            for (i in 0..selected.size) {
                if (selected[i] == index) {
                    selected.remove(i..(i + 1))
                    return
                }
            }
            return
        }
        selected.add(index)
    }
}
