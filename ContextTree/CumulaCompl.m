%% Author: Pedro Borges
function [ cumul_complexity ] = CumulaCompl( stacks_stats, comple_file )

tline = filetoarray(comple_file);
[methods_list, remain] = strtok(tline(1:end), ',');
complexity_list = strtok(remain, ',');
complexity = 0;
num_stacks = length(stacks_stats);
cumul_complexity = zeros(1, num_stacks) ;

length_complexity = length(complexity_list)
%%%% transforming the complexity list from cell to an array
complexity_array = zeros(1,length_complexity);
for aux = 1:length(complexity_list)
    complexity_array(aux) =str2num( cell2mat(complexity_list(aux)));
    
end

for i = 1:num_stacks
    cumul_complexity(i) = 0;
    for j = 1:length(stacks_stats(i).stack{1})
        complexity = findMethod(stacks_stats(i).stack{1}(j), methods_list, complexity_array);
        cumul_complexity(i) = cumul_complexity(i)+complexity;
    end
end

end

function [complexity] = findMethod(stack_method, list_methods, list_complexity)
complexity = 0;
method_name = strtrim(stack_method);
for i =1:length(list_methods)
    
    if(strcmp(method_name, list_methods(i)))
        complexity = list_complexity(i);
    end
end

end


%%%% Opens the file and puts it in the
function [tline] = filetoarray(File)

fid = fopen(File);
tline = textscan(fid,'%s','Delimiter','\n');
tline = tline{1};

fclose(fid);

end