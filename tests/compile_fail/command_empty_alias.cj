// expect-error: invalid CLI command name
package fixture
import jian.*
@JianCommand[aliases: [""]]
func run(): Unit {}
