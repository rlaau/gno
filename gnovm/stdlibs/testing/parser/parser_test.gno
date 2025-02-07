package parser

import (
	"fmt"
	"strconv"
	"testing"
	"unicode/utf8"
)

func TestParser(t *testing.T) {
	texts := []string{
		`func main() {
		parser := NewParser(input)
		t1 := parser.parseTokens(0)
		root := rootEnt{depth: -0x12, data: t1}
		root = applyPatternToRoot(root)
		printTokens([]Ent{root}, 0)
		printTokens([]Ent{root}, 0)
		}`, "{a:apple}     hello := world (x=4)", "<<<<>a<a>", "hello world!", "2138*@#(*@#@#)", "*&@#@!@#)",
		"12837218937", `body {
    counter-reset: katexEqnNo 0 mmlEqnNo 0;
}`,
	}

	for i, e := range texts {
		myAst := parseToRoot(e)
		sealized := serializeToString(myAst)

		if e != sealized {
			t.Errorf("not equal!")
		} else {
			println("ok")
		}
	}
}

func isValidUnicode(s string) bool {
	return utf8.ValidString(s)
}

var (
	counter   int
	validTest int
)

func FuzzParser(f *testing.F) {
	testedStrings := []string{}
	program := `func main() {
		parser := NewParser(input)
		t1 := parser.parseTokens(0)
		root := rootEnt{depth: -0x12, data: t1}
		root = applyPatternToRoot(root)
		printTokens([]Ent{root}, 0)
		printTokens([]Ent{root}, 0)
		}`
	f.Add(program)
	f.Fuzz(func(t *testing.T, p ...interface{}) {
		counter++
		if counter%100 == 0 {
			println(strconv.Itoa(counter) + "th trial")
		}
		s, ok := p[0].(string)
		if !ok {
			panic("dont match")
		}
		if !isValidUnicode(s) {
			return
		}
		sourceCode := program
		ast := parseToRoot(sourceCode)
		sealized := serializeToString(ast)
		validTest++
		if validTest%40 == 0 {
			testedStrings = append(testedStrings, sourceCode)
			testedStrings = append(testedStrings, sealized)
			println(strconv.Itoa(validTest) + "th validTest!")
			if validTest%200 == 0 {
				// 🔹 중복 제거
				uniqueTestedStrings := removeDuplicates(testedStrings)
				fmt.Println(uniqueTestedStrings) // 중복 제거된 리스트 출력
			}
		}
		if program != sealized {
			panic("dont equal")
		}
	})
}

func removeDuplicates(stringsList []string) []string {
	uniqueSet := make(map[string]bool) // 문자열 저장할 맵
	uniqueList := []string{}

	for _, str := range stringsList {
		if !uniqueSet[str] { // 중복 검사
			uniqueSet[str] = true
			uniqueList = append(uniqueList, str)
		}
	}
	return uniqueList
}
