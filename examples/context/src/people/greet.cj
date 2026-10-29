package context_example.people

import jian.*
import context_example.state.PeopleContext
import context_example.services.Logger

@JianCommand[app]
func greet(name: String, logger!: Logger = JianFromContext<PeopleContext>()): Unit {
    logger.greet(name)
}
