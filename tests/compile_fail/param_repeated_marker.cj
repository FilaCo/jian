// expect-error: apply @Param only once per parameter
package fixture

import jian.*

@Command
func example(@Param[short: 'v'] @Param[help: "text"] value!: Bool) {}
