package ratatoskr_tests

import "core:fmt"
import test "core:testing"

@(test)
test :: proc(^test.T) {
	fmt.println("TEST EXECUTED!")
}
