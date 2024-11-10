using Pkg

# List of required packages
required_packages = [
    
]

# Function to check if a package is installed
function is_installed(pkg::String)
    deps = Pkg.dependencies()
    return any(p -> p.name == pkg, values(deps))
end

# Check and install packages if they are not already installed
for pkg in required_packages
    if !is_installed(pkg)
        println("Installing $pkg...")
        Pkg.add(pkg)
    else
        println("$pkg is already installed.")
    end
end
