#!/bin/bash
function wait_till_short_squeue {
while [ $(squeue | wc -l) -ge 5000 ]; do
sleep 600
done
}

if [ "${FREQUENTIST_MODEL}" == "" ]
then
	FREQUENTIST_MODEL=1
fi

if [ "${RAW_PHENOTYPES}" == "1" ]
then
        USE_RAW_PHENOTYPES="-use_raw_phenotypes"
else
        USE_RAW_PHENOTYPES=""
fi

if [ "${CONDITION_ON}" != "" ]
then
	CONDITION_OPTION="-condition_on ${CONDITION_ON}"
else
	CONDITION_OPTION=""
fi

job_ids="afterok"
# mkdir -p logs_snptest

for FN in ${COHORTS}
do

for PHEN in ${PHENOTYPE_NAMES}
do

for ADJ in ${ADJS}
do
mkdir -p ${DATA_DIR}/${PHEN}/${ADJ}
done

EIGEN=""
EIGENS=`cat ${COVARIATE_FILE} | grep ${FN} | grep "^${PHEN}[ 	]" | cut -f 3 -d ' '`
for EIG in ${EIGENS}
do
  # pruefe ob EIG schon in ADDITIONAL_COVARIATE_NAMES, dann NICHT dazu
  if [ "${ADDITIONAL_COVARIATE_NAMES/EIG}" = "${ADDITIONAL_COVARIATE_NAMES}" ]
  then
    if [ "${EIGEN}" == "" ]
    then
      EIGEN=${EIG}
    else
      EIGEN="${EIGEN} ${EIG}"
    fi
  else
    echo "Eigen vector ${EIG} contained in additional_covariates ${ADDITIONAL_COVARIATE_NAMES}"
  fi
done

if [ "${NO_AGE_SEX_ADJUST}" == "1" ]
then
        COV="${ADDITIONAL_COVARIATE_NAMES} ${EIGEN}"
else
if [ "${NO_AGE_ADJUST}" == "1" ]
then
	COV="SEX ${ADDITIONAL_COVARIATE_NAMES} ${EIGEN}"
else
	COV="AGE SEX ${ADDITIONAL_COVARIATE_NAMES} ${EIGEN}"
fi
fi

echo "COVARIATES for ${FN} / ${PHEN}: ${COV}"

for CHR in ${CHRS}
do

echo Processing ${FN} - ${PHEN} - Chromosome ${CHR}

GENFILE=`echo ${GEN_PATH} | sed s/%CHR%/${CHR}/g | sed s/%COHORT%/${FN}/g`



for ADJ in ${ADJS}
do
    if [ ${ADJ} == "adjusted" ]
    then


wait_till_short_squeue	

echo "Analysis with Covariate Adjustment: ${COV}"
echo "Using GEN file: ${GENFILE}"
echo "Using SAMPLE file: ${DATA_DIR}/sample/${FN}.sample"
	
#-total_prob_limit 0 \


# SNPtest AUTOSOMAL ADJUSTED
job_id=$(sbatch ${EXCLUDE}--output ${DATA_DIR}/${PHEN}/adjusted/slurm-snptest-%A.txt --mail-type=FAIL --mem=8G --wrap="${SNPTEST} \
        -data ${GENFILE} ${DATA_DIR}/sample/${FN}.sample \
        -o ${DATA_DIR}/${PHEN}/adjusted/${FN}-chr${CHR}.out \
        -frequentist ${FREQUENTIST_MODEL} \
	    -method expected \
        -hwe \
        -pheno ${PHEN} \
        -lower_sample_limit 50 \
        -assume_chromosome ${CHR} \
        -cov_names ${COV} \
        -log ${DATA_DIR}/${PHEN}/adjusted/snptest-${PHEN}-adjusted-${FN}-chr${CHR}.log \
		${USE_RAW_PHENOTYPES} ${CONDITION_OPTION} >/dev/null")
job_id=$(echo $job_id | sed 's/Submitted batch job //')
job_ids="${job_ids}:${job_id}"

fi

    if [ "${ADJ}" == "unadjusted" ]
    then


if [ "${SKIP_UNADJUSTED_ANALYSIS}" != "1" ]
then
	echo "Unadjusted Analysis: ${FN} / ${PHEN}"

wait_till_short_squeue

# SNPtest AUTOSOMAL UNADJUSTED
job_id=$(sbatch ${EXCLUDE}--output ${DATA_DIR}/${PHEN}/unadjusted/slurm-snptest-%A.txt --mail-type=FAIL --mem=8G --wrap="${SNPTEST} \
        -data ${GENFILE} ${DATA_DIR}/sample/${FN}.sample \
        -o ${DATA_DIR}/${PHEN}/unadjusted/${FN}-chr${CHR}.out \
        -frequentist ${FREQUENTIST_MODEL} \
	    -method expected \
        -hwe \
        -pheno ${PHEN} \
        -lower_sample_limit 50 \
        -assume_chromosome ${CHR} \
        -log ${DATA_DIR}/${PHEN}/unadjusted/snptest-${PHEN}-unadjusted-${FN}-chr${CHR}.log \
		${USE_RAW_PHENOTYPES} >/dev/null")
job_id=$(echo $job_id | sed 's/Submitted batch job //')
job_ids="${job_ids}:${job_id}"

else
	echo "Skip unadjusted analysis"
fi

    fi
done


echo "Chromosome ${CHR} done"
done

if [ "${SKIP_CHR_X}" != "1" ]
then

# X_nonPAR adjusted
CHR=X_nonPAR
echo Processing ${FN} - ${PHEN} - Chromosome ${CHR}

GENFILE=`echo ${GEN_PATH} | sed s/%CHR%/${CHR}/g | sed s/%COHORT%/${FN}/g`

wait_till_short_squeue

echo "Analysis with Covariate Adjustment: ${COV}"
echo "Using GEN file: ${GENFILE}"
echo "Using SAMPLE file: ${DATA_DIR}/sample/${FN}.sample"

# SNPtest X chromosome ADJUSTED
job_id=$(sbatch ${EXCLUDE}--output ${DATA_DIR}/${PHEN}/adjusted/slurm-snptest-%A.txt --mail-type=FAIL --mem=8G --wrap="${SNPTEST} \
        -data ${GENFILE} ${DATA_DIR}/sample/${FN}.sample \
        -o ${DATA_DIR}/${PHEN}/adjusted/${FN}-chr${CHR}.out \
        -frequentist ${FREQUENTIST_MODEL} \
        -method newml \
        -hwe \
        -pheno ${PHEN} \
        -lower_sample_limit 50 \
        -assume_chromosome ${CHR} \
        -cov_names ${COV} \
		-sex_column SEX \
		-assume_chromosome 0X \
        -log ${DATA_DIR}/${PHEN}/adjusted/snptest-${PHEN}-adjusted-${FN}-chr${CHR}.log \
		${USE_RAW_PHENOTYPES} ${CONDITION_OPTION} >/dev/null")
job_id=$(echo $job_id | sed 's/Submitted batch job //')
job_ids="${job_ids}:${job_id}"


if [ "${SKIP_UNADJUSTED_ANALYSIS}" != "1" ]
then
	echo "Unadjusted Analysis (ChrX)"

wait_till_short_squeue

	# SNPtest X chromosome UNADJUSTED
job_id=$(sbatch ${EXCLUDE}--output ${DATA_DIR}/${PHEN}/unadjusted/slurm-snptest-%A.txt --mail-type=FAIL --mem=8G --wrap="${SNPTEST} \
        -data ${GENFILE} ${DATA_DIR}/sample/${FN}.sample \
        -o ${DATA_DIR}/${PHEN}/unadjusted/${FN}-chr${CHR}.out \
        -frequentist ${FREQUENTIST_MODEL} \
	    -method newml \
        -sex_column SEX \
        -assume_chromosome 0X \
        -hwe \
        -pheno ${PHEN} \
        -lower_sample_limit 50 \
        -log ${DATA_DIR}/${PHEN}/unadjusted/snptest-${PHEN}-unadjusted-${FN}-chr${CHR}.log \
		${USE_RAW_PHENOTYPES} >/dev/null")
job_id=$(echo $job_id | sed 's/Submitted batch job //')
job_ids="${job_ids}:${job_id}"

else
	echo "Skip unadjusted analysis (ChrX)"
fi

# end if SKIP_X
fi

echo "Phenotype ${PHENO} submitted"
done

echo "File ${FN} submitted"
done

echo "Waiting for remaining jobs. Checking one by one"
job_ids=$(sed 's/afterok\://g' <<< $job_ids)
echo $job_ids

IFS=':' read -r -a job_ids_array <<< "$job_ids"
for job_id in "${job_ids_array[@]}"
do
	srun ${EXCLUDE}--mem=1G --dependency="afterok:${job_id}" echo -n "."
# 	srun --dependency="afterok:${job_id}" echo "Job ${job_id} was ok."
done