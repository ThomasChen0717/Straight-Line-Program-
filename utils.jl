#Function to print file name for each file read for visual clarity
function printTitle(title)
    n = length(title)+1
    println(repeat(string("-"), n))
    println("$(title):")
    println(repeat(string("-"), n))
end