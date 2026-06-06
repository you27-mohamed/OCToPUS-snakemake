#! /usr/local/bin/perl
#.....................License.................................
#	 IPED a Software for NextGeneration sequencing data denoising
#    Copyright (C) 2014  <M.Mysara et al>

#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.

#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.

#   You should have received a copy of the GNU General Public License
#   along with this program; if not, write to the Free Software
#   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
	
#......................Packages Used..........................
use strict;
use Cwd;
use Getopt::Std;
use File::Basename;
my %opts;
my $diffs;
my $group;
getopt('fncpodgqiFRID',\%opts);
my @options=('f','n','c','p','o','d','g','q','i','F','R','I','D');
foreach my $value(@options){
	for(my $a=0;$a<17;$a=$a+2){
		my $temp_Value = '_'.$value;
		if($temp_Value eq $ARGV[$a]){$opts{$value}=$ARGV[$a+1];}
	}
}
my $logfile="";
if( !defined($opts{o})  ){print "No Output path spacified\n";usage();exit;}
if(!defined($opts{i})){$logfile=int(rand(1000000000000000));}else{$logfile=$opts{i};}
my $logfile_num=$logfile;
$logfile='IPED_'.$logfile.'.logfile';
unlink $logfile;
my $PATH=$ENV{'PWD'}."/Temp/";
system "rm -rf Temp";
mkdir("Temp");
system "rm -rf temp_split";
mkdir("temp_split");
if(!defined($opts{p})){$opts{p}=1;}
if(!defined($opts{c}) ||!defined($opts{q})){
	if(!defined($opts{F}) ||!defined($opts{R})){
		usage();exit;
	}
	else{
	#No contig qual file inserted, need to make the contigs
		print "....IPED: Running modified make.contigs....\n";
		if(!defined($opts{D})){$opts{D}=6;}if(!defined($opts{I})){$opts{I}=20;}
		system "\.\/mothur \"\#set\.dir(output=$PATH);make\.contigs(ffastq=$opts{F},rfastq=$opts{R},deltaq=$opts{D},insert=$opts{I})\" >> ./temp_split/$logfile";
		$opts{c}=$opts{F};
		$opts{c}=~s/fastq/trim\.contigs\.fasta/;
		$opts{q}=$opts{F};
		$opts{q}=~s/fastq/contigs\.qual/;
		$opts{c} = basename($opts{c});
		$opts{c}="./Temp/".$opts{c};
		$opts{q} = basename($opts{q});
		$opts{q}="./Temp/".$opts{q};
		my $dir=$opts{o}.'IPED_Final/'.$logfile_num;
		mkdir($dir);
		system "cp $opts{q} $dir\/";
		system "cp $opts{c} $dir\/";
	}
}
else{}
if(!defined($opts{f}) || !defined($opts{n}) ){print "No fasta or/nor name file inserted\n";usage();exit;}
#Simplification of the qual file
my $temp_accnos="List.accnos";
system "grep \">\" $opts{f} \| perl -pe \"s/\>//gi\" > ./$temp_accnos";
#extraction of ID from the initial contig and qual file, the ID are extracted from the final fasta
system "\.\/mothur \"\#set\.dir(output=$PATH);get.seqs(accnos=$temp_accnos,fasta=$opts{c},qfile=$opts{q})\" >> ./temp_split/$logfile";
$opts{c} = basename($opts{c});
$opts{c}="./Temp/".$opts{c};
$opts{c}=~s/\.([\w]+)$/\.pick\.$1/gi;
$opts{q} = basename($opts{q});
$opts{q}="./Temp/".$opts{q};
$opts{q}=~s/\.([\w]+)$/\.pick\.$1/gi;
system "perl -pe \"s/\\n/\\t\#/g\" -i $opts{q}";
system "perl -pe \"s/\\t\\#\\>/\\n/g\" -i $opts{q}";
system "perl -pe \"s/ /\;/g\" -i $opts{q}";
system "perl -pe \"s/\\>//g\" -i $opts{q}";
#sorting of contig, qual, and name file
system "\.\/mothur \"\#set\.dir(output=$PATH);sort.seqs(fasta=$opts{c},accnos=accnos,name=$opts{n},accnos=./$temp_accnos,taxonomy=$opts{q})\" >> ./temp_split/$logfile";
$opts{n} = basename($opts{n});
$opts{n}="./Temp/".$opts{n};
$opts{n}=~s/\.([\w]+)$/\.sorted\.$1/gi;
$opts{c} = basename($opts{c});
$opts{c}="./Temp/".$opts{c};
$opts{c}=~s/\.([\w]+)$/\.sorted\.$1/gi;
$opts{q} = basename($opts{q});
$opts{q}="./Temp/".$opts{q};
$opts{q}=~s/\.([\w]+)$/\.sorted\.$1/gi;
system "perl -pe \"s/;/ /g\" -i $opts{q}";
system "perl -pe \"s/\^/\>/g\" -i $opts{q}";
system "perl -pe \"s/\\t\\#/\\n/g\" -i $opts{q}";

if(!defined($opts{d})){
	print "....IPED: Getting the Differences....\n";
	open FASTA,$opts{f} or die "....Error: unable to open \"$opts{f}\", make sure you used the complete path!.... \n";
	my @FASTA=<FASTA>;
	close FASATA;
	my $sequence="";
	my $count=0;
	for(my $k=0;$k<scalar(@FASTA);$k++){
		if($FASTA[$k]=~/>/){$count++;}
		else{
			chomp($FASTA[$k]);
			$sequence=$sequence.$FASTA[$k];}
	}
	$sequence=~s/\.//gi;
	$sequence=~s/\-//gi;
	my $length=length($sequence)/$count;
	my $qflage=0;
	for(my $p=100;$qflage==0;$p=$p+100){
		if($length>$p){$diffs=$p/100;}
		else{
			#$diffs=$diffs+1;
			$qflage=1;
		}
	}
}
else{$diffs=$opts{d};}
 unless (-e $opts{c}) {
	print "....Error: unable to open \"$opts{c}\", make sure you used the complete PATH!....\n"; exit;
 }
 unless (-d $opts{o}) {
	print "....Error: unable to print to \"$opts{o}\", make sure you used the complete PATH!....\n"; exit;
 }
if(defined($opts{g})){$group=$opts{g};}
open FH,$opts{f} or die "....Error: unable to open \"$opts{f}\", make sure you used the complete PATH!....\n";
my @seq=<FH>;
close FH;
open FH,$opts{n} or die "....Error: unable to open \"$opts{n}\", make sure you used the complete PATH!....\n";
my @name=<FH>;
close FH;
open FH,$opts{c} or die "....Error: unable to open \"$opts{c}\", make sure you used the complete PATH!....\n";
my @seq_con=<FH>;
close FH;
open FH,$opts{q} or die "....Error: unable to open \"$opts{q}\", make sure you used the complete PATH!....\n";
my @qual_con=<FH>;
close FH;
my $core=$opts{p};
my $seq_len=scalar(@seq)/2;
my $seq_frac=int($seq_len/$core);
my $reminder=$seq_len%$core;


my $i=0;
my $file='./temp_split/'.$i.'.fasta';
my $file1='./temp_split/'.$i.'.name';
my $file2='./temp_split/'.$i.'.cont.fasta';
my $file3='./temp_split/'.$i.'.cont.qual';
print "....IPED: Splitting. Inputs...\n";
foreach $i(0..$core-1){
	$file='./temp_split/'.$i.'.fasta';
        $file1='./temp_split/'.$i.'.name';
		my $file2='./temp_split/'.$i.'.cont.fasta';
		my $file3='./temp_split/'.$i.'.cont.qual';
        open FH,">>",$file;
        open FH1,">>",$file1;
		open FH2,">>",$file2;
		open FH3,">>",$file3;
        for(my $j=($i*$seq_frac*2);$j<($i+1)*$seq_frac*2;$j++){
        	print FH $seq[$j];
			print FH2 $seq_con[$j];
			print FH3 $qual_con[$j];
		my $remind=$j%2;
		if($remind){}
		else{print FH1 $name[($j/2)];}
        }
        close FH;
		close FH1;
		close FH2;
		close FH3;
}
my $i=$core-1;
my $file='./temp_split/'.$i.'.fasta';
my $file1='./temp_split/'.$i.'.name';
my $file2='./temp_split/'.$i.'.cont.fasta';
my $file3='./temp_split/'.$i.'.cont.qual';
open FH, ">>",$file;
open FH1,">>",$file1;
open FH2,">>",$file2;
open FH3,">>",$file3;
for(my $j=($core)*$seq_frac*2;$j<($core*$seq_frac*2)+($reminder*2);$j++){
	print FH $seq[$j];
	print FH2 $seq_con[$j];
	print FH3 $qual_con[$j];
	my $remind=$j%2;
        if($remind){}
        else{print FH1 $name[($j/2)];}

}
close FH;
close FH1;
close FH2;
close FH3;

###########
print "....IPED: Running the Classifier....\n";

foreach my $child (0..$core-1) {
	my $file_='./temp_split/'.$child.'.Result';
        unlink $file_;# or warn "Could not unlink $file_: $!";
        my $file='./temp_split/'.$child.'.fasta';
	my $file1='./temp_split/'.$child.'.name';
	my $file2='./temp_split/'.$child.'.cont.fasta';
	my $file3='./temp_split/'.$child.'.cont.qual';
	my $pid = fork();
        if ($pid == -1) {
        	die;
        }
	elsif ($pid == 0) {
		system  "echo \"perl IPED.pl $file $file1 $file2 $file3 $child\" >> ./temp_split/$logfile";
                exec "perl IPED.pl $file $file1 $file2 $file3 $child > $file_" or die;                 
        }
}
while (wait() != -1) {};
#print "Done\n";
my $cat="";
foreach my $child (0..$core-1) {
	my $file_='./temp_split/'.$child.'.Result';
	$cat=$cat." ".$file_;
}
system "cat $cat > ./temp_split/Results.fasta";
system "cp $opts{n} ./temp_split/Results.names";
#running SLP modified algorithm
print "....IPED: Running modified SLP....\n";

if ($opts{g}){
	system "\.\/mothur \"\#pre\.cluster(fasta=./temp_split/Results.fasta,name=./temp_split/Results.names,diffs=$diffs,group=$group,processors=$core\)\">> ./temp_split/$logfile";
	#Getting reads without the Markers
	system "cp $opts{f} ./temp_split/Results.splitted_.fasta";
	system "cp $opts{n} ./temp_split/Results.splitted_.names";
	system "cut -f1 ./temp_split/Results.precluster.names > ./temp_split/Results.precluster.accnos";
	system "\.\/mothur \"\#split.groups(fasta=./temp_split/Results.splitted_.fasta,group=$opts{g},name=./temp_split/Results.splitted_.names)\"";
	system "cat ./temp_split/Results.splitted_.*.fasta > ./temp_split/Results.precluster_.fasta";
	system "\.\/mothur \"\#get\.seqs(fasta=./temp_split/Results.precluster_.fasta,accnos=./temp_split/Results.precluster.accnos\)\" >> ./temp_split/$logfile";
	unlink "./temp_split/Results.precluster_.fasta";
	print "....IPED: Preparing Output....\n";
	my $dir=$opts{o}.'IPED_Temp/';
	mkdir $dir;
	$dir=$opts{o}.'IPED_Temp/'.$logfile_num;
	mkdir $dir;
	system "cp ./temp_split/* $dir 2>> ./temp_split/$logfile";
	$dir=$opts{o}.'IPED_Final';
	mkdir("$dir");
	$dir=$opts{o}.'IPED_Final/'.$logfile_num;
	mkdir($dir);
	print "....IPED: Printing Output to IPED_Final & templ_split....\n";
	system "cp ./temp_split/Results.precluster.names $dir\/Results.IPED.names";
	system "cp ./temp_split/Results.precluster_.pick.fasta $dir\/Results.IPED.fasta";
}
else{
	system "\.\/mothur \"\#pre\.cluster(fasta=./temp_split/Results.fasta,name=./temp_split/Results.names,diffs=$diffs,processors=$core\)\">> ./temp_split/$logfile";
	#Getting reads without the Markers
	system "cp $opts{f} ./temp_split/Results.precluster_.fasta";
	system "cut -f1 ./temp_split/Results.precluster.names > ./temp_split/Results.precluster.accnos";
	system "\.\/mothur \"\#get\.seqs(fasta=./temp_split/Results.precluster_.fasta,accnos=./temp_split/Results.precluster.accnos\)\" >> ./temp_split/$logfile";
	unlink "./temp_split/Results.precluster_.fasta";
	print "....IPED: Preparing Output....\n";
	my $dir=$opts{o}.'IPED_Temp/';
	mkdir $dir;
	$dir=$opts{o}.'IPED_Temp/'.$logfile_num;
	mkdir $dir;
	system "cp ./temp_split/* $dir 2>> ./temp_split/$logfile";
	$dir=$opts{o}.'IPED_Final';
	mkdir("$dir");
	$dir=$opts{o}.'IPED_Final/'.$logfile_num;
	mkdir($dir);
	print "....IPED: Printing Output to IPED_Final & templ_split....\n";
	system "cp ./temp_split/Results.precluster.names $dir\/Results.IPED.names";
	system "cp ./temp_split/Results.precluster_.pick.fasta $dir\/Results.IPED.fasta";
}
sub usage{
print
"	
	||||||||||||||||||||||||||||||||||||||||||||||||
	||              Welcome To IPED		      ||
	|| A Software For Sequencing Data Denoising   ||
	||    Copyright (C) 2014  <M.Mysara et al>    ||
	||||||||||||||||||||||||||||||||||||||||||||||||

 IPED version 1, Copyright (C) 2014, M.Mysara et al
 IPED comes with ABSOLUTELY NO WARRANTY.
 This is free software, and you are welcome to redistribute it under
 certain conditions; please refer to \'COPYING\' for details.;

 The software also includes \"WEKA-3-6\" and \"mothur\" Both under GNU Copyright
 
 
Command Syntax:
./IPED.run {options}

 Use the Following Mandatory Options:
	USE THE FULL PATH FOR THE FILES: /home/user/path/file
 
Before running IPED you beed to have raw contig and raw quality file
To extract them with mothur [modified] make.contigs command use:
	_F Forward fastq
	_R Reverse fastq
	_o Output Path.

To Run IPED use the following mandatory options:
	_n Name file with the redundancy
	_f Fasta file of aligned sequences(accept only AGTC bases).
	_o Output Path.
	_c Contigs fasta file [output of make.contigs]
	_q Qual file of contigs [output of make.contigs]


Use the Following Non-Mandatory Options:\n
\#Options for IPED
 _p number of processors, defaul 1
 _g group file \(in case of having different sample-groups\)
 _d differences tolerated (Defualt: will be automatically calculated
	to be below 98% distance)
 _i log ID 'to pre-defined ID (default: random number)
 
\#Options for make.contigs
 _D Deltaq default =6 (only in case of _F,_R,_B)
 _I Insert detault = 20 (only in case of _F,_R,_B)
 
 For Queries about the installaion, kindly refer to \'README.txt\'
 For Queries about the Copy rights, kindly refer to \'COPYING.txt\'

CITING [please cite the included software (Mothur, WEKA)]:
(M.Mysara et al, 2014),(PD.Schloss, et al. 2009),(M.Hall et al, 2009).

";
}
