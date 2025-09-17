SHELL := /usr/bin/env bash

.PHONY: demo demo-local build test web-build

build:
	forge build

test:
	forge test -vv

web-build:
	cd web && npm ci && npm run build

# Local demo: simulate validate/postOp using MockEntryPointDemo
# Requires Foundry; runs a single script that deploys contracts and simulates a sponsored op

demo demo-local:
	forge script script/DemoLocal.s.sol:DemoLocal -vv
