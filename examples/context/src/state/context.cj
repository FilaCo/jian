package context_example.state

import jian.*
import context_example.services.Logger

@JianContext
public class PeopleContext {
    public let logger: Logger = Logger()
}

@JianContext
public class AppContext {
    public let people: PeopleContext = PeopleContext()
}
