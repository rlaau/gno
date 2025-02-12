package repl

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	gno "github.com/gnolang/gno/gnovm/pkg/gnolang"
)

// nativePackages는 간단 예시로 "os", "fmt" 등록
func nativePackages(pkgPath string) (*gno.PackageNode, *gno.PackageValue) {
	switch pkgPath {
	case "os":
		pkg := gno.NewPackageNode("os", pkgPath, nil)
		pkg.DefineGoNativeValue("Stdin", os.Stdin)
		pkg.DefineGoNativeValue("Stdout", os.Stdout)
		pkg.DefineGoNativeValue("Stderr", os.Stderr)
		return pkg, pkg.NewPackage()
	case "fmt":
		pkg := gno.NewPackageNode("fmt", pkgPath, nil)
		pkg.DefineGoNativeValue("Println", func(a ...interface{}) (n int, err error) {
			res := fmt.Sprintln(a...)
			return os.Stdout.Write([]byte(res))
		})
		return pkg, pkg.NewPackage()
	case "encoding/json":
		pkg := gno.NewPackageNode("json", pkgPath, nil)
		// Go의 json.Marshal / json.Unmarshal 그대로 노출
		pkg.DefineGoNativeValue("Marshal", json.Marshal)
		pkg.DefineGoNativeValue("Unmarshal", json.Unmarshal)
		// 필요하면 json.NewDecoder, json.NewEncoder 등도 추가 가능
		return pkg, pkg.NewPackage()
		// etc ...
	default:
		return nil, nil
	}
}

// loadPackages는 rootDir/gnovm/stdlibs/pkgPath 등에서 .gno 파일을 읽고 로딩
func loadPackages(rootDir string) func(pkgPath string, store gno.Store) (*gno.PackageNode, *gno.PackageValue) {
	return func(pkgPath string, store gno.Store) (*gno.PackageNode, *gno.PackageValue) {
		stdlibPath := filepath.Join(rootDir, "gnovm", "stdlibs", pkgPath)
		dirEntries, err := os.ReadDir(stdlibPath)
		if err != nil {
			return nil, nil
		}

		var files []string
		for _, de := range dirEntries {
			if !de.IsDir() && strings.HasSuffix(de.Name(), ".gno") {
				files = append(files, filepath.Join(stdlibPath, de.Name()))
			}
		}
		if len(files) == 0 {
			return nil, nil
		}

		memPkg := gno.MustReadMemPackageFromList(files, pkgPath)
		if memPkg.IsEmpty() {
			return nil, nil
		}

		// ephemeral machine
		m2 := gno.NewMachineWithOptions(gno.MachineOptions{
			PkgPath: "stdlibdynamic",
			Output:  os.Stdout,
			Store:   store,
		})
		pn, pv := m2.RunMemPackageWithOverrides(memPkg, true)
		return pn, pv
	}
}
