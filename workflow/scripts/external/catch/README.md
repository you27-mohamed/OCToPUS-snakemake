# CATCh Installation

CATCh (ensemble chimera classifier) and its dependencies (WEKA, mothur2uparse)
are bundled with the OCToPUS distribution but cannot be redistributed separately.

## How to install

1. Download the OCToPUS distribution from:
   https://github.com/M-Mysara/OCToPUS/releases

2. Extract the archive:
   ```
   7z x OCTOPUS_SourceCode_All_Softwares.7z
   ```

3. Copy the required files into this directory:
   ```
   cp /path/to/extracted/CATCh.pl workflow/scripts/external/catch/
   cp /path/to/extracted/mothur2uparse.pl workflow/scripts/external/catch/
   cp /path/to/extracted/weka.jar workflow/scripts/external/catch/
   ```

4. Make Perl scripts executable:
   ```
   chmod +x workflow/scripts/external/catch/CATCh.pl
   chmod +x workflow/scripts/external/catch/mothur2uparse.pl
   ```

5. Remove the placeholder file:
   ```
   rm workflow/scripts/external/catch/weka.jar.placeholder
   ```

## Citation

CATCh: Mysara M, Saeys Y, Leys N, Raes J, Monsieurs P. (2015). CATCh, an
ensemble classifier for chimera detection in 16S rRNA sequencing studies.
Appl. Environ. Microbiol. 81:1573-84.

WEKA: Hall M, et al. (2009). The WEKA Data Mining Software: An Update.
SIGKDD Explorations 11:10-18.
