-include make-local

# Define the Julia executable
JULIA = julialauncher

# The name of the ZIP file
ZIP_FILE = SLP.zip

# The source directory containing the files to zip (current directory)
SRC_DIR = .

REMOVE_FOLDER = SLP

p = input.txt

# The default target to run your Julia program
default: run

# A target to run your Julia program
run: checkDep 
	$(JULIA) SLP.jl $(or $(ARGS), $(p))

# Target to create the zip file
zip: clean $(ZIP_FILE)

# Command to create the zip file
$(ZIP_FILE): 
	zip -r $@ $(SRC_DIR) -x "*.vscode/*" -x "*.DS_Store"

# Clean target to remove the zip file
clean:
	rm -f $(ZIP_FILE)
	rm -rf $(REMOVE_FOLDER)

checkDep:
	$(JULIA) check_dep.jl

# Phony targets
.PHONY: default clean run zip checkDep
