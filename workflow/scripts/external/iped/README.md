# IPED Installation

IPED (Illumina Paired-End Denoising) is bundled with the OCToPUS distribution
but cannot be redistributed separately in this repository.

## How to install

1. Download the OCToPUS distribution from:
   https://github.com/M-Mysara/OCToPUS/releases

2. Extract the archive:
   ```
   7z x OCTOPUS_SourceCode_All_Softwares.7z
   ```

3. Copy `IPED_main.pl` into this directory:
   ```
   cp /path/to/extracted/IPED_main.pl workflow/scripts/external/iped/
   ```

4. Make it executable:
   ```
   chmod +x workflow/scripts/external/iped/IPED_main.pl
   ```

## Citation

Mysara M, Leys N, Raes J, Monsieurs P. (2016). IPED: a highly efficient
denoising tool for Illumina MiSeq Paired-end 16S rRNA gene amplicon sequencing
data. BMC Bioinformatics 17:192.
