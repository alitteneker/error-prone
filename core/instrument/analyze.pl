use strict;
use warnings;

# Currently outputs:
#   (1) stack.csv
#       (a) stack id
#       (b) all remaining cells will contain method calls
#   (2) stats.csv
#       (a) stack id
#       (b) passes
#       (c) fails
#       (d) Tarantula core
#       (e) SBI score
#       (f) Jaccard score
#       (g) Ochiai score
#       (h) Cumulative cyclomatic complexity (computed from $complexities file below)

my $prefix = './cct/';
my $output = './results/';
my $complexities = "./method_data.csv";


my %analyzed_data = ();
my %totals = ();

for my $type ( qw( pass fail ) ) {
    
    # set to -1 for all files, set to some small number for debugging runs
    my $max_files = -1;
    
    my @filenames = get_filenames($prefix, $type);
    
    $totals{$type} = scalar(@filenames);
    print "Found $totals{$type} $type cct files\n";
    
    for my $filename ( @filenames ) {
        
        last unless $max_files--;

        my %found_file = process_file($filename);
        
        for my $stack_val ( keys %found_file ) {
            if( not(exists $analyzed_data{ $stack_val }) ) {
                $analyzed_data{$stack_val} = { pass => 0, fail => 0 };
            }
            $analyzed_data{$stack_val}->{$type} += 1;
        }
        
        print "\tFinished processing $filename\n";
    }
}

my %metadata = load_metadata();
my $index = 0;
my @keys = keys %analyzed_data;

print "All input files processed. Analyzing and processing ".scalar(@keys)." results.\n";

open(my $stacks, '>'.$output.'stacks.csv') or die "Could not open stacks.csv $!";
open(my $stats,  '>'.$output.'stats.csv' ) or die "Could not open stats.csv $!";

while( $index < scalar(@keys) ) {
    
    print $stacks ($index+1) . ",ROOT," . $keys[$index] . "\n";
    
    print $stats join( ',', (
        ($index+1),
        $analyzed_data{ $keys[$index] }->{'pass'},
        $analyzed_data{ $keys[$index] }->{'fail'},
        calc_scores( $analyzed_data{ $keys[$index] }, %totals ),
        get_metadata( $keys[$index], %metadata )
    ) ) . "\n";
    
    if( $index % 1000 == 0 ) {
        print "\tFinished $index out of " . scalar(@keys) . " total results.\n";
    }
    
    ++$index;
}

close $stacks;
close $stats;

print "Complete! Analysis results written to disk.\n";

sub get_filenames {
    my ( $prefix, $type ) = @_;
    my $folder = $prefix . $type;
    
    opendir DIR, $folder or die "Unable to open directory handle $folder";
    my @filenames = map { "$folder/$_" } grep /\.cct$/, readdir DIR;
    closedir DIR;
    
    return @filenames;
}

sub process_file {
    my ( $filename ) = @_;

    open(my $fh, '<:encoding(UTF-8)', $filename) or die "Could not open file '$filename' $!";

    my @stack = ();
    my %found_file = ();

    while (my $line = <$fh>) {
        chomp $line;

        my ( $call_type, $id ) = ( $line =~ m/(\S+)\s(\S+)/ );
        if( $call_type eq 'CALL' ) {
            push @stack, $id;
            $found_file{ join ',', @stack } = 1;
        }
        elsif ( $call_type eq 'RETURN' ) {
            pop @stack;
        }
        else {
            die "Unknown call type '$call_type'";
        }
    }

    return %found_file;
}

sub load_metadata {
    print "Loading cyclomatic complexity metadata . . . ";
    
    my %ret = ();
    
    open(my $fh, '<:encoding(UTF-8)', $complexities) or die "Could not open file '$complexities' $!";
    while (my $line = <$fh>) {
        chomp $line;
        
        my ( $id, $data ) = ( $line =~ m/(.+?),(\d+)/ );
        $ret{$id} = $data;
    }
    
    print "loaded.\n";
    
    return %ret;
}

sub get_metadata {
    my ( $stack, %data ) = @_;
    
    my @stack_vals = split ',', $stack;
    my $result = 0;
    
    for my $id ( @stack_vals ) {
        
        ( $id ) = ( $id =~ m/\/([^\/]+)$/ );
        if( exists $data{$id} ) {
            $result += $data{$id};
        }
    }
    
    return $result;
}

sub calc_scores {
    my ( $data, %totals ) = @_;

    my ( $pass, $fail ) = ( $data->{pass}, $data->{fail} );
    my $perc_pass = ( $pass / $totals{pass} );
    my $perc_fail = ( $fail / $totals{fail} );
    
    my @ret = ();

    # Tarantula: (%failed) / (%passed + %failed)
    push @ret, ( $perc_fail / ( $perc_pass  + $perc_fail ) );
    
    # SBI: failed / ( passed + failed )
    push @ret, ( $fail / ( $pass + $fail ) );
    
    # Jaccard: failed / ( total_failed + passed )
    push @ret, ( $fail / ( $totals{fail} + $pass ) );
    
    # Ochiai: failed / sqrt( total_failed * ( passed + failed ) )
    push @ret, ( $fail / sqrt( $totals{fail} * ( $pass + $fail ) ) );
    
    return join(',', @ret);
}





