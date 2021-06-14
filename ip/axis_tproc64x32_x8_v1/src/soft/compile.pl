#!/usr/bin/perl

# Input program file.
open(FD,"<","$ARGV[0]");
@lines = <FD>;

# Output binary file.
$out_file = $ARGV[0];
$out_file =~ s/.asm/.bin/;
open(FD_OUT,">","$out_file");

# Output dump file.
$out_file_dump = $out_file . "-dump";
open(FD_OUT_DUMP,">","$out_file_dump");

# Hash for data structures.
my @hash = ();

# Instruction coding.
# I-type.
$hash{instructions}{pushi}{bin} 	= "00010000";
$hash{instructions}{popi}{bin} 		= "00010001";
$hash{instructions}{mathi}{bin}		= "00010010";
$hash{instructions}{seti}{bin} 		= "00010011";
$hash{instructions}{synci}{bin}		= "00010100";
$hash{instructions}{waiti}{bin}		= "00010101";
$hash{instructions}{bitwi}{bin}		= "00010110";
$hash{instructions}{memri}{bin}		= "00010111";
$hash{instructions}{memwi}{bin}		= "00011000";
$hash{instructions}{regwi}{bin}		= "00011001";
$hash{instructions}{setbi}{bin}		= "00011010";

# J-type.
$hash{instructions}{loopnz}{bin} 	= "00110000";
$hash{instructions}{condj}{bin} 	= "00110001";
$hash{instructions}{end}{bin} 		= "00111111";

# R-type.
$hash{instructions}{math}{bin} 		= "01010000";
$hash{instructions}{set}{bin} 		= "01010001";
$hash{instructions}{sync}{bin} 		= "01010010";
$hash{instructions}{read}{bin} 		= "01010011";
$hash{instructions}{wait}{bin} 		= "01010100";
$hash{instructions}{bitw}{bin} 		= "01010101";
$hash{instructions}{memr}{bin} 		= "01010110";
$hash{instructions}{memw}{bin} 		= "01010111";
$hash{instructions}{setb}{bin} 		= "01011000";

######################################
### First pass: parse instructions ###
######################################
my $addr = 0;
foreach $line (@lines)
{
	chomp ($line);

	# Empty lines.
	if ( $line =~ m/^\s*$/ )
	{

	}

	# Comments.
	elsif ( $line =~ m/^\s*\/\// )
	{
		#print "$line\n";
	}

	# Tagged instruction (for Jump).
	elsif ( $line =~ m/\s*(.+)\s*:(.+);/ )
	{
		my $ref = $1;
		my $inst = $2;

		# Add reference entry into hash.
		$hash{refs}{$ref} = $addr;

		# Parse instruction.
		&parse_inst(\%hash, $inst, $addr);

		# Increment memory address.
		$addr++;
	}
	else
	{
		my $inst = $line;

		# Parse instruction.
		&parse_inst(\%hash, $inst, $addr);
		
		# Increment memory address.
		$addr++;
	}
}

#######################################
### Second Pass: resolve references ###
#######################################
&resolve_refs(\%hash);

###############################
### Convert to machine code ###
###############################
&convert(\%hash);

############################
### Generate output file ###
############################
@mems = (sort {$a <=> $b} keys %{$hash{memory}});
foreach $mem (@mems)
{
	$inst = $hash{memory}{$mem}{orig};
	$bin = $hash{memory}{$mem}{bin};
	print FD_OUT "$bin\n";
}

##########################
### Generate DUMP file ###
##########################
print FD_OUT_DUMP "#######################\n";
print FD_OUT_DUMP "### Memory Contents ###\n";
print FD_OUT_DUMP "#######################\n";
@mems = (sort {$a <=> $b} keys %{$hash{memory}});
foreach $mem (@mems)
{
	$inst = $hash{memory}{$mem}{orig};
	$bin = $hash{memory}{$mem}{bin};
	$hex = $hash{memory}{$mem}{hex};
	print FD_OUT_DUMP "$mem\t: $hex -> $inst\n";
}
print FD_OUT_DUMP "\n";

print FD_OUT_DUMP "###############\n";
print FD_OUT_DUMP "### Symbols ###\n";
print FD_OUT_DUMP "###############\n";
@refs = keys %{$hash{refs}};
foreach $ref (@refs)
{
	$addr = $hash{refs}{$ref};
	print FD_OUT_DUMP "$ref\t: $addr\n";
}
print FD_OUT_DUMP "\n";

####################
### Sub Routines ###
####################
sub parse_inst
{
	my ($hash_ref, $inst, $addr) = @_;

	# Remove leading spaces from instruction.
	$inst =~ s/^\s+//;

	# Remove trailing comments from instruction.
	$inst =~ s/\s*\/\/.+$//;

	# Remove trailing ;
	$inst =~ s/;//;

	##############
	### I-Type ###
	##############

	# pushi p, $ra, $rb, imm
	if ( $inst =~ m/pushi\s+(\d+)\s*,\s*\$(\d+)\s*,\s*\$(\d+)\s*,\s*(\-{0,1}\d+)/ )
	{
		my $page 	= $1;
		my $ra 		= $2;
		my $rb 		= $3;
		my $imm 	= $4;

		# Push instruction into hash.
		$$hash_ref{memory}{$addr}{inst} = "I-type:pushi:$page:0:0:$rb:$ra:0:$imm";
		$$hash_ref{memory}{$addr}{orig} = $inst;
	}

	# popi p, $r
	if ( $inst =~ m/popi\s+(\d+)\s*,\s*\$(\d+)/ )
	{
		my $page	= $1;
		my $r		= $2;

		# Push instruction into hash.
		$$hash_ref{memory}{$addr}{inst} = "I-type:popi:$page:0:0:$r:0:0:0";
		$$hash_ref{memory}{$addr}{orig} = $inst;
	}

	# mathi p, $ra, $rb oper imm.
	if ( $inst =~ m/mathi\s+(\d+)\s*,\s*\$(\d+)\s*,\s*\$(\d+)\s*([\+\-\*])\s*(0?x?\-?[0-9a-fA-F]+)/)
	{
		my $page	= $1;
		my $ra		= $2;
		my $rb		= $3;
		my $oper	= $4;
		my $imm		= $5;

		# Push instruction into hash.
		$$hash_ref{memory}{$addr}{inst} = "I-type:mathi:$page:0:$oper:$ra:$rb:0:$imm";
		$$hash_ref{memory}{$addr}{orig} = $inst;
	}

	# seti ch, p, $r, t
	if ( $inst =~ m/seti\s+(\d+)\s*,\s*(\d+)\s*,\s*\$(\d+)\s*,\s*(0?x?[0-9a-fA-F]+)/)
	{
		my $ch		= $1;
		my $page	= $2;
		my $ra		= $3;
		my $t		= $4;

		# Push instruction into hash.
		$$hash_ref{memory}{$addr}{inst} = "I-type:seti:$page:$ch:0:0:$ra:0:$t";
		$$hash_ref{memory}{$addr}{orig} = $inst;
	}

	# synci t
	if ( $inst =~ m/synci\s+(\d+)/)
	{
		my $t		= $1;

		# Push instruction into hash.
		$$hash_ref{memory}{$addr}{inst} = "I-type:synci:0:0:0:0:0:0:$t";
		$$hash_ref{memory}{$addr}{orig} = $inst;
	}

	# waiti ch, t
	if ( $inst =~ m/waiti\s+(\d+),\s*(\d+)/)
	{
		my $ch		= $1;
		my $t		= $2;

		# Push instruction into hash.
		$$hash_ref{memory}{$addr}{inst} = "I-type:waiti:0:$ch:0:0:0:0:$t";
		$$hash_ref{memory}{$addr}{orig} = $inst;
	}

	# bitwi p, $ra, $rb oper imm.
	if ( $inst =~ m/bitwi\s+(\d+)\s*,\s*\$(\d+),\s*\$(\d+)\s*([&|<>^]+)\s*(0?x?\-?[0-9a-fA-F]+)/)
	{
	
		my $page	= $1;
		my $ra		= $2;
		my $rb		= $3;
		my $oper	= $4;
		my $imm		= $5;

		# Push instruction into hash.
		$$hash_ref{memory}{$addr}{inst} = "I-type:bitwi:$page:0:$oper:$ra:$rb:0:$imm";
		$$hash_ref{memory}{$addr}{orig} = $inst;
	}

	# bitwi p, $ra, ~imm.
	if ( $inst =~ m/bitwi\s+(\d+)\s*,\s*\$(\d+),\s*~\s*(0?x?\-?[0-9a-fA-F]+)/)
	{
	
		my $page	= $1;
		my $ra		= $2;
		my $oper	= "~";
		my $imm		= $3;

		# Push instruction into hash.
		$$hash_ref{memory}{$addr}{inst} = "I-type:bitwi:$page:0:$oper:$ra:0:0:$imm";
		$$hash_ref{memory}{$addr}{orig} = $inst;
	}

	# memri p, $r, imm.
	if ( $inst =~ m/memri\s+(\d+)\s*,\s*\$(\d+),\s*(0?x?\-?[0-9a-fA-F]+)/)
	{
	
		my $page	= $1;
		my $r		= $2;
		my $imm		= $3;

		# Push instruction into hash.
		$$hash_ref{memory}{$addr}{inst} = "I-type:memri:$page:0:0:$r:0:0:$imm";
		$$hash_ref{memory}{$addr}{orig} = $inst;
	}

	# memwi p, $r, imm.
	if ( $inst =~ m/memwi\s+(\d+)\s*,\s*\$(\d+),\s*(0?x?\-?[0-9a-fA-F]+)/)
	{
	
		my $page	= $1;
		my $r		= $2;
		my $imm		= $3;

		# Push instruction into hash.
		$$hash_ref{memory}{$addr}{inst} = "I-type:memwi:$page:0:0:0:0:$r:$imm";
		$$hash_ref{memory}{$addr}{orig} = $inst;
	}

	# regwi p, $r, imm.
	if ( $inst =~ m/regwi\s+(\d+)\s*,\s*\$(\d+),\s*(0?x?\-?[0-9a-fA-F]+)/)
	{
	
		my $page	= $1;
		my $r		= $2;
		my $imm		= $3;

		# Push instruction into hash.
		$$hash_ref{memory}{$addr}{inst} = "I-type:regwi:$page:0:0:$r:0:0:$imm";
		$$hash_ref{memory}{$addr}{orig} = $inst;
	}

	# setbi ch, p, $r, t
	if ( $inst =~ m/setbi\s+(\d+)\s*,\s*(\d+)\s*,\s*\$(\d+)\s*,\s*(0?x?[0-9a-fA-F]+)/)
	{
		my $ch		= $1;
		my $page	= $2;
		my $ra		= $3;
		my $t		= $4;

		# Push instruction into hash.
		$$hash_ref{memory}{$addr}{inst} = "I-type:setbi:$page:$ch:0:0:$ra:0:$t";
		$$hash_ref{memory}{$addr}{orig} = $inst;
	}

	##############
	### J-Type ###
	##############
	
	# loopnz p, $r, @label
	if ( $inst =~ m/loopnz\s+(\d+)\s*,\s*\$(\d+)\s*,\s*\@(.+)/)
	{
		my $page	= $1;
		my $oper	= "+";
		my $r		= $2;
		my $label	= $3;

		# Push instruction into hash.
		$$hash_ref{memory}{$addr}{inst} = "J-type:loopnz:$page:$oper:$r:$r:0:\@$label";
		$$hash_ref{memory}{$addr}{orig} = $inst;
	}

	# condj p, $ra op $rb, @label
	if ( $inst =~ m/condj\s+(\d+)\s*,\s*\$(\d+)\s*([<>=!]+)\s*\$(\d+)\s*,\s*\@(.+)/)
	{
		my $page	= $1;
		my $ra		= $2;
		my $op		= $3;
		my $rb		= $4;
		my $label	= $5;

		# Push instruction into hash.
		$$hash_ref{memory}{$addr}{inst} = "J-type:condj:$page:$op:0:$ra:$rb:\@$label";
		$$hash_ref{memory}{$addr}{orig} = $inst;
	}

	# end
	if ( $inst =~ m/end/ )
	{
		# Push instruction into hash.
		$$hash_ref{memory}{$addr}{inst} = "J-type:end:0:0:0:0:0:0";
		$$hash_ref{memory}{$addr}{orig} = $inst;
	}

	##############
	### R-Type ###
	##############

	# math p, $ra, $rb oper $rc
	if ( $inst =~ m/math\s+(\d+)\s*,\s*\$(\d+)\s*,\s*\$(\d+)\s*([\+\-\*]+)\s*\$(\d+)/)
	{
		my $page	= $1;
		my $ra		= $2;
		my $rb		= $3;
		my $oper	= $4;
		my $rc		= $5;

		# Push instruction into hash.
		$$hash_ref{memory}{$addr}{inst} = "R-type:math:$page:0:$oper:$ra:$rb:$rc:0:0:0:0:0";
		$$hash_ref{memory}{$addr}{orig} = $inst;
	}

	# set ch, p, $ra, $rb, $rc, $rd, $re, $rt
	if ( $inst =~ m/set\s+(\d+)\s*,\s*(\d+)\s*,\s*\$(\d+)\s*,\s*\$(\d+),\s*\$(\d+),\s*\$(\d+),\s*\$(\d+),\s*\$(\d+)/)
	{
		my $ch		= $1;
		my $page	= $2;
		my $ra		= $3;
		my $rb		= $4;
		my $rc		= $5;
		my $rd		= $6;
		my $re		= $7;
		my $rt		= $8;

		# Push instruction into hash.
		$$hash_ref{memory}{$addr}{inst} = "R-type:set:$page:$ch:0:0:$ra:$rt:$rb:$rc:$rd:$re:0";
		$$hash_ref{memory}{$addr}{orig} = $inst;
	}

	# sync p, $r
	if ( $inst =~ m/sync\s+(\d+)\s*,\s*\$(\d+)/)
	{
		my $page	= $1;
		my $r		= $2;

		# Push instruction into hash.
		$$hash_ref{memory}{$addr}{inst} = "R-type:sync:$page:0:0:0:0:$r:0:0:0:0:0";
		$$hash_ref{memory}{$addr}{orig} = $inst;
	}

	# read ch, p, oper $r
	if ( $inst =~ m/read\s+(\d+)\s*,\s*(\d+)\s*,\s*(upper|lower)\s+\$(\d+)/)
	{
		my $ch		= $1;
		my $page	= $2;
		my $oper	= $3;
		my $ra		= $4;

		# Push instruction into hash.
		$$hash_ref{memory}{$addr}{inst} = "R-type:read:$page:$ch:$oper:$ra:0:0:0:0:0:0:0";
		$$hash_ref{memory}{$addr}{orig} = $inst;
	}

	# wait ch, p, $r
	if ( $inst =~ m/wait\s+(\d+)\s*,\s*(\d+)\s*,\s*\$(\d+)/)
	{
		my $ch		= $1;
		my $page	= $2;
		my $r		= $3;

		# Push instruction into hash.
		$$hash_ref{memory}{$addr}{inst} = "R-type:wait:$page:$ch:0:0:0:$r:0:0:0:0:0";
		$$hash_ref{memory}{$addr}{orig} = $inst;
	}

	# bitw p, $ra, $rb oper $rc
	if ( $inst =~ m/bitw\s+(\d+)\s*,\s*\$(\d+),\s*\$(\d+)\s*([&|<>^]+)\s*\$(\d+)/)
	{
	
		my $page	= $1;
		my $ra		= $2;
		my $rb		= $3;
		my $oper	= $4;
		my $rc		= $5;


		# Push instruction into hash.
		$$hash_ref{memory}{$addr}{inst} = "R-type:bitw:$page:0:$oper:$ra:$rb:$rc:0:0:0:0:0";
		$$hash_ref{memory}{$addr}{orig} = $inst;
	}

	# bitw p, $ra, ~$rb.
	if ( $inst =~ m/bitw\s+(\d+)\s*,\s*\$(\d+),\s*~\s*\$(\d+)/)
	{
	
		my $page	= $1;
		my $ra		= $2;
		my $oper	= "~";
		my $rb		= $3;

		# Push instruction into hash.
		$$hash_ref{memory}{$addr}{inst} = "R-type:bitw:$page:0:$oper:$ra:0:$rb:0:0:0:0:0";
		$$hash_ref{memory}{$addr}{orig} = $inst;
	}

	# memr p, $ra, $rb
	if ( $inst =~ m/memr\s+(\d+)\s*,\s*\$(\d+),\s*\$(\d+)\s*/)
	{
	
		my $page	= $1;
		my $ra		= $2;
		my $rb		= $3;

		# Push instruction into hash.
		$$hash_ref{memory}{$addr}{inst} = "R-type:memr:$page:0:0:$ra:$rb:0:0:0:0:0:0";
		$$hash_ref{memory}{$addr}{orig} = $inst;
	}

	# memr p, $ra, $rb
	if ( $inst =~ m/memw\s+(\d+)\s*,\s*\$(\d+),\s*\$(\d+)\s*/)
	{
	
		my $page	= $1;
		my $ra		= $2;
		my $rb		= $3;

		# Push instruction into hash.
		$$hash_ref{memory}{$addr}{inst} = "R-type:memw:$page:0:0:0:$rb:$ra:0:0:0:0:0";
		$$hash_ref{memory}{$addr}{orig} = $inst;
	}

	# setb ch, p, $ra, $rb, $rc, $rd, $re, $rt
	if ( $inst =~ m/setb\s+(\d+)\s*,\s*(\d+)\s*,\s*\$(\d+)\s*,\s*\$(\d+),\s*\$(\d+),\s*\$(\d+),\s*\$(\d+),\s*\$(\d+)/)
	{
		my $ch		= $1;
		my $page	= $2;
		my $ra		= $3;
		my $rb		= $4;
		my $rc		= $5;
		my $rd		= $6;
		my $re		= $7;
		my $rt		= $8;

		# Push instruction into hash.
		$$hash_ref{memory}{$addr}{inst} = "R-type:setb:$page:$ch:0:0:$ra:$rt:$rb:$rc:$rd:$re:0";
		$$hash_ref{memory}{$addr}{orig} = $inst;
	}
}

sub resolve_refs
{
	my ($hash_ref) = @_;

	my @mems = (sort {$a <=> $b} keys %{$$hash_ref{memory}});
	foreach $mem (@mems)
	{
		my $inst = $hash{memory}{$mem}{inst};

		if ( $inst =~ m/\@(.+)$/ )
		{
			my $ref = $1;

			# Get symbol from table.
			if ( exists $$hash_ref{refs}{$ref} )
			{
				# Get symbol address.
				my $addr = $$hash_ref{refs}{$ref};

				# Replace symbol with actual address.	
				$inst =~ s/\@(.+)$/$addr/;

				# Write value back into hash.
				$$hash_ref{memory}{$mem}{inst} = $inst;
			}
			else
			{
				print "ERROR: Could not resolve $ref symbol. Aborting.\n";
				exit(0);
			}
		}
	}
}

sub convert
{
	my ($hash_ref) = @_;

	my @mems = (sort {$a <=> $b} keys %{$$hash_ref{memory}});
	foreach $mem (@mems)
	{
		# Get instructions.
		my $inst = $$hash_ref{memory}{$mem}{inst};

		# Split parameters.
		my @params = split(/:/,$inst);

		# I-type instruction.
		# I-type:opcode:page:channel:oper:ra:rb:imm.
		if ( $params[0] eq "I-type" )
		{
			# Translate instruction to machine code.
			if ( exists $$hash_ref{instructions}{$params[1]} )
			{
				my $i = $$hash_ref{instructions}{$params[1]}{bin};
				my $page	= &unsigned2bin($params[2],3);
				my $ch		= &unsigned2bin($params[3],3);
				my $oper	= &oper2bin($params[4]);
				my $ra		= &unsigned2bin($params[5],5);
				my $rb		= &unsigned2bin($params[6],5);
				my $rc		= &unsigned2bin($params[7],5);
				my $imm		= &integer2bin($params[8],31);

				my $code = $i . $page . $ch . $oper . $ra . $rb . $rc . $imm;
				my $code_h = sprintf("%x", oct("0b$code"));

				# Write binary value back into hash.
				$$hash_ref{memory}{$mem}{bin} = $code;
				$$hash_ref{memory}{$mem}{hex} = $code_h;
			}
			else
			{
				print "ERROR: Instruction $params[1] not found in catalog. Aborting.\n";
				exit(1);
			}
		}

		# J-type instruction.
		# J-type:opcode:page:oper:ra:rb:rc:addr.
		if ( $params[0] eq "J-type" )
		{
			# Translate instruction to machine code.
			if ( exists $$hash_ref{instructions}{$params[1]} )
			{
				my $i = $$hash_ref{instructions}{$params[1]}{bin};
				my $page	= &unsigned2bin($params[2],3);
				my $z3		= &unsigned2bin(0,3);
				my $oper	= &oper2bin($params[3]);
				my $ra		= &unsigned2bin($params[4],5);
				my $rb		= &unsigned2bin($params[5],5);
				my $rc		= &unsigned2bin($params[6],5);
				my $z15		= &unsigned2bin(0,15);
				my $addr	= &unsigned2bin($params[7],16);

				my $code = $i . $page . $z3 . $oper . $ra . $rb . $rc . $z15 . $addr;
				my $code_h = sprintf("%x", oct("0b$code"));

				# Write binary value back into hash.
				$$hash_ref{memory}{$mem}{bin} = $code;
				$$hash_ref{memory}{$mem}{hex} = $code_h;
			}
			else
			{
				print "ERROR: Instruction $params[1] not found in catalog. Aborting.\n";
				exit(1);
			}

		}

		# R-type instruction.
		# R-type:opcode:page:channel:oper:ra:rb:rc:rd:re:rf:rg:rh.
		if ( $params[0] eq "R-type" )
		{
			# Translate instruction to machine code.
			if ( exists $$hash_ref{instructions}{$params[1]} )
			{
				my $i = $$hash_ref{instructions}{$params[1]}{bin};
				my $page	= &unsigned2bin($params[2],3);
				my $ch		= &unsigned2bin($params[3],3);
				my $oper	= &oper2bin($params[4]);
				my $ra		= &unsigned2bin($params[5],5);
				my $rb		= &unsigned2bin($params[6],5);
				my $rc		= &unsigned2bin($params[7],5);
				my $rd		= &unsigned2bin($params[8],5);
				my $re		= &unsigned2bin($params[9],5);
				my $rf		= &unsigned2bin($params[10],5);
				my $rg		= &unsigned2bin($params[11],5);
				my $rh		= &unsigned2bin($params[12],5);
				my $z6		= &unsigned2bin(0,6);

				my $code = $i . $page . $ch . $oper . $ra . $rb . $rc . $rd . $re . $rf . $rg . $rh . $z6;
				my $code_h = sprintf("%x", oct("0b$code"));

				# Write binary value back into hash.
				$$hash_ref{memory}{$mem}{bin} = $code;
				$$hash_ref{memory}{$mem}{hex} = $code_h;
			}
			else
			{
				print "ERROR: Instruction $params[1] not found in catalog. Aborting.\n";
				exit(1);
			}
		}

	}
}

sub integer2bin
{
	my $dec 	= shift;
	my $bits	= shift;

	# Number goes from -2^(bits-1) to 2^(bits-1) - 1
	$min = -2**($bits-1);
	$max = 2**($bits-1) - 1;

	# Check if number is 0x form.
	if ( $dec =~ m/0x/ )
	{
		my $mmax = 2**$bits - 1;

		$dec = hex($dec);

		if ( $dec > $mmax ) 
		{
			print "ERROR: number $dec bigger than $mmax\n";
			exit(1);
		}

		# Perform conversion.
		$f = "." . $bits . "b";
		return sprintf("%$f", $dec);
	}

	# Check maximum and minimum.
	if ( $dec < $min )
	{
		print "ERROR: number $dec smaller than $min\n";
		exit(1);
	}

	if ( $dec > $max ) 
	{
		print "ERROR: number $dec bigger than $max\n";
		exit(1);
	}

	# Check if number is negative.
	if ( $dec < 0 )
	{
		$dec = $dec + 2**$bits;
	}

	# Perform conversion.
	$f = "." . $bits . "b";
	return sprintf("%$f", $dec);
}

sub unsigned2bin
{
	my $dec 	= shift;
	my $bits	= shift;

	# Number goes from 0 to 2^(bits-1) - 1
	$max = 2**$bits - 1;

	# Check if number is 0x form.
	if ( $dec =~ m/0x/ )
	{
		$dec = hex($dec);
	}

	if ( $dec > $max ) 
	{
		print "ERROR: number $dec bigger than $max\n";
		exit(1);
	}

	# Perform conversion.
	$f = "." . $bits . "b";
	return sprintf("%$f", $dec);
}

sub oper2bin
{
	my $op 	= shift;

	if ( $op eq "0" )
	{
		return "0000";
	}

	# Conditional block.
	elsif ( $op eq ">" )
	{
		return "0000";
	}
	elsif ( $op eq ">=" )
	{
		return "0001";
	}
	elsif ( $op eq "<" )
	{
		return "0010";
	}
	elsif ( $op eq "<=" )
	{
		return "0011";
	}
	elsif ( $op eq "==" )
	{
		return "0100";
	}
	elsif ( $op eq "!=" )
	{
		return "0101";
	}

	# Alu (math).
	elsif ( $op eq "+" )
	{
		return "1000";
	}

	elsif ( $op eq "-" )
	{
		return "1001";
	}

	elsif ( $op eq "*" )
	{
		return "1010";
	}

	# Alu (bitw).
	elsif ( $op eq "&" )
	{
		return "0000";
	}

	elsif ( $op eq "|" )
	{
		return "0001";
	}

	elsif ( $op eq "^" )
	{
		return "0010";
	}

	elsif ( $op eq "~" )
	{
		return "0011";
	}

	elsif ( $op eq "<<" )
	{
		return "0100";
	}

	elsif ( $op eq ">>" )
	{
		return "0101";
	}

	# Read (upper/lower bits).
	elsif ( $op eq "upper" )
	{
		return "1010";	
	}

	elsif ( $op eq "lower" )
	{
		return "0101";	
	}

	# Not recognized.
	else
	{
		print "ERROR: operation $op not recognized. Aborting\n";
	}

}

