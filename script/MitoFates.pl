#!/usr/bin/perl
#  Author:  Yoshinori Fukasawa and Kenichiro Imai
#  Organizations:  Department of Computational Biology, University of Tokyo
#  Copyright (C) 2014, Yoshinori Fukasawa and Kenichiro Imai, All rights reserved.
#
#  Forked and modified by Paul Horton in 2024/01/28
#  Those modifications are minor; cosmetic changes to code, more informative error messages etc.

use 5.028;#  (In 2024) Perl 5.28 is old but not ancient.  Someday maybe require version 5.32 for chained comparisons.

BEGIN{
    use FindBin qw ($Bin);
    use lib "$Bin/bin/modules";
}

use strict;
use warnings;
use MotifPosition;
use MotifHelixPosition;

my $VERSION = "v1.1";

######### Initialize variables ##########
my $scriptDir = $Bin;
####################


#----------  Process ARGV  ----------
my $usage=  "Usage: $0 MultiFastaFile {fungi,metazoa,plant}\n";

@ARGV == 2   or   die $usage;

my $seqs_pathname=  shift @ARGV;

-f $seqs_pathname
    or  die  "Error could not find file '$seqs_pathname';\n$usage";

my $osFlag=  shift @ARGV;


####################
my @Tom20Motif_array;
my @Helix_array;
my @MTSMotif_array;
#to print out motifs in the header, sorted motif list is required.
my @motifs = sort(MotifHelixPosition->new()->getMotifs());
####################

# Get Positions for seqs.
open  my $seqs_fh, '<', $seqs_pathname
    or    die  "Error; could not open file $seqs_pathname: $!";
{
    local $/ ="\n>";

    while( my $line= <$seqs_fh>){

    # Turn $/ into original.
	local $/ = "\n";

	chomp($line);
	my @head_seq = split(/\n/, $line);
	my $id = shift @head_seq;
	my $sequence = join("", @head_seq);
	chomp($sequence);
	$id =~ s/>//g; #for the first header

	my @posArray = findMotifPosition(Seq => $sequence, Length=>100, Pattern=>"pcbp2");
	push @Tom20Motif_array, \@posArray;

	my $searchSpace = 30;
	my $mhp = MotifHelixPosition->new();
	$mhp->calcHmoment(substr($sequence,0, $searchSpace), 96, 8.5);
	push @Helix_array, join(
	    "-",
	    $mhp->getPos,
	    $mhp->getPos+$mhp->getWindowSize-1,
	    $mhp->getMoment >= 2 ? "high" : "low"
	    );
	my $ref = $mhp->searchAndGetPositions($sequence, $searchSpace);

	if($ref){
	    push @MTSMotif_array, $ref;
	}
	##### <<

    }
}

## Prediction of Presequence
my @resultPS = `perl $Bin/bin/predictPreSeq.pl $seqs_pathname`;


## Prediction of CleavageSite
my @resultCS = `perl $Bin/bin/cleavage.pl --gamma --svm --$osFlag $seqs_pathname`;

## Print header
print "Sequence ID\tProbability of presequence\tPrediction\tCleavage site (processing enzyme)\tNet charge\tPositions for TOM20 recognition motif (deliminated by comma)\tPosition of amphypathic alpha-helix\t";

print join("\t", @motifs);
print "\n";

for(0..$#resultPS){
    chomp($resultPS[$_]);
    chomp($resultCS[$_]);
    my ($id,$PreseqProb,$preSeqLabel) = split(/\t/,$resultPS[$_]);
    my ($id2, $mppProb, $preposi, $netcharge, $fragment, $oct1PWMscore, $Icp55PWMscore) = split(/\t/,$resultCS[$_]);

    # Prediction result
    printf "$id\t%0.3f\t$preSeqLabel\t$preposi\t%0.3f\t",$PreseqProb, $netcharge;
    # Tom20 motif
    print join(",", @{$Tom20Motif_array[$_]}), "\t";
    # helix
    print $Helix_array[$_], "\t";
    # MTS motifs
    printMTSMotif($MTSMotif_array[$_]);
    print "\n";
}

sub printMTSMotif
{
    if(@_ != 1){
	print STDERR "\tError\n";
	return 0;
    }

    my $ref = shift;
    foreach my $motif (sort keys %{$ref}){
	if(@{$ref->{$motif}}){
	    print join(",", @{$ref->{$motif}});
	} else {
	    print "-";
	}
	print "\t";
    }
}
