
function [tline] = filetoarray(File)

fid = fopen(File);
tline = textscan(fid,'%s','Delimiter','\n');
tline = tline{1};

fclose(fid);

end