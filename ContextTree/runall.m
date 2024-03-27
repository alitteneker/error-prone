%%   Author: Pedro Borges
%%%% runs the algorithm in two folders, one with passed tests and another
%%%% with failed tests
clear
Dir_passed = '../core/instrument/cct/pass/'; % Name of the directory for failed tests
Dir_failed = '../core/instrument/cct/fail/'; %% Name of the directory for passed outputs
file_cumulative = './StaticMetric/static.csv';
[ stacks_stats, Totalpasses, Totalfails ] = statsMultipleCalls( Dir_failed, Dir_passed );
[ cumul_complexity ] = CumulaCompl( stacks_stats, file_cumulative );
writeResults(stacks_stats, cumul_complexity,  Totalfails, Totalpasses ) %% Writes all the stacks from the tests into csv files. One containing the stacks. Another containing the corresponding number of passes and fails