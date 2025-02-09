// Copyright 2015 go-fuzz project authors. All rights reserved.
// Use of this source code is governed by Apache 2 LICENSE that can be found in the LICENSE file.

package versifier

import (
	"fmt"
	"os"
	"strings"
	"testing"
)

func dump(data string) {
	v := BuildVerse(nil, []byte(data))
	var sb strings.Builder
	v.Print(&sb)
	fmt.Fprintln(os.Stderr, testing.EscapedToString(sb.String()))
}

func TestNumber(t *testing.T) {
	dump(`ab 2e3 -10 def \xeb 명 kk=123 0x123 1e10 asd 1e2 22e-78 -11e72   `)
}

func TestLine(t *testing.T) {
	text := "line1\nline2\nline3"
	dump(text)
}

func TestList1(t *testing.T) {
	dump(`{"f1": "v1", "f2": "v2", "f3": "v3" }`)
}

func TestXML(t *testing.T) {
	xml := string("<item name=foo><prop name=price>100</prop></item>")
	dump(xml)
}

func TestList2(t *testing.T) {
	dump(`1,2.0,3e3`)
}

func TestBracket(t *testing.T) {
	dump(`[] [afal] (  ) (afaf)`)
}

func TestKeyValue(t *testing.T) {
	dump(`a=1 a=b   2  (aa=bb) a bb:cc [dd,a=b,c=d,e=f]`)
	dump(`:a`)
}

func TestHttps(t *testing.T) {
	dump("https://www.naver.com/search.naver?query=\xeb")
}

func TestGenerate(t *testing.T) {
	// 예: 이미 있는 문자열로 Verse를 구성
	v := BuildVerse(nil, []byte("https://www.naver.com/search.naver?query=12"))

	// 5번 정도 반복하며 랜덤 결과를 로그로 찍어보자
	for i := 0; i < 5; i++ {
		gen := v.Rhyme()
		t.Logf("Generated result %d: %q", i, gen)
	}
	xmlString := []byte("<item name=foo><prop name=price>100</prop></item>")
	xml := BuildVerse(nil, xmlString)
	for j := 0; j < 5; j++ {
		gen2 := xml.Rhyme()
		t.Logf("Generated result %d: %q", j, gen2)
	}
}
