use strict;
use warnings;
use List::MoreUtils qw(any first_result);

my $prefix = './cct/';
my $output = './results/';
my $metadata = "./ep_static_outer.csv";
my $pattern = quotemeta "com/google/errorprone/";
my @order_keys = qw( m_tarantula tarantula total );
my @stat_order = (
    qw( pass fail m_pass m_fail line_var pass_line_var fail_line_var ubiquity method_ubiquity line_method_ubiquity ),
    qw( fail_iso_1 fail_iso_2 m_tarantula tarantula sbi jaccard ochiai ) # and more from metadata file
);

# -- Begin Script --
my %collected_method_stacks = ();
my %collected_line_stacks = ();
my %collected_methods = ();
my %collected_lines = ();
my %line_stats = ();
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

build_line_stats();

my %metadata = load_metadata();
print "All input files processed.\n";

write_data( 0, "methodstack", %collected_method_stacks );
write_data( 0, "linestack", %collected_line_stacks );
write_data( 1, "method", %collected_methods );
write_data( 1, "line", %collected_lines );

print "Complete! All output written to directory $output.\n";
# -- End Script --

# build an additional data structure for method line variability
sub build_line_stats {
    for my $key ( keys %collected_lines ) {
        my ( $meth, $ln ) = split ',', $key;
        
        $line_stats{$meth} //= { lines => {}, total_pass => 0, total_fail => 0 };
        $line_stats{$meth}->{lines}->{$ln} = {
            pass => $collected_lines{$key}->{pass},
            fail => $collected_lines{$key}->{fail}
        };
        $line_stats{$meth}->{total_pass} += $collected_lines{$key}->{pass};
        $line_stats{$meth}->{total_fail} += $collected_lines{$key}->{fail};
    }
    for my $meth ( keys %line_stats ) {
        my $num_lines = scalar keys %{ $line_stats{$meth}->{lines} };
        my $total = $line_stats{$meth}->{total_pass} + $line_stats{$meth}->{total_fail};
        my $avg = $total / $num_lines;
        my $avg_pass = $line_stats{$meth}->{total_pass} / $num_lines;
        my $avg_fail = $line_stats{$meth}->{total_fail} / $num_lines;
        my ( $diff, $pass_diff, $fail_diff ) = ( 0, 0, 0 );
        
        for my $lnkey ( keys %{ $line_stats{$meth}->{lines} } ) {
            $diff    += ( ( $line_stats{$meth}->{lines}->{$lnkey}->{pass}
                          + $line_stats{$meth}->{lines}->{$lnkey}->{fail} ) - $avg ) ** 2;
            $pass_diff += ( $line_stats{$meth}->{lines}->{$lnkey}->{pass} - $avg_pass ) ** 2;
            $fail_diff += ( $line_stats{$meth}->{lines}->{$lnkey}->{fail} - $avg_fail ) ** 2;
        }
        
        $line_stats{$meth}->{num_lines} = $num_lines;
        $line_stats{$meth}->{avg} = $avg;
        $line_stats{$meth}->{avg_pass} = $avg_pass;
        $line_stats{$meth}->{avg_fail} = $avg_fail;
        $line_stats{$meth}->{stdev} = sqrt( $diff / $num_lines );
        $line_stats{$meth}->{stdev_pass} = sqrt( $pass_diff / $num_lines );
        $line_stats{$meth}->{stdev_fail} = sqrt( $fail_diff / $num_lines );
    }
}

# increment: helper function to let us more easily build our data structures
sub increment {
    my ( $type, $source, $destination ) = @_;
    
    for my $key ( keys %{ $source } ) {
        $destination->{ $key } //= { pass => 0, fail => 0 };
        $destination->{ $key }->{ $type } += $source->{ $key };
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
            $id =~ s/<init>/Constructor/;
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
    my $num_keys = scalar(@keys);
    
    print "$type:\tProcessing output of $num_keys results.\n";
    
    for my $key ( @keys ) {
        compute_scores( $type, $key, $data{$key}, %test_totals );
        get_metadata( $key, $data{$key}, %metadata );
        if( ++$index % 1000 == 0 ) {
            print "\t\t\tFinished $index out of $num_keys total results.\n";
        }
    }
    
    my @this_stat_order = grep { my $k = $_; any { defined( $data{$_}->{$k} ) } @keys } @stat_order;
    
    my @orderers = grep { defined($data{@keys[0]}->{$_}) } @order_keys;
    print "$type:\tSorting $num_keys by @orderers.\n";
    @keys = sort {
        ( first_result { $data{$b}->{$_} <=> $data{$a}->{$_} } @orderers ) // 0
    } @keys;

    print "$type:\tStarting output of $num_keys results.\n";

    my ( $stacks, $stats );
    unless( $use_key ) {
        open($stacks, ">${output}${type}_stacks.csv") or die "Could not open ${type}_stacks.csv $!";
    }
    open($stats,  ">${output}${type}_stats.csv") or die "Could not open ${type}_stats.csv $!";
    
    # print header row for stats file
    print $stats join( ',', map { ucfirst( lc( $_ ) ) }
        ( ( $use_key ? ($type eq 'line' ? ('method', 'line') : 'method') : 'stack_id' ), @this_stat_order ) ) . "\n";

    $index = 0;
    while( $index < scalar(@keys) ) {
        
        unless( $use_key ) {
            print $stacks ( $index + 1 ) . ",$keys[$index]\n";
        }
        print $stats join( ',',
            ( $use_key ? $keys[$index] : ( $index + 1 ),
            map { $data{$keys[$index]}->{$_} // 'NA' } @this_stat_order )
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
    print "Loading metadata . . . ";
    
    my %ret = ();
    
    open(my $fh, '<:encoding(UTF-8)', $metadata) or die "Could not open file '$metadata' $!";
    
    chomp( my $header = <$fh> );
    my @keys = map { $_ =~ s/['"]//rg } (split ',', $header)[1, -1];
    
    while (my $line = <$fh>) {
        chomp $line;
        
        my ( $id, $data ) = ( $line =~ m/(.+?),([\d.,]+)/ );
        $id =~ s/['"]//g;
        my $index = 0;
        
        $ret{$id} = {};
        for my $val ( split ',', $data ) {
            $ret{$id}->{ $keys[$index++] } = $val;
        }
    }
    
    push @stat_order, @keys;
    
    print "loaded.\n";
    
    return %ret;
}

# aggregate metadata for a particular key/stack
sub get_metadata {
    my ( $key, $data, %metrics ) = @_;
    
    my @stack_vals = split ',', $key;
    
    for my $id ( @stack_vals ) {
        ( $id ) = ( $id =~ m/\/([^\/]+?)(?:[,:]\d+)?$/ );
        if( length($id) and exists($metrics{$id}) ) {
            for my $key ( keys %{ $metrics{$id} } ) {
                $data->{$key} = ($data->{$key} // 0) + $metrics{$id}->{$key};
            }
        }
    }
}

sub compute_scores {
    my ( $type, $key, $data, %test_totals ) = @_;

    my ( $pass, $fail ) = ( $data->{pass}, $data->{fail} );
    my $perc_pass = ( $pass / $test_totals{pass} );
    my $perc_fail = ( $fail / $test_totals{fail} );
    
    # write total to make sorting a bit easier
    $data->{'total'} = $pass + $fail;
    
    # Tarantula: (%failed) / (%passed + %failed)
    $data->{'tarantula'} = ( $perc_fail / ( $perc_pass  + $perc_fail ) );
    
    # SBI: failed / ( passed + failed )
    $data->{'sbi'} = ( $fail / ( $pass + $fail ) );
    
    # Jaccard: failed / ( total_failed + passed )
    $data->{'jaccard'} = ( $fail / ( $test_totals{fail} + $pass ) );
    
    # Ochiai: failed / sqrt( total_failed * ( passed + failed ) )
    $data->{'ochiai'} = ( $fail / sqrt( $test_totals{fail} * ( $pass + $fail ) ) );
    
    # Ubiquity: ( pass + fail ) / ( total_pass + total_fail )
    $data->{'ubiquity'} = ( $pass + $fail ) / ( $test_totals{pass} + $test_totals{fail} );
    
    # Method Stats
    my ( $m_string, $m_pass, $m_fail );
    if( $type =~ /stack/ ) {
        $m_string = join ',', map /^([^:]+)/, split ',', $key;
        $m_pass = $collected_method_stacks{$m_string}->{pass};
        $m_fail = $collected_method_stacks{$m_string}->{fail};
    }
    else {
        ( $m_string ) = ( $key =~ m/^([^:,]+?)(?:,\d+)?$/ );
        $m_pass = $collected_methods{$m_string}->{pass};
        $m_fail = $collected_methods{$m_string}->{fail};
    }

    exit 1 unless length($m_string) and ( $m_pass + $m_fail );
    $data->{"m_pass"} = $m_pass;
    $data->{"m_fail"} = $m_fail;
    my ( $m_perc_pass, $m_perc_fail ) = ( $pass / ($m_pass or 1), $fail / ($m_fail or 1) );
    
    # Method Ubiquity: compute percentage of tests in which this method is called
    $data->{'method_ubiquity'} = ( $m_pass + $m_fail ) / ( $test_totals{pass} + $test_totals{fail} );
    
    # Line Method Ubiquity: compute percentage of time this is called when the enclosing method is called
    $data->{'line_method_ubiquity'} = ( $pass + $fail ) / ( $m_pass + $m_fail );
    
    # Method Tarantula: same as normal tarantula, but with method totals rather than test totals
    $data->{'m_tarantula'} = $m_perc_fail / ( $m_perc_pass + $m_perc_fail );
    
    if( $type eq 'line' ) {
        # Line Variability: difference from average number of line executions for this method, normalized by stdev
        $data->{'line_var'} =
            ( ( $pass + $fail ) - $line_stats{$m_string}->{avg} ) / ( $line_stats{$m_string}->{stdev} or 1 );
        
        # Pass Line Variability: difference from average number of line passes for this method, normalized by stdev
        $data->{'pass_line_var'} =
            ( $pass - $line_stats{$m_string}->{avg_pass} ) / ( $line_stats{$m_string}->{stdev_pass} or 1 );
        
        # Fail Line Variability: difference from average number of line fails for this method, normalized by stdev
        $data->{'fail_line_var'} =
            ( $fail - $line_stats{$m_string}->{avg_fail} ) / ( $line_stats{$m_string}->{stdev_fail} or 1 );
        
        # Fail Isolation: attempt to rank failures by variability of specific line execution
        $data->{'fail_iso_1'} = $data->{'tarantula'} * $data->{'fail_line_var'};
        $data->{'fail_iso_2'} = $data->{'m_tarantula'} * $data->{'fail_line_var'};
    }
    
    # TODO: Something more interesting, use ubiquity as further dimension for metric
}





