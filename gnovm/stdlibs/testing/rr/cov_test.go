package cov_test

import (
	"testing"

	"github.com/gnolang/gno/gnovm/stdlibs/testing/repl"
)
	// generated file
func TestGet(t *testing.T) {
	//getCovOfGnovm()
	a, _ := repl.RunGNOFileInGo(`package rlaau
	import "testing"

 		func anomFunc() int {
			nt := testing.NewT("fuzzss")
			ttt := 0
			// 여기에 t를 주입. 
			// 어떤 익명함수 fn(t *testing.T ...)
			//가 나오면, 그 소스코드에 fn내부적으로 삽입하기
			// 어차피 이건 파일이라서.
			// 밑에 closer함수 만들고, closer는 *testing.T를 받음
			// anomFunc는 close(nt)를 내부적으로
 			result := (func(a int) int {
 				if a == 6 {
					ttt=1
 				} else {
				 println("도달")
				 }
 				println("Hello from Gno!!!!!!!!", a)
 				// 더 복잡한 코드 추가 가능
 				return 1
 			})(testing.SomeNumber)

 			println("std로 리턴:", result)
 			return 36
 		}`)
	println("returned된 값:", a)
}
