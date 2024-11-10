#Function to split input_polynomials to each term
function split_polynomials(poly::String)
    norm_poly = replace(poly, " " => "") #Initial processing, remove all space

    buffer = ""  # To collect characters for the modified polynomial string
    paren_count = 0  # To track whether we're inside parentheses

    # Loop through each character in the polynomial string
    for c in norm_poly
        if c == '('
            paren_count += 1  # We're entering a parenthesis group
        elseif c == ')'
            paren_count -= 1  # We're exiting a parenthesis group
        end

        # Add space before + or - only if we're not inside parentheses
        if (c == '+' || c == '-') && paren_count == 0
            buffer *= " $c"
        else
            buffer *= c
        end
    end

    # Split the modified polynomial into terms
    terms = split(buffer)

    #Remove + sign in each term as + is the default
    terms = [replace(term, r"^\+" => "") for term in terms]

    # Expand each term that contains parentheses
    expanded_terms = []
    for term in terms
        if occursin(r"\(", term)
            expanded_term = expand_parenthesis(term)
            push!(expanded_terms, expanded_term)
        else
            push!(expanded_terms, term)
        end
    end

    return expanded_terms
end

##Function to parse a term in a polynomial into a dictionary entry with [K:V] being [coefficient: Dict(Variable Powers)]
#Ex. 3x^2y will be parsed into (3, Dict("x"=>2, "y" => 1)) 
function parse_term(term::String)
    if occursin("/", term)
        parts = split(term, "/")
        numerator = String(parts[1])
        denominator = String(parts[2])

        coef_num, vars_num = parse_single_term(numerator)
        _, vars_denom = parse_single_term(denominator)

        for(var, power) in vars_denom
            vars_num[var] = -power
        end

        return (coef_num, vars_num)
    else 
        return parse_single_term(term)
    end
end

#Helper function that handles parsing without division 
function parse_single_term(term::String)
    #Regular Expression to capture the coefficient and the variable part
    m = match(r"([+-]?\d*)([a-zA-Z][a-zA-Z0-9\^]*)?", term)
    
    coef_str, var = m.captures

    # Handle the coefficient
    if coef_str == "" || coef_str == "+"  # No coefficient or explicit '+'
        coef = 1
    elseif coef_str == "-"  # Implied '-1' coefficient
        coef = -1
    else
        coef = parse(Int, coef_str)
    end


    vars_dict = Dict{String, Int}()

    if !(var === nothing)
        for var_match in eachmatch(r"([a-zA-Z])(?:\^(\d+))?", var)
            var = var_match[1]
            exp = var_match[2] === nothing ? 1 : parse(Int, var_match[2])
            vars_dict[var] = exp
        end 
    end

    return (coef, vars_dict)
end

#Transforms the parsed terms into the SLP form of the polynomial
function transform_to_slp(terms)
    operations = []
    var_counter = 1
    temp_res_vars = []

    #Iterate through each term and convert each term into SLP form
    for term in terms
        coef, var_powers = term  # Unpack the parsed term

        #Check if coef is negative
        is_negative = coef < 0
        coef = abs(coef)

        #Condition to check if division is applied to the term
        isDivision = false

        temp_vars = []

        #Iterate through each variable to deal with its powers
        for(var, power) in var_powers
            var = Symbol(var)

            if power < 0
                isDivision = true
            end

            if abs(power) > 1
                result = var
                for _ in 1:(abs(power) - 1)
                    intermediate_var = Symbol("u$var_counter")
                    push!(operations, (:*, result, var, 0.0, Dict{Symbol, Float64}()))
                    result = intermediate_var
                    var_counter += 1
                end
                push!(temp_vars, (result, isDivision))
            else 
                push!(temp_vars, (var, isDivision))
            end
        end
        
        #Combining coef with variables
        if coef != 1 
            result = coef
            # Iterate through all variables, starting from the first one
            for temp_var in temp_vars
                if temp_var[2]  # If division is applied
                    push!(operations, (:/, result, temp_var[1], 0.0, Dict{Symbol, Float64}()))
                else  # Normal multiplication
                    push!(operations, (:*, result, temp_var[1], 0.0, Dict{Symbol, Float64}()))
                end
                result = Symbol("u$var_counter")
                var_counter += 1
            end
        else
            # If coef == 1, skip initializing result with coef and directly handle variables
            result = temp_vars[1][1]  # Start with the first variable
        
            # Iterate through remaining variables
            for i in 2:length(temp_vars)
                if temp_vars[i][2]  # If division is applied
                    push!(operations, (:/, result, temp_vars[i][1], 0.0, Dict{Symbol, Float64}()))
                else  # Normal multiplication
                    push!(operations, (:*, result, temp_vars[i][1], 0.0, Dict{Symbol, Float64}()))
                end
                result = Symbol("u$var_counter")
                var_counter += 1
            end
        end
    
        push!(temp_res_vars, (result, is_negative))
    end

    #Combine SLP for each term
    if length(temp_res_vars) > 1
        for i in 2:length(temp_res_vars)
            prev_var, prev_is_negative = temp_res_vars[i-1]
            curr_var, curr_is_negative = temp_res_vars[i]
            
            # Combine using + or - depending on the sign of the current term    
            if curr_is_negative
                push!(operations, (:-, prev_var, curr_var, 0.0, Dict{Symbol, Float64}()))
            else
                push!(operations, (:+, prev_var, curr_var, 0.0, Dict{Symbol, Float64}()))
            end

            # Update the result variable for the next iteration
            temp_res_vars[i] = (Symbol("u$var_counter"), false)  # Mark combined as positive result
            var_counter += 1
        end
    end


    return SLP(operations)
end