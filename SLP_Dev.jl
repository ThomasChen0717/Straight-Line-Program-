include("utils.jl")
include("parser.jl")
include("polyExpander.jl")

#Define the SLP Struct
#Has variable varsConst and codelist that holds a vector of Tuples(Array of tuples)
#Tuples in varsConst have the composition of {Int, Any, Float64, Float64,Float64,Float64}: {Index, Variable or Constant, value, dx, dy, dz}. 
#Tuples in codelist have the composition of {Int, Symbol, Int, Int, Float64, Float64,Float64,Float64}: {Index, operation, arg1, arg2, value, dx, dy, dz}.
struct SLP 
    varsConst::Vector{Tuple{Int, Any, Float64, Float64,Float64,Float64}}
    codelist::Vector{Tuple{Int, Symbol, Int, Int, Float64, Float64,Float64,Float64}}
end

# Function to eval_slp at a point specified by vars and also calculate derivatives
function eval_slp(slp::SLP, vars::Dict{Symbol, Float64})

    #Initialize variables in slp.varsConst
    for i in 1:length(slp.varsConst)
        idx, varConst, _, dx, dy, dz = slp.varsConst[i] 
        if isa(varConst, Symbol) && haskey(vars, varConst)
            new_value = vars[varConst]
            slp.varsConst[i] = (idx, varConst, new_value, dx, dy, dz)
        end
    end

    # Iterate over operations and compute results and derivatives
    for i in 1:length(slp.operations)
        idx, op, arg1, arg2, _, _, _, _ = slp.operations[i]

        # Evaluate the value of the operands
        val1 = arg1 < 0 ? slp.varsConst[-arg1][3] : slp.codelist[arg1][5]
        val2 = arg2 < 0 ? slp.varsConst[-arg2][3] : slp.codelist[arg2][5]

        result = 0.0
        dx, dy, dz = 0.0, 0.0, 0.0

        # Compute the result and derivatives based on the operation
        if op == :+
            result = val1 + val2
            dx = (arg1 < 0 ? slp.varsConst[-arg1][4] : slp.codelist[arg1][6]) +
                 (arg2 < 0 ? slp.varsConst[-arg2][4] : slp.codelist[arg2][6])
            dy = (arg1 < 0 ? slp.varsConst[-arg1][5] : slp.codelist[arg1][7]) +
                 (arg2 < 0 ? slp.varsConst[-arg2][5] : slp.codelist[arg2][7])
            dz = (arg1 < 0 ? slp.varsConst[-arg1][6] : slp.codelist[arg1][8]) +
                 (arg2 < 0 ? slp.varsConst[-arg2][6] : slp.codelist[arg2][8])
        elseif op == :-
            result = val1 - val2
            # Derivatives are the difference of the derivatives of the operands
            dx = (arg1 < 0 ? slp.varsConst[-arg1][4] : slp.codelist[arg1][6]) -
                 (arg2 < 0 ? slp.varsConst[-arg2][4] : slp.codelist[arg2][6])
            dy = (arg1 < 0 ? slp.varsConst[-arg1][5] : slp.codelist[arg1][7]) -
                 (arg2 < 0 ? slp.varsConst[-arg2][5] : slp.codelist[arg2][7])
            dz = (arg1 < 0 ? slp.varsConst[-arg1][6] : slp.codelist[arg1][8]) -
                 (arg2 < 0 ? slp.varsConst[-arg2][6] : slp.codelist[arg2][8])
        elseif op == :*
            result = val1 * val2
            # Use the product rule: d(uv) = u * dv + v * du
            dx = (arg1 < 0 ? slp.varsConst[-arg1][4] : slp.codelist[arg1][6]) * val2 +
                 (arg2 < 0 ? slp.varsConst[-arg2][4] : slp.codelist[arg2][6]) * val1
            dy = (arg1 < 0 ? slp.varsConst[-arg1][5] : slp.codelist[arg1][7]) * val2 +
                 (arg2 < 0 ? slp.varsConst[-arg2][5] : slp.codelist[arg2][7]) * val1
            dz = (arg1 < 0 ? slp.varsConst[-arg1][6] : slp.codelist[arg1][8]) * val2 +
                 (arg2 < 0 ? slp.varsConst[-arg2][6] : slp.codelist[arg2][8]) * val1
        elseif op == :/
            result = val1 / val2
            # Use the quotient rule: d(u/v) = (v * du - u * dv) / v^2
            dx = ((arg1 < 0 ? slp.varsConst[-arg1][4] : slp.codelist[arg1][6]) * val2 +
                 (arg2 < 0 ? slp.varsConst[-arg2][4] : slp.codelist[arg2][6]) * val1) / (val2 ^ 2)
            dy = ((arg1 < 0 ? slp.varsConst[-arg1][5] : slp.codelist[arg1][7]) * val2 +
                 (arg2 < 0 ? slp.varsConst[-arg2][5] : slp.codelist[arg2][7]) * val1) / (val2 ^ 2)
            dz = ((arg1 < 0 ? slp.varsConst[-arg1][6] : slp.codelist[arg1][8]) * val2 +
                 (arg2 < 0 ? slp.varsConst[-arg2][6] : slp.codelist[arg2][8]) * val1) / (val2 ^ 2)
        end
        
        # Update the current operation with the result and derivatives
        slp.codelist[i] = (idx, op, arg1, arg2, result, dx, dy, dz)
    end

    return slp
end



# #Iterate through each file name in Argument
# for i in 1:length(ARGS)
#     file = open(ARGS[i])
#     printTitle(ARGS[i])

#     #Iterate through each line
#     for line in eachline(file)
#         #Skipping comment and empty lines
#         if startswith(line, "#") || isempty(line)
#             continue
#         end
        
#         parts = split(line, r",\s*")

#         vars::Dict{Symbol, Float64} = Dict()
#         description = ""


#         for i in 2:(length(parts)-1)
#             splitEq = split(parts[i], r"=\s*")
#             vars[Symbol(splitEq[1])] = parse(Float64, splitEq[2])
#         end
        
#         # Check if the last part might be a description (optional)
#         lastPart = parts[end]
#         if contains(lastPart, "\"")
#             description = lastPart  # Store the description if it's not a variable assignment
#         else
#             splitEq = split(lastPart, r"=\s*")
#             vars[Symbol(splitEq[1])] = parse(Float64, splitEq[2])
#         end

#         #Splits each polynomial to various terms
#         terms = split_polynomials(String(parts[1]))
        
#         #Parses each term for further processing
#         parsed_terms = [parse_term(term) for term in terms]
        
        

#         #Transform the parsed terms to slp to find the slp form of the polynomial
#         slp = transform_to_slp(parsed_terms)

#         # Evaluate the SLP at the given variables 
#         results, derivatives = eval_slp(slp, vars)
#         results = sort(collect(results), by = x -> parse(Int, string(x[1])[2:end]))
#         derivatives = sort(collect(derivatives), by = x -> string(x[1]))
#         sorted_vars = sort(collect(vars))
        
#         # Print the results
#         for (key, value) in sorted_vars
#             println("$(string(key)) = $value")
#         end
#         println("$(parts[1]):")
#         #Result printing
#         if description != ""
#             description = replace(description, "\\n" => "\n")
#             println(description)
#             println()
#         end

#         for (i, (var, result)) in enumerate(results)
#             # Print result of ui
#             println("\n$var =  $(slp.operations[i][1:3]) = $result")
        
#             # Print partial derivatives of ui
#             println("Partial derivatives of $var:")
#             for (key, value) in derivatives
#                 println("∂$var/∂$key = $(value[var])")
#             end
#         end

#         println()
#     end

# end


