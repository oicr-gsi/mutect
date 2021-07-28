# mutect



## Overview

## Dependencies

* [gatk 3.6-0]()
* [vcftools vcftools 0.1.16]()


## Usage

### Cromwell
```
java -jar cromwell.jar run mutect.wdl --inputs inputs.json
```

### Inputs

#### Required workflow parameters:
Parameter|Value|Description
---|---|---
`tumorBam`|File|Tumor BAM file
`tumorBai`|File|Index of tumor BAM file
`tumorFileName`|String|Name for tumor file
`outputFileNamePrefix`|String|Output prefix for the result file
`runMutect.cosmic`|String|File for cosmic annotations
`runMutect.dbSNP`|String|File for dbSNP annotations


#### Optional workflow parameters:
Parameter|Value|Default|Description
---|---|---|---
`normalBam`|File?|None|Normal BAM file
`normalBai`|File?|None|Index of normal BAM file
`normalFileName`|String?|None|Name for normal file
`pon`|String?|None|Panel of normals VCF
`ponIdx`|String?|None|Index of panel of normals VCF
`intervalFile`|String?|None|BED file with intervals of interest
`intervalsToParallelizeBy`|String?|None|Split number of Mutect jobs by chromosomes to speed it up
`intervalPadding`|Int|10|Used when an interval file is provided (Default 10bp)


#### Optional task parameters:
Parameter|Value|Default|Description
---|---|---|---
`splitStringToArray.lineSeparator`|String|","|Used to separate each chromosome into a string, default is ',' 
`splitStringToArray.memory`|Int|1|Memory allocated for this job
`splitStringToArray.timeout`|Int|1|Hours before task timeout
`splitStringToArray.modules`|String|""|Names and versions of modules to load
`runMutect.modules`|String|"mutect/1.1.7 hg19/p13 hg19-dbsnp-leftaligned/138"|Names and versions of modules to load
`runMutect.mutectTag`|String|"mutect"|Tag to add to file names to denote it's been run through Mutect
`runMutect.refFasta`|String|"$HG19_ROOT/hg19_random.fa"|Reference fasta
`runMutect.downsamplingType`|String?|None|Optional, GATK Mutect parameter. Should be NONE for TS libraries
`runMutect.downsampleToFraction`|String?|None|Optional, fraction to downsample to
`runMutect.downsampleToCoverage`|String?|None|Optional, downsample to coverage
`runMutect.mutectExtraArgs`|String?|None|Extra arguments that can be passed to Mutect call
`runMutect.threads`|Int|4|Requested CPU threads
`runMutect.memory`|Int|32|Memory allocated for this job
`runMutect.timeout`|Int|24|Hours before task timeout
`mergeOutput.modules`|String|"vcftools/0.1.16"|Names and versions of modules to load
`mergeOutput.mutectTag`|String|"mutect_merged"|Tag to denote it's been run through mutect and merged
`mergeOutput.memory`|Int|6|Memory allocated for this job
`mergeOutput.timeout`|Int|24|Hours before task timeout
`calculateCallability.modules`|String|""|Names and versions of modules to load
`calculateCallability.memory`|Int|4|Memory allocated for this job
`calculateCallability.timeout`|Int|4|Hours before task timeout
`updateVcfHeader.modules`|String|"update-vcf-header-deps/0.0.1 tabix/1.9"|Names and versions of modules to load
`updateVcfHeader.caller`|String|"mutect"|Variant caller
`updateVcfHeader.version`|String|"1.1.7"|Version of the variant caller
`updateVcfHeader.reference`|String|"hg19"|Id of the used reference assembly
`updateVcfHeader.memory`|Int|16|Memory allocated for this job
`updateVcfHeader.timeout`|Int|24|Hours before task timeout
`updateVcfHeader.threads`|Int|4|Number of threads to use


### Outputs

Output | Type | Description
---|---|---
`finalVcf`|File|Output vcf with somatic variants
`vcfIndex`|File|Index of the output vcf
`wig`|File|Somatic variants in wiggle format
`out`|File|Out file, useful for understanding why some of the variants were not called
`callabilityMetrics`|File|Metrics from callability analysis task


## Commands
This section lists command(s) run by mutect workflow
 
* Running mutect
 
Call SNVs with muTect package from Broad Institute!
 
Format the list of intervals, change a line separator to newline
 
```
 
   echo INTERVALS_TO_PARRALELIZE_BY_STRING | tr 'LINE_SEPARATOR' '\n'
 
```
 
Running muTect:
 
```
    
     Run some bash code to prepare the command:
 
     java -Xmx[JOB_MEMORY-8]g -jar mutect.jar
     --analysis_type MuTect 
     --reference_sequence REF_FASTA
     --cosmic COSMIC
     --dbsnp DBSNP
     --input_file:tumor TUMOR_BAM
     --tumor_sample_name TUMOR_FILE_NAME
     NORMAL_COMMAND_LINE    # depends on the inputs
     INTERVALS_COMMAND_LINE # depends on the inputs 
     --out OUT_FILE
     --coverage_file COVERAGE_FILE
     --vcf VCF_FILE
 
     ... The following parameters are optional:
 
     --downsampling_type DOWNSAMPLING_TYPE
     --downsample_to_fraction DOWNSAMPLE_TO_FRACTION
     --downsample_to_coverage DOWNSAMPLE_TO_COVERAGE
     --normal_panel PANEL_OF_NORMALS
     MUTECT_EXTRA_ARGUMENTS
 
```
 
Post-processing (Concatenation of chromosome-specific results):

```
    vcf-concat VCF_FILES | vcf-sort > PREFIX.vcf
    tail -n +3 OUT_FILES >> PREFIX.out
    tail -n +1 WIG_FILES >> PREFIX.wig
 
```
 
Callability metrics:
 
```
    zcat -f INPUT_WIG | \
    awk '
    $0 == "0" || $0 == "1" {
         vals[$0]++
    }
    END {
        fail = (vals["0"] == "" ? 0 : vals["0"])
        pass = (vals["1"] == "" ? 0 : vals["1"])
        if (fail == 0 && pass == 0)
            callability = 0
        else
            callability = pass / (pass + fail)
        printf "{\n  \"pass\": %.0f,\n  \"fail\": %.0f,\n  \"callability\": %.6f\n}\n", pass, fail, callability
    }
    ' > WIG_BASENAME.callability_metrics.json
```
 
Post-processing vcf files:
 
```
    Fixing vcf header, FORMAT fields
    swapping NORMAL and TUMOR columns, if needed.

    Embedded python code, see the source of mutect.wdl
 
    ...  
    
    bgzip VCF_NAME && tabix -p vcf VCF_NAME.gz
```

## Support

For support, please file an issue on the [Github project](https://github.com/oicr-gsi) or send an email to gsi@oicr.on.ca .

_Generated with generate-markdown-readme (https://github.com/oicr-gsi/gsi-wdl-tools/)_
