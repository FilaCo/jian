// expect-error: invalid CLI command name
package fixture
import jian.*
@JianCommand[name: "--run"]
func run(): Unit {}
