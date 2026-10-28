// expect-error: duplicate CLI parameter name '--sync-all'
package fixture

import jian.*

@Command
func example(sync_all!: Bool, syncAll!: Bool): Unit {}
