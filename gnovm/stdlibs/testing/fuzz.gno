package testing

import (
	"errors"
	"fmt"
	"os"
	"strconv"
	"strings"
	"testing/fuzzing"
)

// TODO: 현재 동적 조절까진 가능

var SomeNumber int = int(unixNano())

type (
	// Runner is the type of the target function that f.Fuzz will execute.
	Runner func(*T, ...interface{})

	// F is the structure used for fuzzing.
	F struct {
		manager              *fuzzing.FuzzManager // Manages seeds and coverage for fuzzing, sorting and organizing them to quickly find the next input candidate.
		hasher               *fuzzing.FuzzHasher  // Assigns unique hashNumbers to coverage used in fuzzing.
		logger               *fuzzing.FuzzLogger  // Logs and outputs crash cases found during fuzzing.
		corpus               []fuzzing.Seed       // "Real seeds" added through f.Add.
		msgs                 []string             // Stores log messages for reporting.
		failed               bool                 // Indicates whether the fuzzing has encountered a failure.
		ff                   Runner               // The target function for f.Fuzz.
		isFuzzed             bool                 // Monitors whether f.Fuzz has been called.
		seedCount            uint                 // Counts the number of seeds attempted.
		stringByteCandidates []int                // Records the indices of string and []byte arguments among Runner's args.
		dur                  string               // Records the time taken for fuzzing.
		// For command-line tests
		verbose bool // Determines the frequency of logging based on CLI input.
		trials  uint // Number of iterations to run the fuzzing process.
	}
)

// Add adds initial seeds to the f.corpus.
func (f *F) Add(args ...interface{}) {
	if f.isFuzzed {
		panic("Add after Fuzz")
	}
	var values []interface{}
	var types []fuzzing.SupportedType
	if len(args) == 0 {
		panic("zero-argument is denied")
	}
	for i := range args {
		t, e := typeof(args[i])
		if e != nil {
			panic("not supported type")
		}
		values = append(values, args[i])
		types = append(types, t)
	}

	if f.manager.SeedType == nil {
		f.manager.SeedType = types
	} else {
		if !isSliceEqual(f.manager.SeedType, types) {
			panic("added arguments not equal together")
		}
	}
	f.seedCount++
	f.corpus = append(f.corpus, fuzzing.Seed{
		Pid:           f.seedCount,
		Id:            f.seedCount,
		Gen:           1,
		IsCoordinated: false,
		Content:       values,
	})
}

// typeof takes an interface{} and returns its type and whether it is supported.
func typeof(arg interface{}) (fuzzing.SupportedType, error) {
	switch arg.(type) {
	case []byte:
		return fuzzing.ByteArray, nil
	case string:
		return fuzzing.String, nil
	case bool:
		return fuzzing.Bool, nil
	case byte:
		return fuzzing.Byte, nil
	case rune:
		return fuzzing.Rune, nil
	case float32:
		return fuzzing.Float32, nil
	case float64:
		return fuzzing.Float64, nil
	case int:
		return fuzzing.Int, nil
	case int8:
		return fuzzing.Int8, nil
	case int16:
		return fuzzing.Int16, nil
	// deduplication because int32 and rune are of the same type
	// case int32:
	//      return Int32, nil
	case int64:
		return fuzzing.Int64, nil
	case uint:
		return fuzzing.Uint, nil
	// deduplication
	// case uint8:
	//      return Uint8, nil
	case uint16:
		return fuzzing.Uint16, nil
	case uint32:
		return fuzzing.Uint32, nil
	case uint64:
		return fuzzing.Uint64, nil
	default:
		return "", errors.New("unsupported type:")
	}
}

// isSliceEqual checks if two slices of supportedType are equal.
func isSliceEqual(a, b []fuzzing.SupportedType) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}

// Fuzz formats the f.manager using seeds received via f.Add and receives the target function to run via f.Fuzz.
//
// f.Fuzz then repeatedly:
// 1) Pops input from the f.manager
// 2) Generates evolved input from the popped input
// 3) Simulates and logs evolved input to the target function
// 4) Coordinates input to the manager
// 5) If an error occurs or trials (iterations) are completed, it outputs the result and terminates.
func (f *F) Fuzz(run Runner) {
	if !f.isFuzzed {
		f.isFuzzed = true
	} else {
		panic("fuzz called more than once")
	}

	// Format machine
	f.ff = run
	for _, corp := range f.corpus {
		corp = f.simulateFF(corp)
		if f.failed {
			f.handleFail()
			return
		}

		hashNumber := corp.HashNumber
		f.manager.Inithashnumber = append(f.manager.Inithashnumber, hashNumber)
		endInfo := f.manager.CoordinateSeed(corp)
		if endInfo.CompleteTrials {
			f.reportF()
			return
		}
		if endInfo.MaxedCAPACITY {

			f.migrateMachines()
			continue
		}

	}

	// Guidelines for evolving seeds.
	// In insertDelete, and minimazeAndLogInput functions, string and []byte types are treated specially.
	stringByteCandidates := []int{}
	for i, t := range f.manager.SeedType {
		if t == fuzzing.String || t == fuzzing.ByteArray {
			stringByteCandidates = append(stringByteCandidates, i)
		}
	}

	f.stringByteCandidates = stringByteCandidates
	fmt.Fprintln(os.Stderr, "Run trials...")

	// Independently generate inputs from the initially formatted seeds.
	for i := 0; i < len(f.corpus); i++ {
		hn := f.manager.Inithashnumber[i]
		initSeed := []fuzzing.Seed{f.manager.PopInitSeedByHN(hn)}
		isEnd := f.updateMachines(initSeed)
		if isEnd {
			return
		}
	}

	for {
		// 1) Pop input from the manager
		parentSeeds := f.manager.PopSeeds()
		// 2) Generate evolved input from the popped input
		// 3) Simulate and log evolved input to the target function
		// 4) Coordinate input to the manager repeatedly
		isEnd := f.updateMachines(parentSeeds)
		// 5) If an error occurs or trials (iterations) are completed, output the result and terminate.
		if isEnd {
			return
		}
	}
}

// simulateFF simulates the target function with the given seed.
func (f *F) simulateFF(seed fuzzing.Seed) fuzzing.Seed {
	coverage, err, isPanic, panicMsg := monitor(f.ff, seed.Content)

	// Compute seed.hn
	// This completes the status change of the seed before logging
	hashNumber := f.hasher.RegisterCoverage2HashNumber(coverage)
	seed.HashNumber = hashNumber
	if isPanic {
		tr := fuzzing.TestResult{
			PanicOccurred: true,
			PanicMessage:  panicMsg,
			Error:         err,
		}
		f.logger.AddCase(seed, tr)
		f.manager.CoordinateSeed(seed)
		f.Fail()
	}
	if err != nil {
		tr := fuzzing.TestResult{
			PanicOccurred: false,
			PanicMessage:  "",
			Error:         err,
		}
		f.logger.AddCase(seed, tr)
		f.manager.CoordinateSeed(seed)
		f.Fail()
	}
	return seed
}

// monitor runs the target function and captures coverage, errors, and panics.
// TODO: Make sure to revise coverage here!!!
// TODO: I've hard-coded coverage according to the test results here. This will be corrected later!!
func monitor(run Runner, content []interface{}) (coverage fuzzing.Coverage, err error, isPanic bool, panicMsg string) {
	isPanic = false
	panicMsg = ""
	err = nil
	coverage = fuzzing.Coverage{}
	defer func() {
		if r := recover(); r != nil {

			// TODO: part 1
			coverage = fuzzing.GetCoverageOfrunner(content)
			isPanic = true
			if err, ok := r.(error); ok {
				panicMsg = err.Error()
				return
			}
			if s, ok := r.(string); ok {

				panicMsg = s
				return
			}

			panicMsg = "unknown panic"
		}
	}()
	t := NewT("fuzzing")
	// Ensuring the immutability of content
	copied := make([]interface{}, len(content))
	for i, v := range content {
		copied[i] = v
	}
	run(t, copied...)
	info := t.GetResult()
	if info.Failed {
		err = errors.New(string(info.Output))
	}
	// TODO: part 2
	// TODO: Modifying this function to get real coverage
	// TODO: It's just pseudo-coverage of some function
	coverage = fuzzing.GetCoverageOfrunner(content)

	return coverage, err, isPanic, panicMsg
}

// Fail marks the function as having failed but continues execution.
func (f *F) Fail() {
	f.failed = true
}

// handleFail handles a failure during fuzzing by logging and minimizing the input.
func (f *F) handleFail() {
	fmt.Fprintln(os.Stderr, "\n--- FAIL:")

	f.logger.ReportLastFailingInput()
	lastCrashCase := f.logger.GetLastCrashCase()
	f.minimazeAndLogInput(lastCrashCase.RawContent)
	f.logger.ReportLastCrashCase()
	minimaizedCase := f.logger.GetLastCrashCase()
	hn := minimaizedCase.HashNumber
	coverage := f.hasher.HashNumber2Coverage(hn)
	if f.verbose {
		fmt.Fprintln(os.Stderr, "\n--- Trace:")
		fmt.Fprintf(os.Stderr, "%s\n", coverageToString(coverage))
	} else {
		fmt.Fprintln(os.Stderr, "\n--- Trace:")
		fmt.Fprintf(os.Stderr, "Last covered line: function \"%s\" in line %d\n", coverage[len(coverage)-1].CoName, coverage[len(coverage)-1].CoLine)
	}
	if f.verbose {
		f.analyzeResult()
	}
	return
}

func (f *F) analyzeResult() {
	fmt.Fprintln(os.Stderr, "\n--- Analytics:")
	if f.verbose {

		hashNumber := 0
		for f.manager.HashNumber2Priority[hashNumber] != 0 {
			fmt.Fprintf(os.Stdout, "coverage %d: [%d frequency | %d actual storage] \n", hashNumber, f.manager.HashNumber2Priority[hashNumber], len(f.manager.HashNumber2Seeds[hashNumber].Data))
			dataLen := len(f.manager.HashNumber2Seeds[hashNumber].Data)
			sampleCount := getSampleCount(dataLen) // 샘플 개수 결정
			fmt.Fprint(os.Stdout, "- ")
			for j := 0; j < sampleCount; j++ {
				index := j * (dataLen / sampleCount) // 고른 간격으로 인덱스 선택
				s := f.manager.HashNumber2Seeds[hashNumber].Data[index]

				if j > 0 {
					fmt.Fprint(os.Stdout, ", ")
				}
				fmt.Fprintf(os.Stdout, "%v", fuzzing.ContentToString(s.Content))
			}
			fmt.Fprintln(os.Stdout) // 개행 추가

			hashNumber++
		}
	}
}

// 샘플 개수를 결정하는 함수
func getSampleCount(length int) int {
	switch {
	case length >= 4096:
		return 5
	case length >= 512:
		return 4
	case length >= 64:
		return 3
	case length >= 8:
		return 2
	default:
		return 1
	}
}

// coverageToString converts coverage data to a string representation.
func coverageToString(coverage fuzzing.Coverage) string {
	var sb strings.Builder
	sb.WriteString("[")
	count := 0
	for i, line := range coverage {
		sb.WriteString("{co_name: ")
		sb.WriteString(line.CoName)
		sb.WriteString(", co_line: ")
		sb.WriteString(strconv.Itoa(line.CoLine))
		sb.WriteString("}")
		count++
		if i < len(coverage)-1 {
			if count%3 == 0 {
				sb.WriteString(", \n")
			} else {
				sb.WriteString(", ")
			}
		}
	}
	sb.WriteString("]")
	return sb.String()
}

// minimazeAndLogInput minimizes the input that caused a failure and logs it.
// To be precise, it serves to reduce the length of the input string.
func (f *F) minimazeAndLogInput(seedContent []interface{}) {
	minimazalbeIdXs := []int{}
	for i, t := range f.manager.SeedType {
		if t == fuzzing.ByteArray {
			minimazalbeIdXs = append(minimazalbeIdXs, i)
		} else if t == fuzzing.String {
			minimazalbeIdXs = append(minimazalbeIdXs, i)
		}
	}
	if len(minimazalbeIdXs) < 1 {
		return
	}
	sample := seedContent
	content := make([]interface{}, len(sample))
	for i, v := range sample {
		content[i] = v
	}
	// Minimize by progressive, preserveness traits of error
	for {
		progressed, isProgressed, occeredPoint := f.checkProgress(content, minimazalbeIdXs)
		if !isProgressed {
			break
		}
		content = progressed
		minimazalbeIdXs = minimazalbeIdXs[occeredPoint:]
	}
	sampleSeed := fuzzing.Seed{
		Content: content,
	}
	// Confirm and log error
	f.simulateFF(sampleSeed)
	fmt.Fprintln(os.Stderr, "\n--- Minimaized input:")
}

// checkProgres checks if the input can be reduced by one more step while preserving the error.
// If it is reduced, it returns the reduced value by one step.
// returns (reducedInput, isReduced, occeredPoint)
func (f *F) checkProgress(content []interface{}, minimizableIdXs []int) ([]interface{}, bool, int) {
	changed := false

	for occeredPoint, idx := range minimizableIdXs {
		sOrb := content[idx]
		var candidates [][]byte
		var isString bool

		switch v := sOrb.(type) {
		case string:
			if len(v) < 1 {
				continue
			}
			isString = true
			candidates = generateCandidates([]byte(v))
		case []byte:
			if len(v) < 1 {
				continue
			}
			isString = false
			candidates = generateCandidates(v)
		default:
			panic("internal logic error")
		}

		for _, candidate := range candidates {
			tester := make([]interface{}, len(content))
			copy(tester, content)

			if isString {
				tester[idx] = string(candidate)
			} else {
				tester[idx] = candidate
			}

			if f.checkPreserve(tester).errorIsPreserved {
				changed = true
				return tester, changed, occeredPoint
			}
		}
	}
	return content, changed, 0
}

// generateCandidates returns a new slice with the character at each index removed from a given byte slice.
func generateCandidates(b []byte) [][]byte {
	candidates := make([][]byte, 0, len(b))
	for i := 0; i < len(b); i++ {
		// Create a new slice that removes the character at a particular index
		candidate := append([]byte{}, b[:i]...)
		candidate = append(candidate, b[i+1:]...)
		candidates = append(candidates, candidate)
	}
	return candidates
}

type PreserveFailing struct {
	errorIsPreserved bool
	coverage         fuzzing.Coverage
	err              error
	isPanic          bool
	panicMsg         string
	hashNumber       fuzzing.HashNumber
}

// checkPreserve checks if the error is preserved after minimizing the input.
func (f *F) checkPreserve(content []interface{}) PreserveFailing {
	coverage, err, isPanic, panicMsg := monitor(f.ff, content)
	hashNumber := f.hasher.RegisterCoverage2HashNumber(coverage)
	if isPanic {
		return PreserveFailing{
			errorIsPreserved: true,
			coverage:         coverage,
			err:              err,
			isPanic:          true,
			panicMsg:         panicMsg,
			hashNumber:       hashNumber,
		}
	}
	if err != nil {
		return PreserveFailing{
			errorIsPreserved: true,
			coverage:         coverage,
			err:              err,
			isPanic:          false,
			panicMsg:         "",
			hashNumber:       hashNumber,
		}
	}
	return PreserveFailing{
		errorIsPreserved: false,
	}
}

// reportF reports the fuzzing results after successful completion.
func (f *F) reportF() {
	fmt.Fprintln(os.Stderr, "\n--- PASS:")
	fmt.Fprintf(os.Stderr, "Complete %d Trials\n", f.manager.InputCount)
	fmt.Fprintf(os.Stderr, "Inspected %d coverage\n", (f.manager.InspectingHashNumbers))
	if f.verbose {
		f.analyzeResult()
	}
}

// migrateMachines abstracts the existing f.manager and relocates the f.manager.
func (f *F) migrateMachines() {
	// Abstract existing f.manager
	summarizedSeeds := f.manager.Summarize()
	oldHashNumbers := []fuzzing.HashNumber{}
	for _, seed := range summarizedSeeds {
		oldHashNumbers = append(oldHashNumbers, seed.HashNumber)
	}
	coveragesOfSeeds := []fuzzing.Coverage{}
	for _, hn := range oldHashNumbers {
		coveragesOfSeeds = append(coveragesOfSeeds, f.hasher.HashNumber2Coverage(uint(hn)))
	}
	// Sort by re-registering existing seed coverage to the new hash machine
	// Return the value to the seed afterwards
	// The hash number of the seed is 0,1,2... and also registers 0,1,2 and coverage on the hash machine
	f.hasher = fuzzing.NewFuzzHasher()
	for i, cov := range coveragesOfSeeds {
		summarizedSeeds[i].HashNumber = f.hasher.RegisterCoverage2HashNumber(cov)
	}
	// Create and relocate a new FuzzManager
	prevInputCount := f.manager.InputCount
	substractedInputCount := int(prevInputCount) - len(summarizedSeeds)
	prevSeedType := make([]fuzzing.SupportedType, len(f.manager.SeedType))
	copy(prevSeedType, f.manager.SeedType)
	prevInitHashNumber := f.manager.Inithashnumber
	f.manager = fuzzing.NewFuzzManager(f.trials, uint(substractedInputCount))
	f.manager.Verbose = f.verbose
	f.manager.SeedType = prevSeedType
	f.manager.Inithashnumber = prevInitHashNumber
	for _, seed := range summarizedSeeds {
		f.manager.CoordinateSeed(seed)
	}
}

// updateMachines performs the following steps:
// 1) Generates evolved input from it's argument(parentSeeds)
// 2) Simulates and logs evolved input to the target function
// 3) Coordinates input to the fuzzManager and Indicates whether fuzzing should be terminated.
func (f *F) updateMachines(parentSeeds []fuzzing.Seed) bool {
	seedsMap := make(map[fuzzing.HashNumber]*[]fuzzing.Seed)
	// 1) Generate evolved input from the popped input
	childSeeds := fuzzing.Evolve(parentSeeds, &f.seedCount, f.stringByteCandidates)
	// 2) Simulate and log evolved input to the target function
	// If failure occurs, log it and terminate
	for _, child := range childSeeds {
		child = f.simulateFF(child)
		if f.failed {
			f.handleFail()
			return true
		}
		hn := child.HashNumber
		if _, exists := seedsMap[hn]; !exists {
			seedsMap[hn] = &[]fuzzing.Seed{}
		}
		seeds := seedsMap[hn]
		*seeds = append(*seeds, child)
	}
	// 3) Coordinate input to the fuzzManager
	for hn, seeds := range seedsMap {
		if len(*seeds) == 1 {
			concreteEndInfo := f.manager.CoordinateSeed((*seeds)[0])
			flag := f.handleEndInfo(concreteEndInfo, parentSeeds)
			if flag {
				return true
			}
		} else if len(*seeds) == 2 {
			seedArray := *(seeds)
			concreteEndInfo1 := f.manager.CoordinateSeed(seedArray[0])
			flag := f.handleEndInfo(concreteEndInfo1, parentSeeds)
			if flag {
				return true
			}
			concreteEndInfo2 := f.manager.CoordinateSeed(seedArray[1])
			flag = f.handleEndInfo(concreteEndInfo2, parentSeeds)
			if flag {
				return true
			}
		} else {
			// To prevent excessive coordinating of seeds sharing the same hashNumber,
			// only some seeds are concretely stored.
			// When coordinating all seeds of a specific hashNumber,
			// seeds that should naturally be selected are continuously deferred.
			// Coordinate up to 2 seeds concretely, and abstractly coordinate the rest to only affect priority.
			// If more than 2 seeds share the same hashNumber, randomly select 2 to coordinate
			// and abstractly coordinate the rest to only affect priority.
			seedArray := *(seeds)
			absNumber := uint(len(seedArray) - 2)
			absEndInfo := f.manager.CoordinateAbstraction(hn, absNumber)
			flag := f.handleEndInfo(absEndInfo, parentSeeds)
			if flag {
				return true
			}
			selectedIdx1 := fuzzing.RandRange(0, int64(len(seedArray)))
			selectedIdx2 := fuzzing.RandRange(0, int64(len(seedArray)))
			if selectedIdx1 == selectedIdx2 {
				if selectedIdx1 == 0 {
					selectedIdx2 = 1
				} else {
					selectedIdx2 = selectedIdx1 - 1
				}
			}
			concreteEndInfo1 := f.manager.CoordinateSeed(seedArray[selectedIdx1])
			flag = f.handleEndInfo(concreteEndInfo1, parentSeeds)
			if flag {
				return true
			}
			concreteEndInfo2 := f.manager.CoordinateSeed(seedArray[selectedIdx2])
			flag = f.handleEndInfo(concreteEndInfo2, parentSeeds)
			if flag {
				return true
			}
		}
	}
	// After coordinating the evolved child seeds, coordinate the parents
	for _, p := range parentSeeds {
		f.manager.CoordinateSeed(p)
	}
	return false
}

// handleEndInfo handles the endInfo returned by coordinateSeed or coordinateAbstraction.
func (f *F) handleEndInfo(endInfo fuzzing.EndInfo, parentSeeds []fuzzing.Seed) bool {
	if endInfo.CompleteTrials {
		f.reportF()
		return true
	}
	if endInfo.MaxedCAPACITY {
		for _, p := range parentSeeds {
			f.manager.CoordinateSeed(p)
		}
		f.migrateMachines()
		return false
	}
	return false
}

// NewF creates a new instance of F with the specified verbosity and number of trials.
func NewF(verbose bool, trials uint) *F {
	newManager := fuzzing.NewFuzzManager(trials, 0)
	newManager.Verbose = verbose
	newHasher := fuzzing.NewFuzzHasher()
	newLogger := fuzzing.NewFuzzLogger()
	return &F{
		verbose:   verbose,
		manager:   newManager,
		hasher:    newHasher,
		logger:    newLogger,
		isFuzzed:  false,
		seedCount: 0,
		trials:    trials,
	}
}
