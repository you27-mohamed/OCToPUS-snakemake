#! /usr/local/bin/perl
#.....................License.................................
#	 CATCh a Software for Rational Chimera Detection
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
use Getopt::Std;
use Cwd;
##...............Setting Path and Variables....................
getopt('cwoprumdngflhixyz',\%opts);
my @options=('c','w','o','p','r','u','m','d','n','g','f','l','h','i','x','y','z');
foreach my $value(@options){
	for(my $a=0;$a<42;$a=$a+2){
		my $temp_Value = '_'.$value;
		if($temp_Value eq $ARGV[$a]){$opts{$value}=$ARGV[$a+1];}
	}
}
my $logfile;
if (!defined($opts{i})){$logfile=int(rand(1000000000000000));}else{$logfile=$opts{i};}
my $PATH=getcwd();
my $logfile_='CATCH.'.$logfile.'logfile';
my $Classifier_Path=$PATH.'/rdp_multiclassifier_1.1/MultiClassifier.jar';
#my $Ref_DB=$PATH.'/RDP10.28_unaligned.sqlite';
my $Chimeras=$PATH.'/Decipher.name';
my $Chimeras_rev=$PATH.'/Decipher_rev.name';

if($opts{m}eq"d" && !defined($opts{n})){usage();}
elsif(defined($opts{f})||defined($opts{m})){
	#system "rm -rf Tools_Results";
	mkdir("Tools_Results");
	if(!defined($opts{h})){print "Please enter Output Full Path\n";}else{mkdir("$opts{h}/$logfile");mkdir("$opts{h}/$logfile/Tools_Results");}
	if(!defined($opts{o})) {$opts{o}="z"; }  #number of processor
	if(!defined($opts{p})) {$opts{p}=1; }  #number of processor
	#if(!defined($opts{r})) {print "Please enter ChimeraSlayer reference dataset, kindly refer to README for more information";exit;}#$opts{r}='silva.gold.align';} #chimeraslayer  reference data
	#if(!defined($opts{l})) {print "Please enter Pintail reference dataset, kindly refer to README for more information";exit;}#$opts{r}='silva.gold.align';} #chimeraslayer  reference data
	#if(!defined($opts{u})) {print "Please enter Uchime reference dataset, kindly refer to README for more information";exit;}
	#$opts{u}='gold.fa'; }#uchime reference data 	#	if(!defined($opts{m})) {$opts{m}="r";} #mode reference "r" or denovo "d"  
	if(!defined($opts{d})) {$opts{d}="f";} #direction forward "f" or reverse "r"
	if(!defined($opts{c})) {if($opts{m}eq"r"){$opts{c}=0.62;}elsif($opts{m}eq"d"){$opts{c}=0.7}}#cutoff threshold
	#if($opts{o}=~/d/ || $opts{o} eq "z"){if(!defined($opts{w})&& $opts{m}="r"){print "Please enter DECIPHER reference dataset, kindly refer to README for more information";exit;}else{$Ref_DB=$opts{w};}}
	if(!defined($opts{x})){print "Please insert UCHIME output file\n";}if(-e $opts{x}){}else{print "Unable to open UCHIME output file\n";}
	if(!defined($opts{y})){print "Please insert CSlayer output file\n";exit;}if(-e $opts{y}){}else{print "Unable to open CSlayer output file\n";exit;}
	if(!defined($opts{z})){print "Please insert Perseus output file\n";exit;}if(-e $opts{z}){}else{print "Unable to open Perseus output file\n";exit;}

	my $fasta=$opts{f};
	open FH,$fasta;
	open FH_,">seq.fasta";print FH_ "";close FH_;
	open FH_,">>seq.fasta";
	my $seq="";
	while(my $linee=<FH>){
			if($linee=~/\>/){
				#	print $seq."\n";
					if($seq){print FH_ $seq."\n".$linee;$seq="";}
					else{print FH_ $linee;}
			}
			else{
				chop($linee);$linee=~s/-//g;$linee=~s/\.//g;$linee=~s/\n\r//g;$linee=~s/\r\n//g;$linee=~s/\n//g;$linee=~s/\r//g;$seq=$seq.$linee;
			}
	}
	print FH_ $seq;
	close FH;
	close FH_;
	###### reverse phasta
	open FH, "seq.fasta";
	open FH1, ">seq_rev.fasta";print FH1 ""; close FH1;
	open FH1, ">>seq_rev.fasta";
	while(my $line_fasta=<FH>){
		chomp($line_fasta);
		if ($line_fasta=~/^\>/){print FH1 $line_fasta."\n";}
		else{
			$line_fasta=~s/a/X/ig;
			$line_fasta=~s/t/A/ig;
			$line_fasta=~s/c/Y/ig;
			$line_fasta=~s/g/C/ig;
			$line_fasta=~s/X/T/ig;
			$line_fasta=~s/Y/G/ig;
			$line_fasta=reverse($line_fasta);
			print FH1 $line_fasta."\n";
		}
	}
	close FH1;
	close FH;
	###### geting the Names
=head
	open FH, $fasta;
	my $names=$fasta.'_.names';
	$names=~s/\.fasta//i;
	$names=$PATH.'/'.$names;
	open FH, $fasta;
	open FH1,">",$names;print FH1 "";close FH1;
	open FH1,">>",$names;
	while(my $line=<FH>){
			if($line=~/^>/){
					$line=~s/\>//;
					print FH1 $line;
			}
			else{}
	}
	close FH1;
	close FH;
=cut
	my $names = 'name.list';
	system "grep \">\" $fasta | perl -pe 's/>//gi' > $names";
	######UCHIME Results
	if($opts{o}=~/u/||$opts{o}=~/z/){
	print '#########Running Uchime Program###########';print "\n";
		if($opts{m}=~/d/){
			if($opts{g}){
                #system "\.\/mothur \"\#chimera\.uchime(fasta=seq.fasta,name=$opts{n},processors=$opts{p},group=$opts{g})\">> $opts{h}/$logfile/Tools_Results/$logfile_ 2> temp";#GoldDB.fasta
			}
			else{
		#		system "\.\/mothur \"\#chimera\.uchime(fasta=seq.fasta,name=$opts{n},processors=$opts{p})\" >> $opts{h}/$logfile/Tools_Results/$logfile_ 2> temp";#GoldDB.fasta
			}
			my $uc_r="./Tools_Results/Uchime_Result";
			unlink $uc_r;
			open FH_ucr,">>$uc_r";
			open FH_uc,$opts{x};
			#open FH_uc,"seq.uchime.chimeras";
			while(my $line=<FH_uc>){
				chomp $line;
				my $uc_Result="";
				if($line=~/^Score/){}
				else{
					my @array=split('	',$line);
					my $end=scalar(@array)-1;
					$array[$end]=~s/Y/1/;
					$array[$end]=~s/N/0/;
					$array[1]=~s/\/ab=[\d]+\///gi;
					$uc_Result=$array[1].','.$array[$end].','.$array[0]."\n";
				}
				print FH_ucr $uc_Result;
			}
			close FH_uc;
			close FH_ucr;
			system "cp ./Tools_Results/Uchime_Result $opts{h}/$logfile/Tools_Results/";
			#system "cp ./seq.uchime.chimeras $opts{h}/$logfile/Tools_Results/";
		}
		else{ 
		if(-e $opts{u}){print "Using $opts{u} as Uchime reference\n";}else{print "Using default reference as Uchime reference\n";$opts{u}="./gold.fa";}
			system "\.\/mothur \"\#chimera\.uchime(fasta=seq.fasta,reference=$opts{u},processors=$opts{p})\" >> $opts{h}/$logfile/Tools_Results/$logfile_ 2> temp";#GoldDB.fasta
			my $uc_r="./Tools_Results/Uchime_Result";
			unlink $uc_r;
			open FH_ucr,">>$uc_r";
			open FH_uc,$opts{x};
			while(my $line=<FH_uc>){
				chomp $line;
				my $uc_Result="";
				if($line=~/^Score/){}
				else{
					my @array=split('	',$line);
					$array[16]=~s/Y/1/;
					$array[16]=~s/N/0/;
					$uc_Result=$array[0].','.$array[16]."\n";
				}
				print FH_ucr $uc_Result;
			}
			close FH_uc;
			close FH_ucr;
			system "cp ./Tools_Results/Uchime_Result $opts{h}/$logfile/Tools_Results/";
			system "cp ./seq.uchime.chimeras $opts{h}/$logfile/Tools_Results/";
		}
		print '#########Finished Uchime Program###########';print "\n";
	}
	#######ChimeraSlayer
	if($opts{o}=~/c/||$opts{o}=~/z/){
	print '#########Running ChimeraSlayer Program###########';print "\n";
	if(-e $opts{r}){print "Using $opts{r} as ChimerSlayer reference\n";}else{print "Using default reference as ChimeraSlayer reference\n";$opts{r}="./silva.gold.align";}
		#####Getting the Alignment
		system "cp seq.fasta seq.cs.fasta";
		#if($opts{o}=~/a/||$opts{o}=~/z/){
		#		system "\.\/mothur \"\#align\.seqs(fasta=seq.cs.fasta, reference=$opts{r}, processors=$opts{p},flip=T)\">> $opts{h}/$logfile/Tools_Results/$logfile_";#GoldDB.fasta
		#system "\.\/mothur \"\#align\.seqs(fasta=$fasta, reference=$opts{r}, processors=$opts{p})\"";
		#}
		unlink "seq.cs.fasta";
		if($opts{m}=~/d/){
			if($opts{g}){
	#			system "\.\/mothur \"\#chimera\.slayer(fasta=seq.cs.align,name=$opts{n}, processors=$opts{p},group=$opts{g})\">> $opts{h}/$logfile/Tools_Results/$logfile_";
			}
			else{
	#			system "\.\/mothur \"\#chimera\.slayer(fasta=seq.cs.align,name=$opts{n}, processors=$opts{p})\">> $opts{h}/$logfile/Tools_Results/$logfile_";
			}
			my $cs_r="./Tools_Results/ChimeraSlayer_Result";
			unlink $cs_r;
			open FH_csr,">>$cs_r";
			#my $cs=$align;
			#$cs=~s/align$//;
			#$cs=$cs.'slayer.chimeras';
			my $cs=$opts{y};
			open FH_cs, $cs;
			while(my $line=<FH_cs>){
				my $cs_result="";
				my @array=split('	',$line);
				if($line=~/	no$/){$cs_result=$array[0].',0,0'."\n";}
				elsif($line=~/	yes/){
				#	my @array=split('	',$line);
					#5 ,[8]
					my $num_1=$array[5];
					if($num_1<50){$num_1=100-$num_1;}
					my $num_2=$array[8];
					if($num_2<50){$num_2=100-$num_2;}
					my $num_3=($num_1+$num_2)/2;
					$cs_result=$array[0].',1,'.$num_3."\n";
				}
				elsif($line=~/	no/){
					my $num_1=$array[5];
                                        if($num_1<50){$num_1=100-$num_1;}
                                        my $num_2=$array[8];
                                        if($num_2<50){$num_2=100-$num_2;}
                                        my $num_3=($num_1+$num_2)/2;
                                        $cs_result=$array[0].',0,'.$num_3."\n";
				}
				else{}
				print FH_csr $cs_result;
			}
			close FH_csr;
			close FH_cs;
			system "cp ./Tools_Results/ChimeraSlayer_Result $opts{h}/$logfile/Tools_Results/";
		#	system "cp ./seq.cs.slayer.chimeras $opts{h}/$logfile/Tools_Results/";
		}
		else{
	#		system "\.\/mothur \"\#chimera\.slayer(fasta=seq.cs.align,reference=$opts{r}, processors=$opts{p})\">> $opts{h}/$logfile/Tools_Results/$logfile_";
			my $cs_r="./Tools_Results/ChimeraSlayer_Result";
			unlink $cs_r;
			open FH_csr,">>$cs_r";
			#my $cs=$align;
			#$cs=~s/align$//;
			#$cs=$cs.'slayer.chimeras';
			my $cs=$opts{y};
			open FH_cs, $cs;
			while(my $line=<FH_cs>){
				my $cs_result="";
				my @array=split('	',$line);
				if($line=~/	no$/){$cs_result='0,0'."\n";}
				elsif($line=~/	yes/){
				#	my @array=split('	',$line);
					#5 ,[8]
					my $num_1=$array[5];
					if($num_1<50){$num_1=100-$num_1;}
					my $num_2=$array[8];
					if($num_2<50){$num_2=100-$num_2;}
					my $num_3=($num_1+$num_2)/2;
					$cs_result='1,'.$num_3."\n";
				}
				elsif($line=~/	no/){
					my $num_1=$array[5];
                                        if($num_1<50){$num_1=100-$num_1;}
                                        my $num_2=$array[8];
                                        if($num_2<50){$num_2=100-$num_2;}
                                        my $num_3=($num_1+$num_2)/2;
                                        $cs_result='0,'.$num_3."\n";
					#$cs_result="0,$num_1	$array[5]	$num_2	$array[8]	$num_3\n";
				}
				else{}
				print FH_csr $cs_result;
			}
			close FH_csr;
			close FH_cs;
		system "cp ./Tools_Results/ChimeraSlayer_Result $opts{h}/$logfile/Tools_Results/";
		system "cp ./seq.cs.slayer.chimeras $opts{h}/$logfile/Tools_Results/";
		}
		print '#########Finished ChimeraSlayer Program###########';print "\n";
	}
	#####PINTAIL
	if(($opts{o}=~/p/||$opts{o}=~/z/)&&$opts{m}=~/r/){
	print '#########Running Pintail Program###########';print "\n";
	if(-e $opts{l}){print "Using $opts{l} as Pintail reference\n";}else{print "Using default reference\n";$opts{l}="./silva.gold.align";}
	#####Getting the Alignment
		system "cp seq.fasta seq.pin.fasta";
		#if($opts{o}=~/a/||$opts{o}=~/z/){
				system "\.\/mothur \"\#align\.seqs(fasta=seq.pin.fasta, reference=$opts{l}, processors=$opts{p},flip=T)\">> $opts{h}/$logfile/Tools_Results/$logfile_";#GoldDB.fasta
		#system "\.\/mothur \"\#align\.seqs(fasta=$fasta, reference=$opts{r}, processors=$opts{p})\"";
		#}
		unlink "seq.pin.fasta";
			system "\.\/mothur \"\#chimera\.pintail(fasta=seq.pin.align,reference=$opts{l}, processors=$opts{p},quantile=silva\.gold\.pintail\.quan,conservation=silva\.gold\.freq)\">> $opts{h}/$logfile/Tools_Results/$logfile_";
			my $pin_res="./Tools_Results/Pintail_Result";
			unlink $pin_res;
			open FH_pr,">>$pin_res";
			#my $pintail=$align;
			#$pintail=~s/align$//;
			#$pintail=$pintail.'pintail.chimeras';
			my $pintail='seq.pin.pintail.chimeras';#Fastaaligpintail.chimeras
			open FH_p, $pintail;
			my $tracker=0;
			while(my $line=<FH_p>){
				chomp($line);
				if($tracker==0){
					my @array_=split("	",$line);
					$array_[3]=~s/chimera flag\: //g;
					$array_[2]=~s/stDev\: //g;
					$array_[1]=~s/div\: //g;
					$array_[3]=~s/No/0/g;
					$array_[3]=~s/Yes/1/g;
					if($array_[3] eq 1){print FH_pr $array_[1].",".$array_[2].",".$array_[3]."\n";}else{print FH_pr "0,0,0\n";}
				}
				$tracker++;
				if($tracker==3){$tracker=0;}			
			}
			close FH_p;
			close FH_pr;
		system "cp ./Tools_Results/Pintail_Result $opts{h}/$logfile/Tools_Results/";
		system "cp ./seq.pin.pintail.chimeras $opts{h}/$logfile/Tools_Results/";
			print '#########Finished Pintail Program###########';print "\n";
	}
	#########PERSEUS
	#$opts{o}=~/u/||$opts{o}=~/z/
	if($opts{o}=~/p/||$opts{o}=~/z/){
		print '#########Running Perseus Program###########';print "\n";
		if($opts{m}=~/d/){
			if($opts{g}){
#			       system "\.\/mothur \"\#chimera\.perseus(fasta=seq.fasta, name=$opts{n}, processors=$opts{p},group=$opts{g})\">> $opts{h}/$logfile/Tools_Results/$logfile_";
			}
			else{
#				system "\.\/mothur \"\#chimera\.perseus(fasta=seq.fasta, name=$opts{n}, processors=$opts{p})\" >> $opts{h}/$logfile/Tools_Results/$logfile_";
			}
			my $pe_r='./Tools_Results/Perseus_Result';
			unlink $pe_r;
			open FH_per,">>$pe_r";
			open FH_pe,$opts{z};
			while(my $line=<FH_pe>){
				chomp $line;
				my $pe_Result="";
				if($line=~/^SequenceIndex/){}
				else{
					my @array=split('	',$line);
					$array[18]=~s/chimera/1/;
					$array[18]=~s/trimera/1/;
					$array[18]=~s/tetramera/1/;
					$array[18]=~s/good/0/;
					$pe_Result=$array[1].','.$array[18].','.$array[17]."\n";
				}
				print FH_per $pe_Result;
			}
			close FH_pe;
			close FH_per;
			system "cp ./Tools_Results/Perseus_Result $opts{h}/$logfile/Tools_Results/";
		#	system "cp ./seq.perseus.chimeras $opts{h}/$logfile/Tools_Results/";
		}
		print '#########Finished Perseus Program###########';print "\n";
	}
	#########Decipher
	if(($opts{o}=~/d/||$opts{o}=~/z/)&&$opts{m}=~/r/){
	print '#########Running DECIPHER Program###########';print "\n";
	if(!defined($opts{w})){print "Please enter DECIPHER reference dataset, kindly refer to README for more information";exit;}else{print "Using $opts{w} as DECIPHER reference\n";$Ref_DB=$opts{w};}
	if(-e $opts{w}){}else{print "Please use the complete Path for DECIPHER reference\n";exit;}
			my $core=$opts{p};
			if($opts{d}=~/f/){open FH,'seq.fasta';}
			elsif($opts{d}=~/r/){open FH,'seq_rev.fasta';}
			my @seq=<FH>;
			close FH;
			my $seq_len=scalar(@seq)/2;
			my $seq_frac=int($seq_len/$core);
			my $reminder=$seq_len%$core;
			system "rm -rf temp_split";
			mkdir("temp_split");
			my $i=0;
			my $file=$PATH.'/temp_split/'.$i.'.fasta';
			foreach $i(0..$core-1){
				$file=$PATH.'/temp_split/'.$i.'.fasta';
				#print $file
				open FH,">>",$file;
				for(my $j=($i*$seq_frac*2);$j<($i+1)*$seq_frac*2;$j++){
					print FH $seq[$j];
				}
				close FH;
			}
			open FH, ">>",$file;
			for(my $j=($core)*$seq_frac*2;$j<($core*$seq_frac*2)+($reminder*2);$j++){
				print FH $seq[$j];
			}
			close FH;
			foreach my $child (0..$core-1) {
				my $file_=$PATH.'/temp_split/'.$child.'.Result';
				unlink $file_;# or warn "Could not unlink $file_: $!";
				my $pid = fork();
				if ($pid == -1) {
				die;
				}
				elsif ($pid == 0) {
				exec "R --slave --args $Classifier_Path $PATH'/temp_split/'$child.fasta $Ref_DB $PATH'/temp_split/'$child.DB $PATH'/temp_split/'$child.Result< ChimeraFinder.R>> $opts{h}/$logfile/Tools_Results/$logfile_" or die;
				}
			}
			while (wait() != -1) {}
			print "Done\n";
			my $file_=$PATH.'/temp_split/Decipher.number';
			unlink $file_;# or warn "Could not unlink $file_: $!";
			open FH1, ">>$file_";
			foreach my $j(0..$core-1){
				my $file=$PATH.'/temp_split/'.$j.'.Result';
				open FH, $file;
				while(my $line=<FH>){
					chomp $line;
					$line=$line+($j*$seq_frac);
					$line=$line-1;
					print FH1 $line."\n";
				}
				close FH;
			}
			close FH1;
			my $file__='./Tools_Results/Decipher_Result';
			unlink $file__;# or warn "Could not unlink $file__: $!";
			open FH,">>$file__";
			open FH1,"$names";
			my @array=<FH1>;
			close FH1;
			for(my $i=0;$i<scalar(@array);$i++){
				my $trac="0";
				chomp $array[$i];
				open FH2,$file_;
				while(my $line=<FH2>){
					chomp $line;
					if($line == $i){$trac="1";}
					else{}
				}
				close FH2;
				print FH $trac."\n";
			}
			close FH;
			system "cp ./Tools_Results/Decipher_Result $opts{h}/$logfile/Tools_Results/";
			system "cp ./temp_split/Decipher.number $opts{h}/$logfile/Tools_Results/";
	print '#########Finished DECIPHER Program###########';print "\n";
	}
	if($opts{o}=~/r/||$opts{o}=~/z/){
	if($opts{m}=~/r/){
		print '#########Running CATCH Reference Model###########';print "\n";
		open (FH,"$opts{h}/$logfile/Tools_Results/Uchime_Result")or die "cannot open: $!";
		my @UC=<FH>;
		close FH;
		open (FH,"$opts{h}/$logfile/Tools_Results/ChimeraSlayer_Result")or die "cannot open: $!";
		my @CS=<FH>;
		close FH;
		open (FH,"$opts{h}/$logfile/Tools_Results/Pintail_Result")or die "cannot open: $!";
		my @Pin=<FH>;
		close FH;
		open (FH,"$opts{h}/$logfile/Tools_Results/Decipher_Result");#or die "cannot open: $!";
		my @DE=<FH>;
		close FH;
		my $CR="$opts{h}/$logfile/Tools_Results/CATCH_Result.arff";
		unlink $CR;
		open FH,">>$CR";
		print FH "\@relation sirnahabal\n\n\@attribute Uchime_score numeric\n\@attribute Uchime_Result numeric\n\@attribute CS_Result numeric\n\@attribute CS_Score1 numeric\n\@attribute Pintail_Score numeric\n\@attribute Pintail_sdv numeric\n\@attribute Pintail_Result numeric\n\@attribute DECIPHER_Result numeric\n\@attribute Actual_Result numeric\n\n\@data\n";
		for(my $i=0;$i<scalar(@UC);$i++){
			chomp $UC[$i];chomp $CS[$i];chomp $Pin[$i];chomp $DE[$i];
			$Pin[$i]=~s/Your template does not include sequences that provide quantile values at distance [\d]+/0/;
			$Pin[$i]=~s/nan/0/g;
			print FH $UC[$i].",".$CS[$i].",".$Pin[$i].",".$DE[$i].",0\n";
		}
		close FH;
		#print $opts{w}."\n\n";
		my $Model=$PATH.'/Reference.model';
		#chdir $opts{w};
		#print "$CR.Final\n\n";
		system"java -Xmx1000M -classpath ./weka.jar weka.classifiers.functions.SMOreg -l $Model -T $CR -p 0 > $CR.Final"; 
		open FH, "$CR.Final";
		my @array=<FH>;
		close FH;
		open FH1,$names;
		my @array_=<FH1>;
		close FH1;
		unlink "$CR.Final_Result";
		open FH2, ">>$CR.Final_Result";
		print FH2 "SeqID	YN\n";
		for(my $i=5;$i<scalar(@array);$i++){
			chomp($array[$i]);
			if($array[$i]=~/[\d]+[\s]+0[\s]+([0-9]*\.?[0-9]*)[\s]+[0-9]*\.?[0-9]*/){
			#	print "Obaa \n";
				$array[$i]=$1;
				my $result="";
				if($array[$i]>$opts{c}){$result="Chimeric";}
				else{$result="Non_Chimeric";}
				chomp($array_[$i-5]);
				print FH2 $array_[$i-5]."	".$result."\n";
			}
		}
		close FH2;
		print '#########Finished CATCH Reference Model###########';print "\n";
	}
	elsif($opts{m}=~/d/){
		print '#########Running CATCH de novo Model###########';print "\n";
		open (FH,"$opts{h}/$logfile/Tools_Results/Uchime_Result")or die "cannot open: $!";
		my @UC=<FH>;
		close FH;
		open (FH,"$opts{h}/$logfile/Tools_Results/Perseus_Result")or die "cannot open: $!";
		my @PE=<FH>;
		close FH;
		open (FH,$names)or die "cannot open: $!";
		my @Name=<FH>;
		close FH;
                open (FH,"$opts{h}/$logfile/Tools_Results/ChimeraSlayer_Result")or die "cannot open: $!";
                my @CS=<FH>;
                close FH;
		my $CA="$opts{h}/$logfile/Tools_Results/CATCH_Result.arff";
		unlink $CA;
		open FH,">>$CA";
		print FH "\@relation sirnahabal\n\n\@attribute UchDnv_Result numeric\n\@attribute UchDnv_Score numeric\n\@attribute cs_Result numeric\n\@attribute cs_Score numeric\n\@attribute Preseus_Result numeric\n\@attribute Preseus_Score numeric\n\@attribute Actual_Result numeric\n\n\@data\n";
		for(my $i=0;$i<scalar(@Name);$i++){
			chomp $Name[$i];#chomp $UC[$i];chomp $PE[$i];
			my @Names_=split("\t",$Name[$i]);
			$Names=$Names_[0];
			#print $Names."\n";
			my $track=0;
			for ($j=0;$j<scalar(@UC) && $track==0;$j++){
				if($UC[$j]=~/^$Names,([\w\W]+)$/){
					$UC[$j]=$1;
					for($k=0;$k<scalar(@CS);$k++){	
						 if($CS[$k]=~/^$Names,([\w\W]+)$/){
                                       			$CS[$k]=$1;
							for ($O=0;$O<scalar(@PE) && $track==0;$O++){
								if($PE[$O]=~/^$Names,([\w\W]+)$/){
									$PE[$O]=$1;
									chomp $CS[$k];
									chomp $UC[$j];
									chomp $PE[$O];
									print FH $UC[$j].",".$CS[$k].",".$PE[$O].",0\n";
									$track=1;
								}
							}
						}
					}
				}
			}
		}
		close FH;
		#print $opts{w}."\n\n";
		my $Model=$PATH.'/denovo.model';
		#chdir $opts{w};
		#print "$CR.Final\n\n";
		system"java -Xmx2000M -classpath ./weka_.jar weka.classifiers.functions.SMOreg -l $Model -T $CA -p 0 > $CA.Final"; 
		open FH, "$CA.Final";
		my @array=<FH>;
		close FH;
		open FH1,$names;
		my @array_=<FH1>;
		close FH1;
		unlink "$CA.Final_Result";
		open FH2, ">>$CA.Final_Result";
		print FH2 "SeqID	YN\n";
		for(my $i=5;$i<scalar(@array);$i++){
			chomp($array[$i]);
			if($array[$i]=~/[\d]+[\s]+0[\s]+([0-9]*\.?[0-9]*)[\s]+[0-9]*\.?[0-9]*/){
			#	print "Obaa \n";
				$array[$i]=$1;
				my $result="";
				#print $array[$i]."\n";
				if($array[$i]>$opts{c}){$result="Chimeric";}
				else{$result="Non_Chimeric";}
				chomp($array_[$i-5]);
				print FH2 $array_[$i-5]."	".$result."\n";
			}
		#	else{print FH2 $array_[$i-5]."Boss\n";}
		}
		close FH2;
		print '#########Finished CATCH de novo Model###########';print "\n";
	}
	}
	else{}
	#system "cp ./Tools_Results/$logfile_ $opts{h}/$logfile/Tools_Results/";
}
else{

	usage();
}
sub usage{
print
"	
	||||||||||||||||||||||||||||||||||||||||||||||||
	||		Welcome To CATCh	      ||
	|| A Software For Rational Chimera Detection  ||
	||    Copyright (C) 2014  <M.Mysara et al>    ||
	||||||||||||||||||||||||||||||||||||||||||||||||

 CATCh version 1, Copyright (C) 2014, M.Mysara et al
 CATCh comes with ABSOLUTELY NO WARRANTY.
 This is free software, and you are welcome to redistribute it under
 certain conditions; refer to COPYING for details.;
 
The software also includes \"WEKA-3-6\", \"DECIPHER\", \"RDP MultiClassifier\" and \"mothur\" All under GNU Copyright,
Refer to the Readme file for these tool citations.
 
Command Syntax:
./CATCh.run {options}

 Use the Following Mandatory Options:\n
 _f file.fasta
 _m mode whether denovo 'd' or reference 'r' 
 _n Name file with the redundancy in denovo mode
 _h output path
 _w DECIPHER dataset path

 Use the Following Non-Mandatory Options:\n
 _o  option to run the whole program \"z\" or to run specific step
	u =Uchime	c =ChimeraSlayer	p=Perseus
	p =Pintail	d =decipher	r =CATCH
 _p number of processors, defaul 1
 _r chimeraslayer reference data path, default './silva.gold.align'
 _u uchime reference data path, default 'gold.fa'
 _l pintail reference data path, default './silva.gold.align'
 _d direction whether forward 'f' (default) or reverse 'r'
 _c cutoff for CATCh (default 0.62 for reference, and 0.70 for denovo)
 _g group file (required when having mutiple samples in the same fasta)
 _i log ID 'to continue previous run'
 
	
";
}
