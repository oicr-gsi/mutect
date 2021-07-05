version 1.0

workflow mutect {
  input {
    File tumorBam
    File tumorBai
    String tumorFileName
    File? normalBam
    File? normalBai
    String? normalFileName
    String outputFileNamePrefix
    File? pon
    File? ponIdx
    File? intervalFile
    String? intervalsToParallelizeBy
    Int? intervalPadding
  }

  parameter_meta {
    tumorBam: "Tumor BAM file"
    tumorBai: "Index of tumor BAM file"
    tumorFileName: "Name for tumor file"
    normalBam: "Normal BAM file"
    normalBai: "Index of normal BAM file"
    normalFileName: "Name for normal file"
    outputFileNamePrefix: "Output prefix for the result file"
    pon: "Panel of normals VCF"
    ponIdx: "Index of panel of normals VCF"
    intervalFile: "BED file with intervals of interest"
    intervalsToParallelizeBy: "Split number of Mutect jobs by chromosomes to speed it up"
    intervalPadding: "Used when an interval file is provided (Default 10bp)"
  }

  call splitStringToArray {
    input:
      intervalsToParallelizeBy = intervalsToParallelizeBy
  }

  Boolean intervalsProvided = if (defined(intervalsToParallelizeBy)) then true else false

  scatter(subintervals in splitStringToArray.out) {
    call runMutect {
      input:
        tumorBam = tumorBam,
        tumorBai = tumorBai,
        tumorFileName = tumorFileName,
        normalBam = normalBam,
        normalBai = normalBai,
        normalFileName = normalFileName,
        outputFileNamePrefix = outputFileNamePrefix,
        pon = pon,
        ponIdx = ponIdx,
        intervalsProvided = intervalsProvided,
        intervalFile = intervalFile,
        intervals = subintervals,
        intervalPadding = intervalPadding
    }
  }

  Array[File] outs = runMutect.out
  Array[File] wigs = runMutect.wig
  Array[File] vcfs = runMutect.vcf

  call mergeOutput {
    input:
      outFiles = outs,
      wigFiles = wigs,
      vcfFiles = vcfs,
      outputBasename = outputFileNamePrefix
  }

  call calculateCallability {
    input:
      wig = mergeOutput.wig
  }

  call updateVcfHeader {
    input:
      vcf = mergeOutput.vcf
  }

  output {
    File finalVcf = updateVcfHeader.updatedVcf
    File vcfIndex = updateVcfHeader.vcfIndex
    File wig = mergeOutput.wig
    File out = mergeOutput.out
    File callabilityMetrics = calculateCallability.callabilityMetrics
  }

  meta {
    author: "Angie Mosquera"
    email: "angie.mosquera@oicr.on.ca"
    description: ""
    dependencies: [
      {
        name: "gatk/3.6-0",
        url: ""
      },
      {
        name: "vcftools/vcftools/0.1.16",
        url: ""
      }
    ]
    output_meta: {
      finalVcf: "Output vcf with somatic variants"
      vcfIndex: "Index of the output vcf"
      wig: "Somatic variants in wiggle format"
      out: "Out file, useful for understanding why some of the variants were not called"
      callabilityMetrics: "Metrics from callability analysis task"      
    }

  }
}

task splitStringToArray {
  input {
    String? intervalsToParallelizeBy
    String lineSeparator = ","
    Int memory = 1
    Int timeout = 1
    String modules = ""
  }

  parameter_meta {
    intervalsToParallelizeBy: "String of chromosomes that will be split into Array[String] for scatter"
    lineSeparator: "Used to separate each chromosome into a string, default is ',' "
    timeout: "Hours before task timeout"
    memory: "Memory allocated for this job"
    modules: "Names and versions of modules to load"
  }

  command <<<
    set -euo pipefail

    echo "~{intervalsToParallelizeBy}" | tr '~{lineSeparator}' '\n'
  >>>

  runtime {
    memory:  "~{memory} GB"
    modules: "~{modules}"
    timeout: "~{timeout}"
  }

  output {
    Array[Array[String]] out = read_tsv(stdout())
  }

  meta {
    output_meta: {
      out: "Chromosomes to split Mutect jobs by, in Array[File] format."
    }
  }
}

task runMutect {
  input {
    String modules = "mutect/1.1.7 hg19/p13 hg19-dbsnp-leftaligned/138"
    String mutectTag = "mutect"
    File tumorBam
    File tumorBai
    String tumorFileName
    File? normalBam
    File? normalBai
    String? normalFileName
    String outputFileNamePrefix
    String refFasta = "$HG19_ROOT/hg19_random.fa"
    File cosmic
    File dbSNP
    File dbSNPidx
    File? pon
    File? ponIdx
    File? intervalFile
    Boolean intervalsProvided
    Int? intervalPadding = 10
    Array[String]? intervals
    String? downsamplingType
    String? downsampleToFraction
    String? downsampleToCoverage
    String? mutectExtraArgs
    Int threads = 4
    Int memory = 32
    Int timeout = 24
  }

  parameter_meta {
    modules: "Names and versions of modules to load"
    mutectTag: "Tag to add to file names to denote it's been run through Mutect"
    tumorBam: "Tumor BAM file"
    tumorBai: "Index of tumor BAM file"
    normalBam: "Normal BAM file"
    normalBai: "Index of normal BAM file"
    refFasta: "Reference fasta"
    cosmic: "File for cosmic annotations"
    dbSNP: "File for dbSNP annotations"
    dbSNPidx: "File for index of dbSNP annotations"
    pon: "Panel of normals VCF"
    ponIdx: "Index of panel of normals VCF"
    intervalFile: "BED file with intervals of interest"
    intervalsProvided: "If a string of chromosomes is provided, use it as an interval in Mutect call"
    intervals: "Split number of Mutect jobs by chromosomes to speed it up"
    intervalPadding: "Used when an interval file is provided (Default 10bp)"
    downsamplingType: "Optional, GATK Mutect parameter. Should be NONE for TS libraries"
    downsampleToFraction: "Optional, fraction to downsample to"
    downsampleToCoverage: "Optional, downsample to coverage"
    mutectExtraArgs: "Extra arguments that can be passed to Mutect call"
    threads: "Requested CPU threads"
    memory: "Memory allocated for this job"
    timeout: "Hours before task timeout"
  }

  String outFile = outputFileNamePrefix + "." + mutectTag + ".out"
  String covFile = outputFileNamePrefix + "." + mutectTag + ".wig"
  String vcfFile = outputFileNamePrefix + "." + mutectTag + ".vcf"

  command <<<
    set -euo pipefail
    
    if [ -f "~{normalBam}" ]; then
      normal_command_line="--input_file:normal ~{normalBam} --normal_sample_name ~{normalFileName}"
    else
      normal_command_line=""
    fi

    if [ -f "~{intervalFile}" ]; then
      if ~{intervalsProvided} ; then
        interval_command_line="--intervals ~{intervalFile} --intervals ~{sep=" --intervals " intervals} --interval_set_rule INTERSECTION --interval_padding ~{intervalPadding}"
      else
        interval_command_line="--intervals ~{intervalFile} --interval_set_rule INTERSECTION --interval_padding ~{intervalPadding}"
      fi
    else
      if ~{intervalsProvided} ; then
        interval_command_line="--intervals ~{sep=" --intervals " intervals}"
      fi
    fi

    java -Xmx~{memory-8}g -jar $MUTECT_ROOT/share/mutect.jar \
    --analysis_type MuTect \
    --reference_sequence ~{refFasta} \
    --cosmic ~{cosmic} \
    --dbsnp ~{dbSNP} \
    --input_file:tumor ~{tumorBam} \
    --tumor_sample_name ~{tumorFileName} \
    $normal_command_line \
    $interval_command_line \
    --out ~{outFile} \
    --coverage_file ~{covFile} \
    --vcf ~{vcfFile}  ~{"--downsampling_type " + downsamplingType} ~{"--downsample_to_fraction " + downsampleToFraction}  ~{"--downsample_to_coverage " + downsampleToCoverage} ~{"--normal_panel " + pon} \
    ~{mutectExtraArgs}
  >>>

  runtime {
    cpu: "~{threads}"
    memory:  "~{memory} GB"
    modules: "~{modules}"
    timeout: "~{timeout}"
  }

  output {
    File out = "~{outFile}"
    File wig = "~{covFile}"
    File vcf = "~{vcfFile}"
  }

  meta {
    output_meta: {
      out: "Call stats in .out format",
      wig: "wig coverage",
      vcf: "Variant call file"
    }
  }
}

task mergeOutput {
  input {
    String modules = "vcftools/0.1.16"
    Array[File] outFiles
    Array[File] wigFiles
    Array[File] vcfFiles
    String mutectTag = "mutect_merged"
    String outputBasename
    Int memory = 6
    Int timeout = 24
  }

  parameter_meta {
    modules: "Names and versions of modules to load"
    outFiles: ".out files to merge together from scatter"
    wigFiles: ".wig coverage files to merge together from scatter"
    vcfFiles: ".vcf to merge together from scatter"
    outputBasename: "Basename from tumor BAM to generate output prefix"
    mutectTag: "Tag to denote it's been run through mutect and merged"
    memory: "Memory allocated for this job"
    timeout: "Hours before task timeout"
  }

  String outputPrefix = outputBasename + "." + mutectTag

  command <<<
    set -euo pipefail
    
    vcf-concat ~{sep=" " vcfFiles} | vcf-sort > "~{outputPrefix}.vcf"

    tail -n +3 ~{sep=" " outFiles} >> "~{outputPrefix}.out"

    tail -n +1 ~{sep=" " wigFiles} >> "~{outputPrefix}.wig"
  >>>

  runtime {
    memory:  "~{memory} GB"
    modules: "~{modules}"
    timeout: "~{timeout}"
  }

  output {
    File vcf = "~{outputPrefix}.vcf"
    File wig = "~{outputPrefix}.wig"
    File out = "~{outputPrefix}.out"
  }

  meta {
    output_meta: {
      vcf: "Merged vcf",
      wig: "Merged coverage wig",
      out: "Merged call stats"
    }
  }
}

task calculateCallability {
  input {
    String modules = ""
    File wig
    Int memory = 4
    Int timeout = 4
  }

  parameter_meta {
    modules: "Names and versions of modules to load"
    wig: ".wig coverage files to generate callability metrics for"
    memory: "Memory allocated for this job"
    timeout: "Hours before task timeout"
  }

  String wigBasename = basename(wig, '.wig')

  command <<<
    zcat -f ~{wig} | \
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
    ' > ~{wigBasename}.callability_metrics.json
  >>>
  runtime {
      memory:  "~{memory} GB"
      modules: "~{modules}"
      timeout: "~{timeout}"
    }

  output {
    File callabilityMetrics = "~{wigBasename}.callability_metrics.json"
  }

  meta {
    output_meta: {
      callabilityMetrics: "Callability metrics from .wig"
    }
  }
}

task updateVcfHeader {
  input {
    String modules = "update-vcf-header-deps/0.0.1 tabix/1.9"
    File vcf
    String caller = "mutect"
    String version = "1.1.7"
    String reference = "hg19"
    Int memory = 16
    Int timeout = 24
    Int threads = 4
  }

  parameter_meta {
    modules: "Names and versions of modules to load"
    vcf: "Input .vcf to update"
    caller: "Variant caller"
    version: "Version of the variant caller"
    reference: "Id of the used reference assembly"
    memory: "Memory allocated for this job"
    timeout: "Hours before task timeout"
    threads: "Number of threads to use"
  }

  String vcf_name = basename(vcf)

  command <<<
    set -euo pipefail
    
    python3<<CODE
    import vcf
    import re

    def modify_header_and_records(reader):
      header_lines = ["##fileformat=" + reader.metadata['fileformat'] + "\n", "##source=~{caller}\n",
                      "##source_version=~{version}\n", "##reference=" + reader.metadata['reference'] + "\n"]
      for c in reader.contigs:
        if re.search('_', reader.contigs[c].id):
          continue
        header_lines.append("##contig=<ID=" + reader.contigs[c].id + ",length=" + str(reader.contigs[c].length) +
                            ",assembly=~{reference}>\n")

      for i in reader.infos:
        num = reader.infos[i].num
        if reader.infos[i].num is None:
          num = '.'
        header_lines.append("##INFO=<ID=" + reader.infos[i].id +
                            ",Number=" + str(num) + ",Type=" + reader.infos[i].type +
                            ",Description=\"" + reader.infos[i].desc + "\">\n")

      for f in reader.formats:
        num = reader.formats[f].num if reader.formats[f].num is not None else '.'
        header_lines.append("##FORMAT=<ID=" + reader.formats[f].id +
                            ",Number=" + str(num) + ",Type=" + reader.formats[f].type +
                            ",Description=\"" + reader.formats[f].desc + "\">\n")

      for f in reader.filters:
        header_lines.append("##FILTER=<ID=" + reader.filters[f].id +
                            ",Description=\"" + reader.filters[f].desc + "\">\n")

      input_hash = {}
      swapped = False
      if 'inputs' in reader.metadata.keys():
        header_lines.append("##inputs=" + " ".join(reader.metadata['inputs']) + "\n")
        for s in reader.metadata['inputs'][0].split(" "):
          input = s.split(":")
          input_hash.update({input[1]: input[0]})
        sample_list = list(input_hash.values())
        if sample_list[0] != 'NORMAL':
          swapped = True

      if 'SAMPLE' in reader.metadata.keys():
        for s in reader.metadata['SAMPLE']:
          header_lines.append("##SAMPLE=<ID=" + s['ID'] + ",SampleName=" + s['SampleName'] +
                              ",File=" + s['File'] + ">\n")

      if len(reader.samples) == 2 and reader.samples[0] != 'NORMAL' and len(input_hash) == 0:
        swapped = True

      header_fields = ['CHROM', 'POS', 'ID', 'REF', 'ALT', 'QUAL', 'FILTER', 'INFO', 'FORMAT']

      if reader.samples[0] not in ['NORMAL', 'TUMOR'] and len(input_hash) == 2:
        header_fields.extend(input_hash.values() if not swapped else ['NORMAL', 'TUMOR'])
      else:
        header_fields.extend(reader.samples if not swapped else reversed(reader.samples))
      header_lines.append("#" + "\t".join(header_fields) + "\n")

      record_lines = []
      for record in reader:
        if re.search('_', record.CHROM):
          continue

        record_data = [record.CHROM, str(record.POS), '.' if record.ID is None else record.ID, record.REF,
                       ",".join(map(str, '.' if record.ALT[0] is None else record.ALT)),
                       '.' if record.QUAL is None else record.QUAL,
                       "PASS" if len(record.FILTER) == 0 else ";".join(record.FILTER)]
        info_data = []
        for field in record.INFO:
          if isinstance(record.INFO[field], list):
            info_data.append("=".join([field, ",".join(map(str, record.INFO[field]))]))
          else:
            info_data.append("=".join([field, "." if record.INFO[field] is None else str(record.INFO[field])]))
        info_string = ";".join(info_data) if len(info_data) > 0 else "."
        record_data.append(info_string)

        format_data = []
        for field in record.FORMAT.split(":"):
          format_data.append(field)
        record_data.append(":".join(format_data))

        sample_data = []
        for sample in record.samples:
          for field in record.FORMAT.split(":"):
            if isinstance(sample[field], list):
              format_data.append(",".join(map(str, sample[field])))
            else:
              format_data.append("." if sample[field] is None else str(sample[field]))
          sample_data.append(":".join(format_data))
        if swapped:
          sample_data.reverse()
        for s in sample_data:
          record_data.append(s)
        record_lines.append("\t".join(record_data) + "\n")
      return header_lines, record_lines

    vcf_reader = vcf.Reader(filename="~{vcf}", compressed=False)
    modifiedVcf = modify_header_and_records(vcf_reader)

    with open("~{vcf_name}", mode='w+') as out:
      out.writelines(modifiedVcf[0])
      out.writelines(modifiedVcf[1])
    out.close()
    CODE

    bgzip ~{vcf_name} && tabix -p vcf ~{vcf_name}.gz
  >>>

  runtime {
    modules: "~{modules}"
    memory: "~{memory} GB"
    timeout: "~{timeout}"
    cpu: "~{threads}"
  }

  output {
    File updatedVcf = "~{vcf_name}.gz"
    File vcfIndex = "~{vcf_name}.gz.tbi"
  }
}

