include("parser.jl")

#Function to handle parenthesis expansion
function expand_parenthesis(term::String)
    # Split the polynomial into parts around parentheses and other operators
    factors = split_parenthesis_terms(term)

    res = factors[1]
    for i in 2:length(factors)
        res = multiply_factors(String(res), String(factors[i]))
    end

    return res
end

# Function to multiply two terms, distributing multiplication over addition
function multiply_factors(factor1::String, factor2::String)
    # Split the terms in each factor by '+' and '-'
    terms1 = split_terms(factor1)
    terms2 = split_terms(factor2)


    # Store the result of multiplying each pair of terms
    result_terms = [(0, Dict{String, Int}())]
    
    # Distribute the multiplication between terms from factor1 and factor2
    for t1 in terms1
        for t2 in terms2
            product = multiply_single_terms(String(t1), String(t2))
            result_terms = combine_terms(result_terms, product)
        end
    end
    
    # Format the final result as a string
    return format_polynomial(result_terms)
end

# Function to split terms by '+' and '-' (account for signs)
function split_terms(factor::String)
    # Normalize spaces and handle negative terms
    factor = replace(factor, " " => "")
    terms = split(factor, r"(?=[+-])")
    return terms
end

# Function to multiply two single terms and return a dictionary of the result
function multiply_single_terms(term1::String, term2::String)
    term1 = strip(term1)
    term2 = strip(term2)


    # Multiply coefficients and variables
    coef1, vars1 = parse_single_term(String(term1))
    coef2, vars2 = parse_single_term(String(term2))

    # Multiply coefficients
    coef = coef1 * coef2
    
    # Combine powers of the variables
    for (var, power) in vars2
        if haskey(vars1, var)
            vars1[var] += power
        else
            vars1[var] = power
        end
    end

    return (coef, vars1)
end

# Combine two terms (sum coefficients if the terms are similar)
function combine_terms(terms::Vector{Tuple{Int, Dict{String, Int}}}, new_term::Tuple{Int, Dict{String, Int}})
    combined_terms = deepcopy(terms)  # Make a copy to avoid modifying the input

    # Check if the new_term can be merged with an existing term
    for (i, (coef, vars)) in enumerate(combined_terms)
        if vars == new_term[2]  # Check if the variables match
            combined_terms[i] = (coef + new_term[1], vars)  # Sum coefficients if variables match
            return combined_terms
        end
    end

    # If no matching term is found, add the new term to the list
    push!(combined_terms, new_term)
    return combined_terms
end

# Function to format the polynomial into a string
function format_polynomial(terms::Vector{Tuple{Int, Dict{String, Int}}})
    # Sort terms by the degree (sum of the powers) in descending order
    sorted_terms = sort(terms, by = x -> -sum(values(x[2])))  # Negative sign to sort descending

    result = ""
    for (coef, vars) in sorted_terms
        # Skip if coefficient is zero
        if coef == 0
            continue
        end
        
        term_str = abs(coef) == 1 && !isempty(vars) ? "" : string(abs(coef))
        for (var, power) in vars
            if power == 1
                term_str *= var
            else
                term_str *= string(var, "^", power)
            end
        end
        if result == ""
            result = term_str
        else
            result *= coef > 0 ? " + $term_str" : " - $(term_str)"
        end
    end
    return result
end

function split_parenthesis_terms(term::String)
    # Remove all opening parentheses
    term = replace(term, "(" => "")
    
    # Split by the closing parentheses
    terms = split(term, ")")
    
    # Remove any empty strings (if present)
    terms = filter(t -> !isempty(t), terms)
    
    return terms
end