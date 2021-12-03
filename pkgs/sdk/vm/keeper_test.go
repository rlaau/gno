package vm

import (
	"testing"

	"github.com/jaekwon/testify/assert"

	"github.com/gnolang/gno/pkgs/crypto"
	"github.com/gnolang/gno/pkgs/std"
)

func TestVMKeeper(t *testing.T) {
	env := setupTestEnv()
	ctx := env.ctx

	// Give "addr1" some gnots.
	addr := crypto.AddressFromPreimage([]byte("addr1"))
	acc := env.acck.NewAccountWithAddress(ctx, addr)
	env.acck.SetAccount(ctx, acc)
	env.bank.SetCoins(ctx, addr, std.MustParseCoins("10gnot"))
	assert.True(t, env.bank.GetCoins(ctx, addr).IsEqual(std.MustParseCoins("10gnot")))

	// Create test package.
	files := []std.MemFile{
		{"init.go", `
package test

import "std"

func init() {
}

func Echo(msg string) string {
	addr := std.GetCaller()
	send := std.GetSend()
	err := std.Send(addr, send)
	if err != nil {
		return "error:"+err.Error()
	} else {
		return "echo:"+msg
	}
}`},
	}
	pkgPath := "gno.land/r/test"
	msg1 := NewMsgAddPackage(addr, pkgPath, files)
	err := env.vmk.AddPackage(ctx, msg1)

	// Run Echo function.
	coins := std.MustParseCoins("10gnot")
	msg2 := NewMsgCall(addr, coins, pkgPath, "Echo", []string{"hello world"})
	res, err := env.vmk.Call(ctx, msg2)
	assert.NoError(t, err)
	assert.Equal(t, res, `("echo:hello world" string)`)
	// t.Log("result:", res)
}