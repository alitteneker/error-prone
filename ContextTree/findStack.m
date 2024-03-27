%% Author: Pedro Borges
%%%% Searches for the stack in the array of stacks_stats
%%%% Retuns the index in the stacks_stats array where it found the stack
%%%% Returns 0 if didn't find the stack
function [index] = findStack(stack, stacks_stats)
index = 0;
for i = 1:length(stacks_stats)
    
    isequal = cellComp(stack{1}, stacks_stats(i).stack{1}); %% needs the {1} because the array is inside the cell
    if isequal == 1 %% means it found the stack
        index = i; %% index is the current position on the array
        %break;
    end
end
end


%%%% Used to compare two cell arrays
%%%% Returns 0 if the two stacks are differente
%%%% Returns 1 if the two stacks are equal
function [is_equal] = cellComp(stacka, stackb)

if length(stacka) ~= length(stackb)
    
    is_equal = false;
else
    aux = strcmp(stacka,stackb) ;
    aux = aux -1;
    if ~isempty(find(aux))  %% if there is a term that is any -1 term, then they are not equal
        is_equal = false;
    else
        is_equal = true;
    end
    
end
end
