%% Author: Pedro Borges
%%%% funciton used to merge two stack_stats
%%%% Reminder: Pass the smallest stack_stats as the A!
function [stack_statsA] = mergeStats(stack_statsA,stack_statsB )

stack_statsA = trimWhites(stack_statsA);
stack_statsB = trimWhites(stack_statsB);

num_stacksA = length(stack_statsA);
num_stacksB = length(stack_statsB);


for i = 1:num_stacksB
    
    index = findStack(stack_statsB(i).stack, stack_statsA);
    if index > 0 %%% Means it found the stack. Then update the 
        passesA = stack_statsA(index).passes;
        passesB = stack_statsB(i).passes;
        
        stack_statsA(index).passes = passesA + passesB;
        
        failsA = stack_statsA(index).fails;
        failsB = stack_statsB(i).fails;
        stack_statsA(index).fails = failsA + failsB;
    else
        stack_statsA(end+1)= stack_statsB(i);
    end
    
end

end



