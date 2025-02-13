package mutating

import "testing/fuzzing"

type Mutator struct {
	data map[fuzzing.HashNumber]MutSampleSet // key: hashNumber, value: mutSampleSet
}

type MutSample struct {
	seed     fuzzing.Seed
	rootEnts []RootEnt
}

type MutSampleSet struct {
	samples map[int]MutSample // Maintain ID-based dictionary
}

func (mss *MutSampleSet) add(id int, sample MutSample) {
	mss.samples[id] = sample
}

func (mss *MutSampleSet) isEmpty() bool {
	return len(mss.samples) == 0
}

func (mss *MutSampleSet) size() int {
	return len(mss.samples)
}

func (mss *MutSampleSet) getAll() []MutSample {
	values := make([]MutSample, 0, len(mss.samples))
	for _, sample := range mss.samples {
		values = append(values, sample)
	}
	return values
}

func (mss *MutSampleSet) getElById(id int) (*MutSample, bool) {
	sample, exists := mss.samples[id]
	return &sample, exists
}
