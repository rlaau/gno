package testing

import (
	"bytes"
	"strconv"
)

type (
	// internalHash represents a value that primarily changes coverage based on hashing.
	internalHash uint64

	// HashNumber represents the final value that coverage changes to
	// (based on the unique value from hashNumberCounter).
	HashNumber uint64

	// hashNumberCounter is a counter used to assign unique hashNumbers.
	hashNumberCounter struct {
		counter HashNumber
	}
)

type (
	// Coverage: array of coveredLine
	Coverage []CoveredLine

	// CoveredLine: single covered line
	CoveredLine struct {
		coName string
		coLine int
	}
)

// ----------------------------------------
// FuzzHasher: main struct
// ----------------------------------------
type FuzzHasher struct {
	HashNumber2Internal     *[MaxCapacity]internalHash  // Table: hashNumber -> internalHash
	internal2Cov            map[internalHash]Coverage   // Table: internalHash -> Coverage
	internalHash2hashNumber map[internalHash]HashNumber // Table: internalHash -> hashNumber
	hashNumberCounter       *hashNumberCounter          // Counter for unique hashNumbers

	// coverageCache map[string]hashNumber  // coverage -> hashNumber
}

// NewHashNumberCounter creates a new hashNumberCounter with given initial counter value.
func NewHashNumberCounter(counter HashNumber) *hashNumberCounter {
	return &hashNumberCounter{
		counter: counter,
	}
}

// NewFuzzHasher creates and initializes a new fuzzHasher instance.
func NewFuzzHasher() *FuzzHasher {
	return &FuzzHasher{
		HashNumber2Internal:     &[MaxCapacity]internalHash{},
		internal2Cov:            make(map[internalHash]Coverage),
		internalHash2hashNumber: make(map[internalHash]HashNumber),
		hashNumberCounter:       NewHashNumberCounter(0),
	}
}

// ----------------------------------------
// registerCoverage2HashNumber
// ----------------------------------------
// 1) computes internalHash from coverage
// 2) inserts coverage into internal2Cov
// 3) obtains hashNumber (unique ID)
// 4) updates hashNumber2Internal
// 5) returns the assigned hashNumber
func (fh *FuzzHasher) registerCoverage2HashNumber(coverage Coverage) HashNumber {
	ih := getInternalHash(coverage) // compute internalHash
	fh.internal2Cov[ih] = coverage

	hn := fh.countHashNumber(ih)
	fh.HashNumber2Internal[hn] = ih
	return hn
}

// countHashNumber assigns a unique hashNumber to the given internalHash.
// If it exists, returns existing; otherwise create new.
// starting point is 0
func (fh *FuzzHasher) countHashNumber(ih internalHash) HashNumber {
	if val, exists := fh.internalHash2hashNumber[ih]; exists {
		// if already known, return
		return val
	}
	fh.internalHash2hashNumber[ih] = fh.hashNumberCounter.counter
	current := fh.hashNumberCounter.counter
	fh.hashNumberCounter.counter++
	return current
}

// hashNumber2Coverage: given a hashNumber -> retrieve Coverage
func (fh *FuzzHasher) hashNumber2Coverage(hn uint) Coverage {
	ih := fh.HashNumber2Internal[hn]
	return fh.internal2Cov[ih]
}

// ----------------------------------------
// getInternalHash: coverage -> xxHash64
// ----------------------------------------
// replaces SHA256 usage; calls xxh64Sum (assume already implemented).
func getInternalHash(cv Coverage) internalHash {
	valBytes := coverageToBytes(cv)
	// seed=0 is typical, but can be anything
	valUint := xxh64Sum(valBytes, 0)
	return internalHash(valUint)
}

// ----------------------------------------
// coverageToBytes: optimized approach
// ----------------------------------------
// uses bytes.Buffer instead of strings.Builder
func coverageToBytes(cv Coverage) []byte {
	// each line -> coName length + ~few bytes

	var buf bytes.Buffer

	for _, line := range cv {
		// write coName as bytes
		buf.WriteString(line.coName)
		// write separator
		buf.WriteByte('|')

		// convert coLine to decimal
		// => intToString or strconv.Itoa
		buf.WriteString(strconv.Itoa(line.coLine))

		// separator
		buf.WriteByte('|')
	}
	return buf.Bytes()
}
