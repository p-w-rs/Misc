using TOML

function get_packageUuid(package_name::String)
    # Convert the package name string to a symbol
    package_symbol = Symbol(package_name)

    # Load the package into the current scope
    @eval using $package_symbol

    # Get the module object
    mod = eval(package_symbol)

    # Get the path to the source file of the module
    source_path = pathof(mod)
    if source_path === nothing
        error("Package $package_name is not loaded from a file.")
    end

    # Get the package directory by navigating up two levels from the source file
    package_dir = dirname(dirname(source_path))

    # Construct the path to the project.toml file
    project_file = joinpath(package_dir, "project.toml")
    if !isfile(project_file)
        error("Project file not found in $package_dir")
    end

    # Parse the project.toml file
    metadata = TOML.parsefile(project_file)

    # Retrieve the UUID from the metadata
    if haskey(metadata, "uuid")
        return metadata["uuid"]
    else
        error("UUID not found in project file")
    end
end

# run get uuid on the first command line argument
println(get_packageUuid(ARGS[1]))
