#!/bin/bash
# cd /dsk/ge_netssd/studies/00_GCKD/01_analyses/gwas/multi_biomarker_GWAS/common_chip/17_Metabolon_full_ratios_urine/
# set -- "04_params/pipeline-params_test_10k"
# script_dir=/data/programs/pipelines/snptest-multicohort-pipeline-slurm/pipeline.sh
# echo $1

# überprüft, ob reguläre Datei existiert
if [ ! -f "${1}" ]
then
	echo "Usage: ${0} param-file"
	exit 9
fi

# directory setzen
SCRIPT_DIR=${0%/*}
# SCRIPT_DIR=${script_dir%/*}

# read params
. ${1}


# überprüfen, ob Experiment directory existiert
if [ "${EXPERIMENT}" != "" ]
then
	if [ ! -d "${EXPERIMENT}" ]
	then
		echo "Experiment directory does not exist: ${EXPERIMENT}"
		exit
	fi
fi


if [ "${ADJS}" != "unadjusted" ] && [ "${ADJS}" != "adjusted" ] && [ "${ADJS}" != "unadjusted adjusted" ] && [ "${ADJS}" != "adjusted unadjusted" ]
then
        echo "ADJS needs to be either unadjusted, or adjusted, or both"
        exit
fi

# directory für log setzen 
LOG_DIR=${DATA_DIR}/../03_logs
mkdir -p ${DATA_DIR}
mkdir -p ${LOG_DIR}
mkdir -p ${DATA_DIR}/log

# determine chromosomes
if [ "${SKIP_CHR_X}" == "0" ]
then
	CHRS="1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 X_nonPAR"
else
	CHRS="1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22"
fi

if [ "${ONLY_CHRS}" != "" ]
then
	CHRS="${ONLY_CHRS}"
fi
export CHRS

echo "Chromosome List: ${CHRS}"


count=$(echo ${PHENOTYPE_TYPES} | wc -c)
count=$(expr $count / 2)

# if too many traits loop
# echo ${PHENOTYPE_NAMES} | wc -c
if [ "$count" -ge "1001" ]
then
echo "More than 1000 phenotypes: looping (${count} phenotypes)"

PHENOTYPE_TYPES_ALL=$PHENOTYPE_TYPES
PHENOTYPE_NAMES_ALL=$PHENOTYPE_NAMES

i=1
while [ $i -lt $count ]
do
j=$[$i+999]
# stop at j=count
if [ "$j" -gt "$count" ]
then
	j=$count
fi


echo "Processing phenotype ${i} until ${j}"
PHENOTYPE_TYPES=$(echo $PHENOTYPE_TYPES_ALL| cut -d " " -f${i}-${j})
PHENOTYPE_NAMES=$(echo $PHENOTYPE_NAMES_ALL| cut -d " " -f${i}-${j})

# prepare sample file
. ${SCRIPT_DIR}/01-prepare-sample.sh

# check return code
if [ "$RC" != 0 ]
then
	echo "Sample file formatting failed - check logs"
	exit
fi

# SNPtest
if [ "${FORMAT_ONLY_NO_SNPTEST}" != "1" ]
then
	. ${SCRIPT_DIR}/02-snptest.sh
fi

# Formatting
. ${SCRIPT_DIR}/03-formatting.sh

# gwasqc
. ${SCRIPT_DIR}/04-run-gwasqc.sh



i=$[$j+1]
done

PHENOTYPE_TYPES=$PHENOTYPE_TYPES_ALL
PHENOTYPE_NAMES=$PHENOTYPE_NAMES_ALL



else
echo "Less than 1000 phenotypes: No looping (${count} phenotypes)"

# prepare sample file
. ${SCRIPT_DIR}/01-prepare-sample.sh

# check return code
if [ "$RC" != 0 ]
then
	echo "Sample file formatting failed - check logs"
	exit
fi

#echo "Proceed?"
#read


# SNPtest
if [ "${FORMAT_ONLY_NO_SNPTEST}" != "1" ]
then
	. ${SCRIPT_DIR}/02-snptest.sh
fi

# Formatting
. ${SCRIPT_DIR}/03-formatting.sh

# gwasqc
. ${SCRIPT_DIR}/04-run-gwasqc.sh



fi




