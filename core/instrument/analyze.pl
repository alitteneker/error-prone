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
my $complexities = "./out.csv";
my $pattern = quotemeta "com/google/errorprone/";
my @stat_order = qw( pass fail tarantula sbi jaccard ochiai );
my $order_key = "tarantula";

# -- Begin Script --
my %collected_method_stacks = ();
my %collected_line_stacks = ();
my %collected_methods = ();
my %collected_lines = ();
my %test_totals = ();

for my $type ( qw( pass fail ) ) {
    
    my $max_files = -1;
    
    my @filenames = get_test_filenames($prefix, $type);
    
    $test_totals{$type} = scalar(@filenames);
    print "Found $test_totals{$type} $type cct files\n";
    
    for my $filename ( @filenames ) {
        
        last unless $max_files--;

        my ( $methods, $lines, $method_stacks, $line_stacks ) = process_file($filename);
        
        increment( $type, $method_stacks, \%collected_method_stacks );
        increment( $type, $line_stacks, \%collected_line_stacks );
        increment( $type, $methods, \%collected_methods );
        increment( $type, $lines, \%collected_lines );
        
        print "\tFinished processing $filename\n";
    }
}

my %metadata = load_metadata();
print "All input files processed.\n";

write_data( 0, "methodstack", %collected_method_stacks );
write_data( 0, "linestack", %collected_line_stacks );
write_data( 1, "method", %collected_methods );
write_data( 1, "line", %collected_lines );

print "Complete! All output written to directory $output.\n";
# -- End Script --

sub increment {
    my ( $type, $source, $destination ) = @_;
    
    for my $key ( keys %{ $source } ) {
        if( not(exists $destination->{ $key } )) {
            $destination->{ $key } = { pass => 0, fail => 0 };
        }
        $destination->{ $key }->{ $type } += 1;
    }
}

# process_file: process a single cct file, and build data structures for tracking methods, lines, and stacks
sub process_file {
    my ( $filename ) = @_;
    
    open(my $fh, '<:encoding(UTF-8)', $filename) or die "Could not open file '$filename' $!";
    
    my @methods = ();
    my @lineset = ();
    my @active = ();
    my $index = -1;
    
    my %method_stacks = ();
    my %line_stacks = ();
    my %methods = ();
    my %lines = ();
    
    while (my $line = <$fh>) {
        chomp $line;
        
        my ( $call_type, $id ) = ( $line =~ m/(\S+)\s(\S+)/ );
        if( $call_type eq 'CALL' ) {
            push @methods, $id;
            $lineset[ ++$index ] = -1;
            push @active, 0;
            if( $id =~ m/$pattern/ ) {
                $active[$index] = 1;
                $methods{$id} = 1;
                $method_stacks{ join ',', map { $active[$_] ? $methods[$_] : () } ( 0 .. $index ) } = 1;
            }
        }
        elsif ( $call_type eq 'LINE' ) {
            if( $index >= 0 and $active[$index] ) {
                $lineset[$index] = $id;
                $lines{ $methods[$index] . "," . $id } = 1;
                $line_stacks{ join ',', map { $active[$_] ? "$methods[$_]:$lineset[$_]" : () } ( 0 .. $index ) } = 1;
            }
        }
        elsif ( $call_type eq 'RETURN' ) {
            pop @methods;
            pop @active;
            --$index;
        }
        else {
            die "Unknown call type '$call_type'";
        }
    }
    
    return ( \%methods, \%lines, \%method_stacks, \%line_stacks );
}

# write_stacks: write the stack and stats data for the passed data
sub write_data {
    my ( $use_key, $type, %data ) = @_;
    
    my $index = 0;
    my @keys = keys %data;
    
    print "$type:\tProcessing output of " . scalar(@keys) . " results.\n";
    
    for my $key ( @keys ) {
        compute_scores( $data{$key}, %test_totals );
        $data{$key}->{'cyclomatic_complexity'} = get_metadata( $key, %metadata );
        if( ++$index % 1000 == 0 ) {
            print "\t\t\tFinished $index out of " . scalar(@keys) . " total results.\n";
        }
    }
    @keys = sort {
        $data{$b}->{$order_key} <=> $data{$a}->{$order_key}
        or $data{$b}->{pass} + $data{$b}->{fail} <=> $data{$a}->{pass} + $data{$a}->{fail}
    } @keys;

    print "$type:\tStarting output of " . scalar(@keys) . " results.\n";

    my ( $stacks, $stats );
    unless( $use_key ) {
        open($stacks, ">${output}${type}_stacks.csv") or die "Could not open ${type}_stacks.csv $!";
    }
    open($stats,  ">${output}${type}_stats.csv") or die "Could not open ${type}_stats.csv $!";

    $index = 0;
    while( $index < scalar(@keys) ) {
        
        unless( $use_key ) {
            print $stacks ( $index + 1 ) . "," . $keys[$index] . "\n";
        }
        print $stats join( ',',
            ( $use_key ? $keys[$index] : ( $index + 1 ),
            map { $data{$keys[$index]}->{$_} } @stat_order )
        ) . "\n";
        
        ++$index;
    }
    
    close $stacks unless $use_key;
    close $stats;
    
    print "$type:\tFinished output of results.\n";
}

# get_test_filenames: get a list of all .cct files in the given folder
sub get_test_filenames {
    my ( $prefix, $type ) = @_;
    my $folder = $prefix . $type;
    
    opendir DIR, $folder or die "Unable to open directory handle $folder";
    my @filenames = map { "$folder/$_" } grep /\.cct$/, readdir DIR;
    closedir DIR;
    
    return @filenames;
}

# load_metadata: load cyclomatic complexity data
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
        ( $id ) = ( $id =~ m/\/([^\/]+?)(?::\d+)?$/ );
        if( length($id) and exists($data{$id}) ) {
            $result += $data{$id};
        }
    }
    
    return $result;
}

sub compute_scores {
    my ( $data, %test_totals ) = @_;

    my ( $pass, $fail ) = ( $data->{pass}, $data->{fail} );
    my $perc_pass = ( $pass / $test_totals{pass} );
    my $perc_fail = ( $fail / $test_totals{fail} );
    
    # Tarantula: (%failed) / (%passed + %failed)
    $data->{'tarantula'} = ( $perc_fail / ( $perc_pass  + $perc_fail ) );
    
    # SBI: failed / ( passed + failed )
    $data->{'sbi'} = ( $fail / ( $pass + $fail ) );
    
    # Jaccard: failed / ( total_failed + passed )
    $data->{'jaccard'} = ( $fail / ( $test_totals{fail} + $pass ) );
    
    # Ochiai: failed / sqrt( total_failed * ( passed + failed ) )
    $data->{'ochiai'} = ( $fail / sqrt( $test_totals{fail} * ( $pass + $fail ) ) );
}





