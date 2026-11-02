// expect-error: CLI command name 'help' is reserved
package fixture
import jian.*
@JianCommand[aliases: ["help"]]
func run(): Unit {}
