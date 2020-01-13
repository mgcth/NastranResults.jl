"""
    read_input(file::String)

Read input file as is.
"""
function read_input(file::String)
    model = NastranModel(file);
end

"""
    write_input(file::String)

Write input file.
"""
function write_input(file::String)
end

"""
    generate_input(file::String, modifications::Dict)

Generate input file with specified changes, from existing file. This requires
manual work from the user.

Support for INCLUDE files, but only one a single line for now, i.e. not split over multiple lines.
"""
function generate_input(file::String, new_name::String, path::String, mods::Dict)
    output_file = Vector{String}()
    fo = open(string(new_name), "w")

    # replace parameters in place
    replace_parameters!(file, output_file, path, mods)

    # save to new file
    writedlm(fo, output_file)
    close(fo)
end

function replace_parameters!(file, output_file, path, mods)
    #lines = readdlm(file, '\n', String; skipblanks=false, quotes=false, comments=false)

    for line in eachline(open(file)) #lines
        if line[1] != '\$'
            if split(line)[1] == INCLUDE
                data_file = strip(string(split(line)[2]), '\'')
                line = replace(line, data_file, join([path, data_file]))
                #replace_parameters!(file, output_file, mods)
                #continue
            else
                map(keys(mods)) do i
                    if !iszero(searchindex(line, i))
                        # this is ugly, can it be automated somehow (more general)
                        value = @sprintf("%16.10E", float(mods[i]))
                        line = replace(line, i, value)
                        #delete!(mods, i) # same parameter multiple times?
                    end
                end
            end
        end

        push!(output_file, line)
        #write(fo, line)
    end
end
