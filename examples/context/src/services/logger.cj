package context_example.services

public class Logger {
    public var verbose = false

    public func greet(name: String): Unit {
        if (verbose) { println("Greeting ${name}") }
        println("Hello, ${name}!")
    }
}
