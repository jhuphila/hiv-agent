.PHONY: install gold model-all evaluate clean test

help:
	@echo "install  - create/update the hiv-agent conda env"
	@echo "gold     - run sierrapy directly (no agent) to build a standard answer key for evaluation"
	@echo "test     - run pytest in the hiv-agent env -- not yet implemented"
	@echo "clean    - remove caches"

install:
	conda env create -f environment.yaml || conda env update -f environment.yaml

gold:               # deterministic Sierra reference, no agent, the gold standard
	conda run -n hiv-agent python .cursor/skills/sierrapy/translate_and_query.py \
		--data-dir data --results-dir results/gold

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