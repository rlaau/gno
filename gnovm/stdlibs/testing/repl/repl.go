package repl

import (
	"bytes"
	"fmt"
	"os"

	"github.com/gnolang/gno/gnovm/pkg/gnoenv"
	gno "github.com/gnolang/gno/gnovm/pkg/gnolang"
	"github.com/gnolang/gno/gnovm/pkg/test"
	"github.com/gnolang/gno/tm2/pkg/std"
)

func RunGNOFileInGo(gnoSource string) (string, error) {
	// 1. Gno 환경 루트
	rootDir := gnoenv.RootDir()

	// 2. 테스트용 스토어 생성
	_, testStore := test.Store(rootDir, true, os.Stdin, os.Stdout, os.Stderr)

	// 3. 머신 생성 옵션 설정
	pkgPath := "main"
	ctx := test.Context(pkgPath, std.Coins{})

	// 4. 실행 결과를 저장할 버퍼 생성
	var outputBuffer bytes.Buffer

	m := gno.NewMachineWithOptions(gno.MachineOptions{
		PkgPath: pkgPath,
		Output:  &outputBuffer, // 출력을 버퍼에 저장
		Input:   os.Stdin,
		Store:   testStore,
		Context: ctx,
		Debug:   false,
	})
	defer m.Release()

	// 5. Gno 코드를 파일 노드로 변환
	fileNode, err := gno.ParseFile("input.gno", gnoSource)
	if err != nil {
		return "", fmt.Errorf("ParseFile error: %w", err)
	}

	// 6. 파일 내의 선언들을 실행(등록)
	m.RunFiles(fileNode)

	// ★ 추가: main() 함수를 실제로 실행합니다.
	m.RunFunc("anomFunc")

	println("실행 되긴 했음`")

	// 7. 실행 결과를 문자열로 반환
	return outputBuffer.String(), nil
}

// RunGNOinGo는 Gno 익명 함수를 문자열로 받아 실행하고, 실행 결과(리턴값)를 문자열로 반환합니다.
func RunGNOinGo(expr string) (string, error) {
	// 1. Gno 환경의 루트 디렉터리를 결정합니다.
	rootDir := gnoenv.RootDir()

	// 2. 테스트용 스토어를 초기화합니다.
	_, testStore := test.Store(rootDir, true, os.Stdin, os.Stdout, os.Stderr)

	// 3. 기본 패키지 경로와 컨텍스트를 설정합니다.
	pkgPath := "main"
	ctx := test.Context(pkgPath, std.Coins{})

	// 4. 가상 머신을 생성합니다.
	m := gno.NewMachineWithOptions(gno.MachineOptions{
		PkgPath: pkgPath,
		Output:  os.Stdout,
		Input:   os.Stdin,
		Store:   testStore,
		Context: ctx,
		Debug:   false, // 필요에 따라 true로 설정
	})
	defer m.Release()

	// 5. runExpr를 사용하여 전달된 문자열 코드를 실행하고, 그 결과를 받습니다.
	result := runExpr(m, expr)
	return result, nil
}

// runExpr는 전달된 expr을 실행하고, 그 결과값을 문자열로 반환합니다.
func runExpr(m *gno.Machine, expr string) string {

	var resultStr string
	defer func() {
		if r := recover(); r != nil {
			println("패닉!!!!!!!!!!!!!!!!!!!!!")
			switch r := r.(type) {
			case gno.UnhandledPanicError:
				fmt.Printf("panic running expression %s: %v\nStacktrace: %s\n", expr, r.Error(), m.ExceptionsStacktrace())
			default:
				fmt.Printf("panic running expression %s: %v\nMachine State:%s\nStacktrace: %s\n", expr, r, m.String(), m.Stacktrace().String())
			}
			panic(r)
		}
	}()
	//TODO 머스트파싱?
	parsedExpr, err := gno.ParseExpr(expr)
	if err != nil {
		println("에러:")
		panic(fmt.Errorf("could not parse: %w", err))
	}
	res := m.Eval(parsedExpr)
	// 결과 슬라이스를 문자열로 변환합니다.
	resultStr = fmt.Sprintf("%v", res)
	println("결과:", resultStr)
	return resultStr
}

// // /////////////////////
// // runGnoExpr는 expr 문자열을 받아서,
// // 1) "package main\n\n" + expr 내용을 갖는 main.gno 파일을 생성하고,
// // 2) "gno run ." 명령어를 실행하여 해당 파일을 실행한 후,
// // 3) 실행이 완료되면 main.gno 파일을 삭제합니다.
// func RunGnoExpr(expr string) error {
// 	// 생성할 파일 이름과 내용 정의
// 	fileName := "main.gno"
// 	content := "package main\n\n" + expr

// 	// main.gno 파일 생성
// 	if err := os.WriteFile(fileName, []byte(content), 0644); err != nil {
// 		return fmt.Errorf("failed to write %s: %w", fileName, err)
// 	}

// 	// 실행이 완료된 후 main.gno 파일을 삭제하기 위한 defer
// 	defer func() {
// 		if err := os.Remove(fileName); err != nil {
// 			fmt.Fprintf(os.Stderr, "warning: failed to remove %s: %v\n", fileName, err)
// 		}
// 	}()

// 	// "gno run ." 명령어 실행
// 	cmd := exec.Command("gno", "run", ".")
// 	cmd.Stdout = os.Stdout
// 	cmd.Stderr = os.Stderr
// 	if err := cmd.Run(); err != nil {
// 		return fmt.Errorf("failed to execute gno run .: %w", err)
// 	}

// 	return nil
// }

// func main() {
// 	// 예시: main.gno 파일 내에 main() 함수가 포함된 Gno 코드를 실행
// 	expr := `
// func main() {
// 	println("Hello from Gno!")
// 	// 여기에 더 복잡한 코드를 추가할 수 있습니다.
// }`

// 	if err := runGnoExpr(expr); err != nil {
// 		fmt.Println("Error:", err)
// 	}
// }
