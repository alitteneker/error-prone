%% Author: Pedro Borges
%%% function to parse the text file to take the path off the method.

function [CallOrRetunr, method] = parseFile(file)

[tline] = filetoarray(file);
[CallOrRetunr, remain] = strtok(tline(1:end));
[token1, remain1] = strtok(remain(1:end), '.');
method = strtok(remain1(1:end), '.');

end