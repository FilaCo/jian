// expect-error: invalid CLI command name
package fixture
import jian.*
@JianCommand[name: ""]
func run(): Unit {}
