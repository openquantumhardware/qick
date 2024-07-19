#!/usr/bin/perl
# This file generates the fir.tcl file to be run from vivado.
# Copy fir coefficient files. One IP per .coe file will be created.
# Copy generated .xci files to avoid generating FIR cores every time.

open(my $file, "$ARGV[0]") or die "Could not open file '$ARGV[0]' $!";
my @lines = <$file>;

open(my $out_tcl, ">", "fir.tcl") or die "Could not open file fir.tcl $!";
open(my $out_add, ">", "add.tcl") or die "Could not open file fir.tcl $!";

@out = `ls coef/*.coe`;
foreach (@out)
{
	chomp($_);
	$fir = $_;
	$fir =~ s/coef\///g;
	$fir =~ s/.coe//g;

	print $out_add ("add_files ./fir/$fir/$fir.xci\n");

	foreach my $line (@lines)
	{
		my $temp = $line;
		chomp($temp);
		$temp =~ s/<FIR>/$fir/g;
		print $out_tcl ("$temp\n");
	}
}

