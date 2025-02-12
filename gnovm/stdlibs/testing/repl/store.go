package repl

import (
	gno "github.com/gnolang/gno/gnovm/pkg/gnolang"
)

// DynamicStore는 “memdb 없이 in-memory 스토어 + 동적 로더 콜백” 만 갖춘 최소 버전
type DynamicStore struct {
	Store    gno.Store
	OnLoad   func(pkgPath string, store gno.Store) (*gno.PackageNode, *gno.PackageValue)
	OnNative func(pkgPath string) (*gno.PackageNode, *gno.PackageValue)
}

// NewDynamicStore 생성
func NewDynamicStore(
	loader func(pkgPath string, store gno.Store) (*gno.PackageNode, *gno.PackageValue),
	native func(pkgPath string) (*gno.PackageNode, *gno.PackageValue),
) *DynamicStore {
	ds := &DynamicStore{
		Store:    gno.NewStore(nil, nil, nil), // backing store = nil (in-memory)
		OnLoad:   loader,
		OnNative: native,
	}
	ds.Store.SetPackageGetter(ds.getPackage)
	return ds
}

// getPackage는 pkgPath에 따라 OnNative / OnLoad 콜백을 호출
func (ds *DynamicStore) getPackage(pkgPath string, store gno.Store) (*gno.PackageNode, *gno.PackageValue) {
	// 1. native packages?
	if ds.OnNative != nil {
		pn, pv := ds.OnNative(pkgPath)
		if pn != nil {
			return pn, pv
		}
	}

	// 2. standard gno packages?
	if ds.OnLoad != nil {
		pn, pv := ds.OnLoad(pkgPath, store)
		if pn != nil {
			return pn, pv
		}
	}

	// not found
	return nil, nil
}
func MinimalContextEx(pkgPath string) interface{} {
	return &struct {
		PkgPath string
		ChainID string
	}{
		pkgPath,
		"dev-chain",
	}
}
