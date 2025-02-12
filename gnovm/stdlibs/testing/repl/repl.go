package repl

import (
	"bytes"
	"fmt"
	"os"

	"github.com/gnolang/gno/gnovm/pkg/gnoenv"
	gnolang "github.com/gnolang/gno/gnovm/pkg/gnolang"
	gnl "github.com/gnolang/gno/gnovm/stdlibs/testing/gnl"
)

// X_runGNOFileInGoWithCoverage는 Gno 소스코드를 실행하고, 결과 문자열과
// 커버리지 정보를 콘솔에 출력합니다.
func X_runGNOFileInGoWithCoverage(gnoSource string) (string, error) {
	// 1) 매 실행마다 커버리지 비트맵 초기화
	gnl.ResetCoverageBitmap()

	// 2) Gno rootDir
	rootDir := gnoenv.RootDir()

	// 3) DynamicStore 생성
	//    - nativePackages: os, fmt 등 Go Native
	//    - loadPackages: rootDir/gnovm/stdlibs/pkgPath 에서 .gno 로드
	ds := NewDynamicStore(
		loadPackages(rootDir), // OnLoad
		nativePackages,        // OnNative
	)

	// 4) MinimalContextEx 생성 (체인ID 등)
	pkgPath := "rlaau"
	ctx := MinimalContextEx(pkgPath)

	// 5) 결과 버퍼
	var outputBuffer bytes.Buffer

	// 6) Machine 생성
	m := gnl.NewMachineWithOptions(gnolang.MachineOptions{
		PkgPath: pkgPath,
		Output:  &outputBuffer, // 결과를 버퍼에 적재
		Input:   os.Stdin,
		Store:   ds.Store, // DynamicStore의 gno.Store
		Context: ctx,
		Debug:   false,
	})
	defer m.Release()

	// 7) Gno 코드를 파싱 (gnl.ParseFile)
	fileNode, err := gnl.ParseFile("input.gno", gnoSource)
	if err != nil {
		return "", fmt.Errorf("ParseFile error: %w", err)
	}

	// 8) 파일 내 선언들 등록
	m.RunFiles(fileNode)

	// 9) anomFunc 실행 (또는 main)
	m.RunFunc("anomFunc")

	// 10) 커버리지 출력 (index=xxx, count=yyy)
	gnl.PrintCoverageBitmap()
	fmt.Println("=== 실행 완료 ===")

	// 11) 결과 반환
	return outputBuffer.String(), nil
}

// package repl

// import (
// 	"bytes"
// 	"fmt"
// 	"os"

// 	"github.com/gnolang/gno/gnovm/pkg/gnoenv"
// 	gnolang "github.com/gnolang/gno/gnovm/pkg/gnolang"
// 	"github.com/gnolang/gno/gnovm/pkg/test"
// 	gnl "github.com/gnolang/gno/gnovm/stdlibs/testing/gnl"
// 	"github.com/gnolang/gno/tm2/pkg/std"
// )

// func RunGNOFileInGo(gnoSource string) (string, error) {
// 	// 1. Gno 환경 루트
// 	rootDir := gnoenv.RootDir()

// 	// 2. 테스트용 스토어 생성
// 	_, testStore := test.Store(rootDir, true, os.Stdin, os.Stdout, os.Stderr)

// 	// 3. 머신 생성 옵션 설정
// 	pkgPath := "rlaau"
// 	ctx := test.Context(pkgPath, std.Coins{})

// 	// 4. 실행 결과를 저장할 버퍼 생성
// 	var outputBuffer bytes.Buffer

// 	m := gnl.NewMachineWithOptions(gnolang.MachineOptions{
// 		PkgPath: pkgPath,
// 		Output:  &outputBuffer, // 출력을 버퍼에 저장
// 		Input:   os.Stdin,
// 		Store:   testStore,
// 		Context: ctx,
// 		Debug:   false,
// 	})
// 	defer m.Release()

// 	// 5. Gno 코드를 파일 노드로 변환
// 	fileNode, err := gnl.ParseFile("input.gno", gnoSource)
// 	if err != nil {
// 		return "", fmt.Errorf("ParseFile error: %w", err)
// 	}

// 	// 6. 파일 내의 선언들을 실행(등록)
// 	m.RunFiles(fileNode)

// 	// ★ 추가: main() 함수를 실제로 실행합니다.
// 	m.RunFunc("anomFunc")

// 	println("실행 되긴 했음`")

// 	// 7. 실행 결과를 문자열로 반환
// 	return outputBuffer.String(), nil
// }

// // RunGNOinGo는 Gno 익명 함수를 문자열로 받아 실행하고, 실행 결과(리턴값)를 문자열로 반환합니다.
// func RunGNOinGo(expr string) (string, error) {
// 	// 1. Gno 환경의 루트 디렉터리를 결정합니다.
// 	rootDir := gnoenv.RootDir()

// 	// 2. 테스트용 스토어를 초기화합니다.
// 	_, testStore := test.Store(rootDir, true, os.Stdin, os.Stdout, os.Stderr)

// 	// 3. 기본 패키지 경로와 컨텍스트를 설정합니다.
// 	pkgPath := "main"
// 	ctx := test.Context(pkgPath, std.Coins{})

// 	// 4. 가상 머신을 생성합니다.
// 	m := gnl.NewMachineWithOptions(gnolang.MachineOptions{
// 		PkgPath: pkgPath,
// 		Output:  os.Stdout,
// 		Input:   os.Stdin,
// 		Store:   testStore,
// 		Context: ctx,
// 		Debug:   false, // 필요에 따라 true로 설정
// 	})
// 	defer m.Release()

// 	// 5. runExpr를 사용하여 전달된 문자열 코드를 실행하고, 그 결과를 받습니다.
// 	result := runExpr(gnl.WrapGnoMachine(m), expr)
// 	return result, nil
// }

// // runExpr는 전달된 expr을 실행하고, 그 결과값을 문자열로 반환합니다.
// func runExpr(m *gnl.Machine, expr string) string {

// 	var resultStr string
// 	defer func() {
// 		if r := recover(); r != nil {
// 			println("패닉!!!!!!!!!!!!!!!!!!!!!")
// 			switch r := r.(type) {
// 			case gnolang.UnhandledPanicError:
// 				fmt.Printf("panic running expression %s: %v\nStacktrace: %s\n", expr, r.Error(), m.ExceptionsStacktrace())
// 			default:
// 				fmt.Printf("panic running expression %s: %v\nMachine State:%s\nStacktrace: %s\n", expr, r, m.String(), m.Stacktrace().String())
// 			}
// 			panic(r)
// 		}
// 	}()
// 	//TODO 머스트파싱?
// 	parsedExpr, err := gnl.ParseExpr(expr)
// 	if err != nil {
// 		println("에러:")
// 		panic(fmt.Errorf("could not parse: %w", err))
// 	}
// 	res := m.Eval(parsedExpr)
// 	// 결과 슬라이스를 문자열로 변환합니다.
// 	resultStr = fmt.Sprintf("%v", res)
// 	println("결과:", resultStr)
// 	return resultStr
// }
