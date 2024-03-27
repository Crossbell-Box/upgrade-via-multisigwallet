# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

all: clean install build foundry-test

# Clean the repo
clean  :; forge clean

# Install the Modules
install :; forge install --no-commit

# Update Dependencies
update:; forge update

# Builds
build  :; forge build

bindings :
	@echo " > \033[32mCreate go bindings...\033[0m"
	./tools/createBindings.sh

# Tests
# --ffi # enable if you need the `ffi` cheat code on HEVM
foundry-test :; forge clean && forge test --optimize --optimizer-runs 200 -v

# Run solhint
solhint :; solhint -f table "{src,test,script}/**/*.sol"

# slither
# to install slither, visit [https://github.com/crytic/slither]
slither :; slither . --fail-low #--triage-mode

# mythril
mythril :
	@echo " > \033[32mChecking contracts with mythril...\033[0m"
	./tools/mythril.sh

mythx :
	@echo " > \033[32mChecking contracts with mythx...\033[0m"
	mythx analyze

# upgradeable check
upgradeable:
	@echo " > \033[32mChecking upgradeable...\033[0m"
	./tools/checkUpgradeable.sh

# check upgradeable contract storage layout
storage-layout:
	@echo " > \033[32mChecking contract storage layout...\033[0m"
	./tools/checkStorageLayout.sh

# [DANGEROUS] regenerate upgradeable contract storage layout
regenerate-storage-layout:
	@echo " > \033[32m[DANGEROUS]Regenerating storage layout...\033[0m"
	rm ./tools/storageLayout/* && ./tools/checkStorageLayout.sh

# Lints
lint :; npx prettier --plugin=prettier-plugin-solidity  --write "{src,test,script}/**/*.sol"

# Generate Gas Snapshots
snapshot :; forge clean && forge snapshot
