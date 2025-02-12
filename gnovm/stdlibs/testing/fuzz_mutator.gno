package testing

import "testing/parser"

type mutator struct {
	data map[hashNumber]mutSampleSet // key: hashNumber, value: mutSampleSet
}

type mutSample struct {
	seed     seed
	rootEnts []parser.RootEnt
}

type mutSampleSet struct {
	samples map[int]mutSample // Maintain ID-based dictionary
}

func (mss *mutSampleSet) add(id int, sample mutSample) {
	mss.samples[id] = sample
}

func (mss *mutSampleSet) isEmpty() bool {
	return len(mss.samples) == 0
}

func (mss *mutSampleSet) size() int {
	return len(mss.samples)
}

func (mss *mutSampleSet) getAll() []mutSample {
	values := make([]mutSample, 0, len(mss.samples))
	for _, sample := range mss.samples {
		values = append(values, sample)
	}
	return values
}

func (mss *mutSampleSet) getElById(id int) (*mutSample, bool) {
	sample, exists := mss.samples[id]
	return &sample, exists
}
