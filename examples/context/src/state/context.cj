package context_example.state

import jian.*
import context_example.services.Logger

@JianContext
public class AppContext {
    public let logger: Logger = Logger()
}
