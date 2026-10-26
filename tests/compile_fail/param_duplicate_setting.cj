// expect-error: duplicate Param setting 'help'
package fixture

import jian.*

@Command
func example(@Param[help: "one", help: "two"] value!: Bool) {}
