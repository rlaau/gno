package main

import (
	"bytes"
	"fmt"
	"os"
	"os/exec"
	"strings"

	"github.com/gnolang/gno/gnovm/stdlibs/testing/repl"
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
	cmd := exec.Command("go", "test", "-coverpkg="+pkgList, "-v", "-coverprofile=coverage.out", "./...")
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

// // parseCoverageFile는 coverage.out 파일에서, 특정 함수 이름이 포함된 라인의 세 번째 필드를
// // 파싱하여 커버리지 값을 반환합니다.
// func parseCoverageFile(filename, funcName string) (float64, error) {
// 	cmd := exec.Command("go", "tool", "cover", "-func="+filename)
// 	var out bytes.Buffer
// 	cmd.Stdout = &out
// 	cmd.Stderr = &out

// 	err := cmd.Run()
// 	if err != nil {
// 		return 0, fmt.Errorf("failed to analyze coverage file: %v\nOutput: %s", err, out.String())
// 	}

// 	lines := strings.Split(out.String(), "\n")
// 	for _, line := range lines {
// 		if strings.Contains(line, funcName) {
// 			parts := strings.Fields(line)
// 			if len(parts) >= 3 {
// 				var coverage float64
// 				fmt.Sscanf(parts[2], "%f", &coverage)
// 				return coverage, nil
// 			}
// 		}
// 	}
// 	return 0, fmt.Errorf("function %s not found in coverage report", funcName)
// }

// // 테스트할 Gno 실행 함수 (예시)
// func testingFunction() {
// 	repl.RunGnoExpr(`func main() int {
// 	println("Hello from Gno!")
// 	return 1
// 	// 더 복잡한 코드 추가 가능
// }`)
// }

func getCovOfGnovm() {
	result, err := repl.RunGNOinGo(`(func() int {
		println("Hello from Gno!!!!!!!!")
		// 더 복잡한 코드 추가 가능
		return 1
	})()`)
	if err != nil {
		println("ERROR발생:", err)
	} else {
		println("실행 결과:", result)
	}
}

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

func main() {
	println("start Main")

	// 1. 커버리지 측정 실행 (github.com/gnolang/gno/gnovm/pkg/gnolang/ 하위의 패키지들에 대해서)
	err := getCoverage()
	if err != nil {
		fmt.Println("Error running coverage test:", err)
		return
	}

	// 3. coverage.out 파일 전체에서,
	//    (a) machine.go에 속한 라인만 필터링하고,
	//    (b) 그 중 세 번째 필드(실행 횟수)가 0이 아닌 라인만 남깁니다.
	data, err := os.ReadFile("coverage.out")
	if err != nil {
		fmt.Println("Error reading coverage.out:", err)
		return
	}
	allFiltered := filterNonZeroLines(string(data))
	machineFiltered := filterMachineCoverage(allFiltered)

	fmt.Println("Filtered coverage lines (machine.go only, execution count nonzero):")
	fmt.Println(machineFiltered)
}
