#!/bin/bash
set -o nounset
set -o errexit
set -o pipefail

cd $1
ls | sed 's/.*\.//' | sort | uniq -c
echo "Numbers of variants:"
find . -name "*vcf.gz" -follow -type f -printf "echo -n \"%p \"; zcat %p | grep -v '^#' | wc -l;" | bash

module load jq
jq -c . *.callability_metrics.json