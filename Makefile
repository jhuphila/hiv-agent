.PHONY: install gold pipeline-gold evaluate clean test help

help:
	@echo "install       - create/update the hiv-agent conda env"
	@echo "gold          - run sierrapy fasta directly to build the Sierra ground-truth answer key"
	@echo "pipeline-gold - run translate_and_query.py to build a pipeline regression reference"
	@echo "test          - run pytest in the hiv-agent env -- not yet implemented"
	@echo "clean         - remove caches"

install:
	conda env create -f environment.yaml || conda env update -f environment.yaml

gold:               # Sierra-direct ground truth - one output JSON per FASTA in data/
	mkdir -p results/gold
	@for f in data/*.fasta; do \
		base=$$(basename $$f .fasta); \
		echo "Running Sierra on $$f -> results/gold/$$base.json"; \
		conda run -n hiv-agent sierrapy fasta $$f -o results/gold/$$base.json; \
	done

pipeline-gold:      # Wrapper script reference - regression check only, not primary eval ground truth
	conda run -n hiv-agent python .cursor/skills/sierrapy/translate_and_query.py \
		--data-dir data --results-dir results/pipeline-gold

test:
	conda run -n hiv-agent pytest

clean:
	rm -rf __pycache__ .pytest_cache
	find . -type d -name __pycache__ -prune -exec rm -rf {} +

# not yet implemented
# evaluate:
# 	conda run -n hiv-agent python eval/run_judge.py
# model-all:          # run the agent across all test sequences, all configs
# 	conda run -n hiv-agent python run_model_all.py