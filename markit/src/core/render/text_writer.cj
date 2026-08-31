package markit.core.render

import std.io.OutputStream

public interface TextWriter {
    func write(value: String): Unit
}

public class StringTextWriter <: TextWriter {
    private var buffer: StringBuilder = StringBuilder()

    public func write(value: String): Unit {
        buffer.append(value)
    }

    public func toString(): String {
        return buffer.toString()
    }
}

public class OutputStreamTextWriter <: TextWriter {
    private let output: OutputStream

    public init(output: OutputStream) {
        this.output = output
    }

    public func write(value: String): Unit {
        if (!value.isEmpty()) {
            output.write(value.toArray())
        }
    }

    public func flush(): Unit {
        output.flush()
    }
}
