package cov

import (
	"fmt"
	"os"
	"os/exec"
	"strings"
	"time"
)

func X_getCovOfSource(sourceCode string) string {
	startTotal := time.Now()
	startWrite := time.Now()
	if err := WriteCovTestFile(sourceCode); err != nil {
		fmt.Println("Error writing cov_test.go:", err)
		os.Exit(1)
	}
	fmt.Printf("✅ cov_test.go 파일 작성 완료 (소요 시간: %v)\n", time.Since(startWrite))
	fmt.Println("cov_test.go written successfully.")
	startCoverage := time.Now()
	err := getCoverage()
	if err != nil {
		fmt.Println("Error running coverage:", err)
		return "error occuered"
	}
	fmt.Printf("✅ 커버리지 측정 완료 (소요 시간: %v)\n", time.Since(startCoverage))
	//TODO: 데이터를 읽어서 파싱하는데 걸린 시간=> 0.9초임
	//TODO: 나머지  0.9초는 어디에...?
	// 2. coverage.out 파일 전체를 읽어들입니다.
	startRead := time.Now()
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
	fmt.Printf("✅ coverage.out 파일 읽기+분석 로직 (소요 시간: %v)\n", time.Since(startRead))
	// 5. 결과를 순차적으로 출력합니다.

	//fmt.Println("\n=== machine.go에 해당하는 커버리지 라인 ===")
	//fmt.Println(machineCoverage)
	fmt.Printf("✅총 소요요(소요 시간: %v)\n", time.Since(startTotal))
	return machineCoverage
}

func getCoverage() error {
	// 해당 패키지 목록 가져오기
	pkgList := "github.com/gnolang/gno/gnovm/stdlibs/testing/gnl"

	startBuild := time.Now()
	// ✅ 기존 바이너리 재사용하여 빌드 시간 절약
	if _, err := os.Stat("testbinary"); os.IsNotExist(err) {
		fmt.Println("Building test binary...")
		cmdBuild := exec.Command("go", "test", "-c", "-coverpkg="+pkgList, "-o", "testbinary")
		cmdBuild.Stdout = os.Stdout
		cmdBuild.Stderr = os.Stderr
		err := cmdBuild.Run()
		if err != nil {
			return fmt.Errorf("failed to build test binary: %v", err)
		}
	} else {
		fmt.Println("Using cached test binary")
	}
	fmt.Printf("✅ 빌드 실행시간 (소요 시간: %v)\n", time.Since(startBuild))

	// 1️⃣ 패키지 로드를 미리 수행하여 캐시 활용
	exec.Command("./testbinary", "-test.run=^$", "-test.count=1").Run()

	// 2️⃣ **병렬 실행 활성화 및 stdout 버퍼 최적화**
	startBinary := time.Now()
	cmdRun := exec.Command("./testbinary", "-test.v", "-test.parallel=4", "-test.count=1", "-test.coverprofile=coverage.out")

	// ✅ stdout을 직접 사용하여 실행 속도 최적화
	cmdRun.Stdout = os.Stdout
	cmdRun.Stderr = os.Stderr

	err := cmdRun.Run()
	fmt.Printf("✅ 바이너리 실행시간 (소요 시간: %v)\n", time.Since(startBinary))

	if err != nil {
		return fmt.Errorf("failed to run test binary: %v", err)
	}
	return nil
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
	// 1) cov_test.go 파일이 이미 존재하는지 확인
	existing, err := os.ReadFile("cov_test.go")
	if err == nil {
		// 2) 파일이 있고, 내용이 동일하다면 다시 쓰지 않음
		if string(existing) == content {
			fmt.Println("cov_test.go 파일이 이미 동일한 내용으로 존재합니다. 덮어쓰기를 생략합니다.")
			return nil
		}
	}
	// 3) 파일이 없거나 내용이 다르면 새로 작성
	fmt.Println("cov_test.go 파일 내용이 달라, 새로 작성합니다.")
	return os.WriteFile("cov_test.go", []byte(content), 0644)
}
