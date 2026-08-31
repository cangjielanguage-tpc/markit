package markit_kit.utils

public interface Optional<T> {
    operator func !(): T { 
        (this as Option<T>).getOrThrow().getOrThrow()
    }
 }

extend <T> Option<T> <: Optional<T> where T <: Any { }