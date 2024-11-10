include("utils.jl")
include("parser.jl")
include("polyExpander.jl")

#Define the SLP Struct
#Has variable operations that holds a vector of Tuples(Array of tuples)
#Each Tuple have the composition of {Symbol, Any, Any, Float64, Vector{Float64}}. In the first index, it would hold the operation(+,-,*,/) and it would hold the two operants in the following two indexes. The next index holds the evaluated value of the operation at a given point, and the last index holds a dynamic array that holds partial derivatives with respect to each variable in the slp
struct SLP 
    operations::Vector{Tuple{Symbol, Any, Any, Float64, Dict{Symbol, Float64}}}
end

# Function to eval_slp at a point specified by vars and also calculate derivatives
function eval_slp(slp::SLP, vars::Dict{Symbol, Float64})
    # Stores intermediate results of the SLP and derivatives
    results = Dict{Symbol, Float64}()  # Store evaluated values
    derivatives = Dict{Symbol, Dict{Symbol, Float64}}()  # Store partial derivatives for each variable

    # Initialize derivative dictionaries for each variable
    for var in keys(vars)
        derivatives[var] = Dict{Symbol, Float64}()
        derivatives[var][var] = 1.0
        for otherVar in keys(vars)
            if otherVar != var
                derivatives[var][otherVar] = 0.0
            end
        end
    end

    # Iterate over operations and compute results and derivatives
    for i in 1:length(slp.operations)
        op, arg1, arg2, _, _ = slp.operations[i]

        # Evaluate the value of the operands
        val1 = isa(arg1, Symbol) ? (haskey(results, arg1) ? results[arg1] : vars[arg1]) : arg1
        val2 = isa(arg2, Symbol) ? (haskey(results, arg2) ? results[arg2] : vars[arg2]) : arg2

        result = 0.0
        derivative = Dict{Symbol, Float64}()  # Derivative for this operation

        # Compute the result and derivatives based on the operation
        if op == :+
            result = val1 + val2
            # Derivatives are simply the sum of the derivatives of the operands
            for var in keys(vars)
                derivative[var] = (haskey(derivatives[var], arg1) ? derivatives[var][arg1] : 0.0) +
                                  (haskey(derivatives[var], arg2) ? derivatives[var][arg2] : 0.0)
            end
        elseif op == :-
            result = val1 - val2
            # Derivatives are the difference of the derivatives of the operands
            for var in keys(vars)
                derivative[var] = (haskey(derivatives[var], arg1) ? derivatives[var][arg1] : 0.0) -
                                  (haskey(derivatives[var], arg2) ? derivatives[var][arg2] : 0.0)
            end
        elseif op == :*
            result = val1 * val2
            # Use the product rule: d(uv) = u * dv + v * du
            for var in keys(vars)
                d_val1 = haskey(derivatives[var], arg1) ? derivatives[var][arg1] : 0.0
                d_val2 = haskey(derivatives[var], arg2) ? derivatives[var][arg2] : 0.0
                derivative[var] = d_val1 * val2 + val1 * d_val2
            end
        elseif op == :/
            result = val1 / val2
            # Use the quotient rule: d(u/v) = (v * du - u * dv) / v^2
            for var in keys(vars)
                d_val1 = haskey(derivatives[var], arg1) ? derivatives[var][arg1] : 0.0
                d_val2 = haskey(derivatives[var], arg2) ? derivatives[var][arg2] : 0.0
                derivative[var] = (d_val1 * val2 - val1 * d_val2) / (val2^2)
            end
        end

        # Store the result and derivatives for the current operation
        res_var = Symbol("u$(i)")
        results[res_var] = result
        for var in keys(vars)
            derivatives[var][res_var] = derivative[var]
        end

        # Update the current operation with the result and derivative
        slp.operations[i] = (op, arg1, arg2, result, derivative)
    end

    return results, derivatives
end

tmp_poly = "(x+1)(x-1)"
println(expand_parenthesis(tmp_poly))


#Iterate through each file name in Argument
for i in 1:length(ARGS)
    file = open(ARGS[i])
    printTitle(ARGS[i])

    #Iterate through each line
    for line in eachline(file)
        #Skipping comment and empty lines
        if startswith(line, "#") || isempty(line)
            continue
        end
        
        parts = split(line, r",\s*")

        vars::Dict{Symbol, Float64} = Dict()
        description = ""


        for i in 2:(length(parts)-1)
            splitEq = split(parts[i], r"=\s*")
            vars[Symbol(splitEq[1])] = parse(Float64, splitEq[2])
        end
        
        # Check if the last part might be a description (optional)
        lastPart = parts[end]
        if contains(lastPart, "\"")
            description = lastPart  # Store the description if it's not a variable assignment
        else
            splitEq = split(lastPart, r"=\s*")
            vars[Symbol(splitEq[1])] = parse(Float64, splitEq[2])
        end

        #Splits each polynomial to various terms
        terms = split_polynomials(String(parts[1]))
        
        #Parses each term for further processing
        parsed_terms = [parse_term(term) for term in terms]
        
        

        #Transform the parsed terms to slp to find the slp form of the polynomial
        slp = transform_to_slp(parsed_terms)

        # Evaluate the SLP at the given variables 
        results, derivatives = eval_slp(slp, vars)
        results = sort(collect(results), by = x -> parse(Int, string(x[1])[2:end]))
        derivatives = sort(collect(derivatives), by = x -> string(x[1]))
        sorted_vars = sort(collect(vars))
        
        # Print the results
        for (key, value) in sorted_vars
            println("$(string(key)) = $value")
        end
        println("$(parts[1]):")
        #Result printing
        if description != ""
            description = replace(description, "\\n" => "\n")
            println(description)
            println()
        end

        for (i, (var, result)) in enumerate(results)
            # Print result of ui
            println("\n$var =  $(slp.operations[i][1:3]) = $result")
        
            # Print partial derivatives of ui
            println("Partial derivatives of $var:")
            for (key, value) in derivatives
                println("∂$var/∂$key = $(value[var])")
            end
        end

        println()
    end

end


