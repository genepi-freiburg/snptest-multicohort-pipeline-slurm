#!/bin/bash
function wait_till_short_squeue {
while [ $(squeue | wc -l) -ge 5000 ]; do
sleep 600
done
}

mkdir -p ${DATA_DIR}/../logs_formatting
FORMATTING_LOG="${DATA_DIR}/../logs_formatting/formatting.log"
rm -f ${FORMATTING_LOG}
touch ${FORMATTING_LOG}

job_ids="afterok"

for PHEN in ${PHENOTYPE_NAMES}
do
for FN in ${COHORTS}
do
for ADJ in ${ADJS}
do
for CHR in ${CHRS}
do
	echo Format ${FN} ${CHR} ${ADJ} ${PHEN}
	OUTFILE="${DATA_DIR}/${PHEN}/${ADJ}/${FN}-chr${CHR}.gwas"
	if [ -f ${OUTFILE} ]
	then
		echo "File exists: ${OUTFILE} - skip" | tee -a ${FORMATTING_LOG}
	else
		wait_till_short_squeue
		job_id=$(sbatch ${EXCLUDE}--output ${DATA_DIR}/../logs_formatting/slurm-formatting-%A.txt --mail-type=FAIL --wrap="${SCRIPT_DIR}/formatting.pl \
			-i ${DATA_DIR}/${PHEN}/${ADJ}/${FN}-chr${CHR}.out \
			-c ${CHR} \
			-o ${OUTFILE}")
		job_id=$(echo $job_id | sed 's/Submitted batch job //')
		job_ids="${job_ids}:${job_id}"
	fi
done
done
done
done

echo "Waiting for remaining jobs"
# srun --dependency=${job_ids} echo "Done"
job_ids=$(sed 's/afterok\://g' <<< $job_ids)
echo $job_ids
IFS=':' read -r -a job_ids_array <<< "$job_ids" 
for job_id in "${job_ids_array[@]}"
do
	srun ${EXCLUDE}--dependency="afterok:${job_id}" echo -n "."
# 	srun --dependency="afterok:${job_id}" echo "Job ${job_id} was ok."
done


echo "Merge files" >>${FORMATTING_LOG}
job_ids_all="afterok"

for PHEN in ${PHENOTYPE_NAMES}
do
for FN in ${COHORTS}
do
for ADJ in ${ADJS}
do

	echo "Combine ${FN} ${ADJ} ${PHEN}" | tee -a ${FORMATTING_LOG}

	FIRST_FILE=`ls ${DATA_DIR}/${PHEN}/${ADJ}/${FN}-chr*.gwas | head -n 1`
	echo "First file (for header) is: $FIRST_FILE"
	head -n 1 ${FIRST_FILE} >${DATA_DIR}/${PHEN}/${ADJ}/${FN}.gwas
	job_ids="afterok:121653"
	for CHR in ${CHRS}
	do
		wait_till_short_squeue
		job_id=$(sbatch --dependency=${job_ids} ${EXCLUDE}--output ${DATA_DIR}/../logs_formatting/slurm-formatting-%A.txt --mail-type=FAIL --wrap="sed -e '1d' ${DATA_DIR}/${PHEN}/${ADJ}/${FN}-chr${CHR}.gwas \
			>>${DATA_DIR}/${PHEN}/${ADJ}/${FN}.gwas")
		job_id=$(echo $job_id | sed 's/Submitted batch job //')
		job_ids="${job_ids}:${job_id}"
		job_ids_all="${job_ids_all}:${job_id}"
	done
	sbatch --output ${DATA_DIR}/../logs_formatting/slurm-delete-interim-%A.txt --dependency=${job_ids} --wrap="rm ${DATA_DIR}/${PHEN}/${ADJ}/${FN}-chr*.gwas"
#	ls GCKD_COMMON_CLEAN-chr*.gwas
#	ls GCKD_COMMON_CLEAN-chr*.out
	sbatch --output ${DATA_DIR}/../logs_formatting/slurm-delete-interim-%A.txt --dependency=${job_ids} --wrap="rm ${DATA_DIR}/${PHEN}/${ADJ}/${FN}-chr*.out"
done
done
done

echo "Waiting for remaining jobs"
# srun --dependency=${job_ids_all} echo "Done"
job_ids_all=$(sed 's/afterok\://g' <<< $job_ids_all)
echo $job_ids_all
# srun --dependency=${job_ids} echo "Done"
IFS=':' read -r -a job_ids_array <<< "$job_ids_all"
for job_id in "${job_ids_array[@]}"
do
	srun ${EXCLUDE}--dependency="afterok:${job_id}" echo -n "."
# 	srun --dependency="afterok:${job_id}" echo "Job ${job_id} was ok."
done



if [ "${SNP_TRANSLATION_TABLE}" != "" ]
then

echo "Add RSID alias column, translate using ${SNP_TRANSLATION_TABLE}" >>${FORMATTING_LOG}
echo "Add RSID alias column, translate using ${SNP_TRANSLATION_TABLE}"



job_ids="afterok"

for PHEN in ${PHENOTYPE_NAMES}
do
for FN in ${COHORTS}
do
for ADJ in ${ADJS}
do

wait_till_short_squeue

GWAS_FN="${DATA_DIR}/${PHEN}/${ADJ}/${FN}.gwas"
echo "Working with: ${GWAS_FN}"

mv "${GWAS_FN}" "${GWAS_FN}.orig"	
job_id=$(sbatch ${EXCLUDE}--output ${DATA_DIR}/../logs_formatting/slurm-formatting-%A.txt --mail-type=FAIL --wrap="/data/programs/scripts/utils/update-gwas-by-map.pl \
	-g '${GWAS_FN}.orig' \
	-m '${SNP_TRANSLATION_TABLE}' \
	-o '${GWAS_FN}' \
	-s ")
job_id=$(echo $job_id | sed 's/Submitted batch job //')
job_ids="${job_ids}:${job_id}"
done
done
done

echo "Waiting for remaining jobs"
job_ids=$(sed 's/afterok\://g' <<< $job_ids)
echo $job_ids
# srun --dependency=${job_ids} echo "Done"
IFS=':' read -r -a job_ids_array <<< "$job_ids"
for job_id in "${job_ids_array[@]}"
do
	srun ${EXCLUDE}--dependency="afterok:${job_id}" echo -n "."
# 	srun --dependency="afterok:${job_id}" echo "Job ${job_id} was ok."
done


else

echo "No RSID translation" >>${FORMATTING_LOG}
echo "No RSID translation"

fi

if [ "${INFO_TRANSLATION_TABLE}" != "" ]
then

echo "Replace SNPtest info with Rsq for imputation quality, using ${INFO_TRANSLATION_TABLE}" >>${FORMATTING_LOG}
echo "Replace SNPtest info with Rsq for imputation quality, using ${INFO_TRANSLATION_TABLE}"

job_ids="afterok"
for PHEN in ${PHENOTYPE_NAMES}
do
for FN in ${COHORTS}
do
for ADJ in ${ADJS}
do

wait_till_short_squeue

GWAS_FN="${DATA_DIR}/${PHEN}/${ADJ}/${FN}.gwas"
echo "Working with: ${GWAS_FN}"

mv "${GWAS_FN}" "${GWAS_FN}.orig1"
job_id=$(sbatch ${EXCLUDE}--output ${DATA_DIR}/../logs_formatting/slurm-formatting-%A.txt --mail-type=FAIL --wrap="${SCRIPT_DIR}/update-gwas-by-Rsq.pl \
        -g '${GWAS_FN}.orig1' \
        -m '${INFO_TRANSLATION_TABLE}' \
        -o '${GWAS_FN}'")
job_id=$(echo $job_id | sed 's/Submitted batch job //')
job_ids="${job_ids}:${job_id}"

sbatch --output ${DATA_DIR}/../logs_formatting/slurm-delete-interim-%A.txt --dependency=afterok:${job_id} --wrap="rm ${GWAS_FN}.orig1"
#rm ${GWAS_FN}.orig1
done
done
done

echo "Waiting for remaining jobs"
job_ids=$(sed 's/afterok\://g' <<< $job_ids)
echo $job_ids
# srun --dependency=${job_ids} echo "Done"
IFS=':' read -r -a job_ids_array <<< "$job_ids"
for job_id in "${job_ids_array[@]}"
do
	srun ${EXCLUDE}--dependency="afterok:${job_id}" echo -n "."
# 	srun --dependency="afterok:${job_id}" echo "Job ${job_id} was ok."
done

else

echo "No Rsq replacement" >>${FORMATTING_LOG}
echo "No Rsq replacement"

fi


echo "Done" | tee -a ${FORMATTING_LOG}
