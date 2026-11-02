// expect-error: CLI command name 'help' is reserved
package fixture
import jian.*
@JianCommand[name: "help"]
func run(): Unit {}
