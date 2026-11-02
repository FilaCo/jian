// expect-error: invalid CLI command name
package fixture
import jian.*
@JianCommand[name: "two words"]
func run(): Unit {}
