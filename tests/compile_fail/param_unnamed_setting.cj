// expect-error: @Param settings must be named
package fixture

import jian.*

@Command
func example(@Param['v'] value!: Bool) {}
