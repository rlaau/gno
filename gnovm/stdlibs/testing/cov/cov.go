package cov

import (
	"bytes"
	"fmt"
	"os"
	"os/exec"
	"strings"
)

// getGnoPackages는 "github.com/gnolang/gno/gnovm/pkg/gnolang/" 하위의 모든 패키지를 가져와 쉼표로 연결합니다.
func getGnoPackages() (string, error) {
	// 패키지 목록을 "github.com/gnolang/gno/gnovm/pkg/gnolang/..." 로 제한합니다.
	cmd := exec.Command("go", "list", "github.com/gnolang/gno/gnovm/pkg/gnolang/")
	var out bytes.Buffer
	cmd.Stdout = &out
	cmd.Stderr = &out

	err := cmd.Run()
	if err != nil {
		return "", fmt.Errorf("failed to list packages: %v\nOutput: %s", err, out.String())
	}

	// 결과를 줄 단위로 분리한 뒤, 쉼표로 연결합니다.
	lines := strings.Split(strings.TrimSpace(out.String()), "\n")
	packages := strings.Join(lines, ",")
	return packages, nil
}

// // getCoverage는 "github.com/gnolang/gno/gnovm/pkg/gnolang/" 하위의 패키지들에 대해 커버리지를 측정합니다.
func getCoverage() error {
	// 해당 패키지 목록 가져오기
	pkgList, err := getGnoPackages()
	if err != nil {
		return err
	}

	// 커버리지 실행 명령어 (테스트 실행 시 -coverpkg 옵션에 위 pkgList를 적용)
	cmd := exec.Command("go", "test", "-coverpkg="+pkgList, "-v", "-coverprofile=coverage.out")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	// 실행
	err = cmd.Run()
	if err != nil {
		return fmt.Errorf("failed to run tests with coverage: %v", err)
	}

	fmt.Println("Coverage profile generated: coverage.out")
	return nil
}

// func getCovOfGnovm() {
// 	result, err := repl.RunGNOinGo(`(func(a int) int {

// 		println("Hello from Gno!!!!!!!!",a)
// 		// 더 복잡한 코드 추가 가능
// 		return a
// 		})(6)`)
// 	if err != nil {
// 		println("ERROR발생:", err)
// 	} else {
// 		println("실행 결과:", result)
// 	}
// }

// filterNonZeroLines는 입력 문자열에서, 각 줄의 세 번째 필드(실행 횟수)가 0이 아닌 라인만 반환합니다.
func filterNonZeroLines(input string) string {
	var outputLines []string
	lines := strings.Split(input, "\n")
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		fields := strings.Fields(line)
		if len(fields) < 3 {
			continue
		}
		// 세 번째 필드가 "0"이 아니면 결과에 포함
		if fields[2] != "0" {
			outputLines = append(outputLines, line)
		}
	}
	return strings.Join(outputLines, "\n")
}

// filterMachineCoverage는 입력된 커버리지 결과 문자열에서
// "github.com/gnolang/gno/gnovm/pkg/gnolang/machine.go:"로 시작하는 라인만을 추출하여 반환합니다.
func filterMachineCoverage(input string) string {
	const targetPrefix = "github.com/gnolang/gno/gnovm/pkg/gnolang/machine.go:"
	lines := strings.Split(input, "\n")
	var filteredLines []string
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		if strings.HasPrefix(line, targetPrefix) {
			filteredLines = append(filteredLines, line)
		}
	}
	return strings.Join(filteredLines, "\n")
}

//func main() {
// println("start Main")

// // 1. 커버리지 측정 실행 (github.com/gnolang/gno/gnovm/pkg/gnolang/ 하위의 패키지들에 대해서)
// err := getCoverage()
// if err != nil {
// 	fmt.Println("Error running coverage test:", err)
// 	return
// }

// // 3. coverage.out 파일 전체에서,
// //    (a) machine.go에 속한 라인만 필터링하고,
// //    (b) 그 중 세 번째 필드(실행 횟수)가 0이 아닌 라인만 남깁니다.
// data, err := os.ReadFile("coverage.out")
// if err != nil {
// 	fmt.Println("Error reading coverage.out:", err)
// 	return
// }
// allFiltered := filterNonZeroLines(string(data))
// machineFiltered := filterMachineCoverage(allFiltered)

// fmt.Println("Filtered coverage lines (machine.go only, execution count nonzero):")
// fmt.Println(machineFiltered)
// a, _ := repl.RunGNOFileInGo(`

// package main

// func anomFunc() int {
// 	// 익명함수를 정의하고 바로 호출합니다.
// 	result := (func(a int) int {
// 		if a == 6 {
// 			println("처음 std값")
// 		}
// 		println("Hello from Gno!!!!!!!!", a)
// 		// 더 복잡한 코드 추가 가능
// 		return 1
// 	})(6)

// 	println("std로 리턴:", result)

//		// 무한 루프 대신 몇 번만 반복
//		for i := 0; i < 5000; i++ {
//			// for j := 0; j < 5000; j++ {
//			// 	println("kk")
//			// }
//		}
//			return 8
//	}`)
//
// println("returned된 값(이게 8이 아니네..):", a)
//
//		getCoverage()
//	}
func WriteCovTestFile(sourceCode string) error {
	// 템플릿 문자열 안에 %s 자리에 입력받은 sourceCode가 삽입됩니다.
	const template = `package cov_test

import (
	"testing"

	"github.com/gnolang/gno/gnovm/stdlibs/testing/repl"
)
	// generated file
func TestGet(t *testing.T) {
	//getCovOfGnovm()
	a, _ := repl.RunGNOFileInGo(` + "`" + `%s` + "`" + `)
	println("returned된 값:", a)
}
`
	// sourceCode를 템플릿에 삽입
	content := fmt.Sprintf(template, sourceCode)
	// 파일 cov_test.go에 저장 (권한: 0644)
	return os.WriteFile("cov_test.go", []byte(content), 0644)
}

func X_getCovOfSource(sourceCode string) string {

	if err := WriteCovTestFile(sourceCode); err != nil {
		fmt.Println("Error writing cov_test.go:", err)
		os.Exit(1)
	}
	fmt.Println("cov_test.go written successfully.")
	err := getCoverage()
	if err != nil {
		fmt.Println("Error running coverage:", err)
		return "error occuered"
	}

	// 2. coverage.out 파일 전체를 읽어들입니다.
	data, err := os.ReadFile("coverage.out")
	if err != nil {
		fmt.Println("Error reading coverage.out:", err)
		return "error occuered"
	}
	coverageData := string(data)

	// 3. 전체 커버리지 결과에서 실행 횟수가 0이 아닌 라인만 필터링합니다.
	nonZero := filterNonZeroLines(coverageData)

	// 4. 그 중 machine.go에 해당하는 라인만 추출합니다.
	machineCoverage := filterMachineCoverage(nonZero)

	// 5. 결과를 순차적으로 출력합니다.

	fmt.Println("\n=== machine.go에 해당하는 커버리지 라인 ===")
	fmt.Println(machineCoverage)
	return machineCoverage
}

// func main() {
// 	// 1. 커버리지 프로파일을 생성합니다.
// 	// 예시: 간단한 Gno 소스 코드를 전달합니다.
// 	exampleSource := `package main

// 		func anomFunc() int {
// 			// 익명함수를 정의하고 바로 호출합니다.
// 			result := (func(a int) int {
// 				if a == 6 {
// 					println("catch!")
// 				}
// 				println("Hello from Gno!!!!!!!!", a)
// 				// 더 복잡한 코드 추가 가능
// 				return 1
// 			})(6)

// 			println("std로 리턴:", result)
// 			return 14
// 		}`
// 	getCovOfSource(exampleSource)
// }

// parseCoverageFile는 coverage.out 파일에서, 특정 함수 이름이 포함된 라인의 세 번째 필드를
// 파싱하여 커버리지 값을 반환합니다.
func parseCoverageFile(filename, funcName string) (float64, error) {
	cmd := exec.Command("go", "tool", "cover", "-func="+filename)
	var out bytes.Buffer
	cmd.Stdout = &out
	cmd.Stderr = &out

	err := cmd.Run()
	if err != nil {
		return 0, fmt.Errorf("failed to analyze coverage file: %v\nOutput: %s", err, out.String())
	}

	lines := strings.Split(out.String(), "\n")
	for _, line := range lines {
		if strings.Contains(line, funcName) {
			parts := strings.Fields(line)
			if len(parts) >= 3 {
				var coverage float64
				fmt.Sscanf(parts[2], "%f", &coverage)
				return coverage, nil
			}
		}
	}
	return 0, fmt.Errorf("function %s not found in coverage report", funcName)
}

// // 테스트할 Gno 실행 함수 (예시)
// func testingFunction() {
// 	repl.RunGnoExpr(`func main() int {
//  	println("Hello from Gno!")
//  	return 1
//  	// 더 복잡한 코드 추가 가능
//  }`)
// }
