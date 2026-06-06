#! /usr/local/bin/perl
open FH,$ARGV[0];
my @fasta=<FH>;
close FH;
open FH1,$ARGV[1];
my @name=<FH1>;
close FH1;
for (my $i=0;$i<scalar(@fasta);$i++){
	if($fasta[$i]=~/>/){
		chomp $fasta[$i];
		my $size=scalar(split(",",$name[($i+1)/2]));
		#;size=9830;
		if($ARGV[3]){
		$fasta[$i]=$fasta[$i].';barcodelabel='.$ARGV[3].';size='.$size.';'."\n";
		#;barcodelabel=MCK1;
		}
		else{
		$fasta[$i]=$fasta[$i].';size='.$size.';'."\n";
		}
		print $fasta[$i];
	}
	else{
	chomp($fasta[$i]);
	$fasta[$i]=~s/\.//gi;
	$fasta[$i]=~s/\-//gi;
	if($ARGV[2]eq "f"){
		$fasta[$i]=~s/A/H/gi;
		$fasta[$i]=~s/T/A/gi;
		$fasta[$i]=~s/H/T/gi;
		$fasta[$i]=~s/C/H/gi;
		$fasta[$i]=~s/G/C/gi;
		$fasta[$i]=~s/H/G/gi;
		$fasta[$i]=reverse($fasta[$i]);
	}
	print $fasta[$i]."\n";}
#}
#	chomp $arr[$i];
#	for (my $j=0;$j<scalar(@arr1);$j++){
#		 chomp $arr1[$j];
#		if ($arr1[$j] eq ">".$arr[$i]){
#			chomp $arr1[$j+1];
#			print $arr1[$j]."\n".$arr1[$j+1]."\n";
#		}
#	}

}


