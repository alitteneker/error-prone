%% Author: Pedro Borges
%%% Trim any white spaces from a stack_stats array
function [stack_stats] =  trimWhites(stack_stats)
num_stacks = length(stack_stats);

for i = 1:num_stacks
    for j = 1:length(stack_stats(i).stack{1})
        stack_stats(i).stack{1}(j) =strtrim( stack_stats(i).stack{1}(j));
    end
end


end