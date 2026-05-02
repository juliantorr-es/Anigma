#!/usr/bin/perl

use strict;
use warnings;
use File::Find;
use File::Slurp;

# Configuration
my @directories = (
    'Packages/HarmoniaModule',
);

my %files_to_skip = (
    # Skip CLI tools that use print() for user output
    'SessionEpilogueRunner.swift' => 1,
    'CathedralIntegrationDemo.swift' => 1,
    'SimpleHarnessTest.swift' => 1,
    'SimpleTest.swift' => 1,
    'USAGE_EXAMPLES.swift' => 1,
    # Add more CLI files to skip as needed
);

my $converted_count = 0;
my $file_count = 0;

sub process_file {
    my $file = $_; 
    
    # Skip CLI tools and test files
    foreach my $skip_file (keys %files_to_skip) {
        return if $file =~ /\/$skip_file$/;
    }
    
    # Only process Swift files
    return unless $file =~ /\.swift$/;
    
    my $content = read_file($file);
    
    # Check if file already has OSLog
    if ($content =~ /import\s+os\.log/ || $content =~ /import\s+os/) {
        # File already has OSLog, just convert print statements
        return if convert_print_statements(\$content, $file);
    } else {
        # File needs OSLog import and logger
        add_oslog_import(\$content);
        add_logger_declaration(\$content);
        return if convert_print_statements(\$content, $file);
    }
    
    # Write the converted content back to file
    write_file($file, $content);
    $converted_count += count_converted($content);
    $file_count++;
    print "✓ Converted $file\n";
}

sub add_oslog_import {
    my $content_ref = shift;
    
    # Find the last import statement
    if ($$content_ref =~ /^(import\s+\w+)/gm) {
        # Add OSLog import after the last import
        $$content_ref =~ s/^(import\s+\w+)/$1\nimport os.log/m;
    } else {
        # If no imports, add it after the file header
        $$content_ref =~ s/^(\n\/\/\s+\w+\.swift)/$1\nimport os.log/m;
    }
}

sub add_logger_declaration {
    my $content_ref = shift;
    
    # Find a good place to add the logger (after imports, before first class/struct)
    if ($$content_ref =~ /^(public\s+(class|struct|actor|enum)\s+\w+)/m) {
        # Add logger before the first class/struct declaration
        my $indent = "    ";
        $$content_ref =~ s/^(public\s+(class|struct|actor|enum)\s+\w+)/private let log = Logger(subsystem: "com.anigma.harmonia", category: "\L$2")\n\n$1/m;
    } elsif ($$content_ref =~ /^(class\s+\w+)/m) {
        # Add logger before the first class declaration
        my $indent = "    ";
        $$content_ref =~ s/^(class\s+\w+)/private let log = Logger(subsystem: "com.anigma.harmonia", category: "class")\n\n$1/m;
    }
}

sub convert_print_statements {
    my ($content_ref, $file) = @_;
    
    my $original_count = () = $$content_ref =~ /print\(/g;
    return 0 unless $original_count > 0;
    
    # Convert simple print statements
    $$content_ref =~ s/print\("([^"]*)"\)/log.info("$1")/g;
    
    # Convert print statements with string interpolation
    $$content_ref =~ s/print\("([^"]*)"\)/log.info("$1")/g;
    
    # Convert print statements with variables
    $$content_ref =~ s/print\(\s*(\w+)\s*\)/log.info("$1")/g;
    
    # More complex patterns would go here
    
    my $new_count = () = $$content_ref =~ /print\(/g;
    return $original_count - $new_count;
}

sub count_converted {
    my $content = shift;
    return () = $content =~ /log\.(info|error|warning|critical)\(/g;
}

# Main execution
print "Starting HarmoniaModule OSLog conversion...\n";

foreach my $dir (@directories) {
    find({ wanted => \&process_file, no_chdir => 1 }, $dir);
}

print "\n✅ Conversion complete!\n";
print "Files converted: $file_count\n";
print "Print statements converted: $converted_count\n";