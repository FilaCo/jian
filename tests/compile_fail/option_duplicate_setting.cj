// expect-error: duplicate Option setting 'help'
package fixture

import jian.*

@Command
func example(value!: Bool = Option(help: "one", help: "two")) {}
