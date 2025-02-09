package cov_test

import (
	"testing"

	"github.com/gnolang/gno/gnovm/stdlibs/testing/repl"
)

// TODO 절대 수정하지 마삼!!!!!!!!!1
// TODO: 파일 절대 수정 금지!!
func TestGet(t *testing.T) {
	//getCovOfGnovm()
	a, _ := repl.RunGNOFileInGo(`package main

		func anomFunc() int {
			// 익명함수를 정의하고 바로 호출합니다.
			result := (func(a int) int {
				if a == 6 {
					println("catch!")
				}
				println("Hello from Gno!!!!!!!!", a)
				// 더 복잡한 코드 추가 가능
				return 1
			})(6)
			
			println("std로 리턴:", result)
			return 14
		}`)
	println("returned된 값:", a)
}
