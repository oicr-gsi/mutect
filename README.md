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
`runMutect.cosmic`|File|File for cosmic annotations
`runMutect.dbSNP`|File|File for dbSNP annotations
`runMutect.dbSNPidx`|File|File for index of dbSNP annotations


#### Optional workflow parameters:
Parameter|Value|Default|Description
---|---|---|---
`normalBam`|File?|None|Normal BAM file
`normalBai`|File?|None|Index of normal BAM file
`normalFileName`|String?|None|Name for normal file
`pon`|File?|None|Panel of normals VCF
`ponIdx`|File?|None|Index of panel of normals VCF
`intervalFile`|File?|None|BED file with intervals of interest
`intervalsToParallelizeBy`|String?|None|Split number of Mutect jobs by chromosomes to speed it up
`intervalPadding`|Int?|None|Used when an interval file is provided (Default 10bp)


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


## Support

For support, please file an issue on the [Github project](https://github.com/oicr-gsi) or send an email to gsi@oicr.on.ca .

_Generated with generate-markdown-readme (https://github.com/oicr-gsi/gsi-wdl-tools/)_
