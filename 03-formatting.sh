#!/bin/bash
function wait_till_short_squeue {
while [ $(squeue | wc -l) -ge 5000 ]; do
sleep 600
done
}

# mkdir -p ${DATA_DIR}/../logs_formatting
FORMATTING_LOG="${LOG_DIR}/formatting.log"
rm -f ${FORMATTING_LOG}
touch ${FORMATTING_LOG}
init_wait_id=$(sbatch --output ${LOG_DIR}/slurm-initializing-wait-%A.txt --mem=1G --wrap="sleep 0")
init_wait_id=$(echo $init_wait_id | sed 's/Submitted batch job //')
init_wait_id="afterok:${init_wait_id}"


job_ids=$init_wait_id

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
		job_id=$(sbatch ${EXCLUDE}--output ${DATA_DIR}/${PHEN}/${ADJ}/slurm-formatting-chr${CHR}-%A.txt --mail-type=FAIL --mem=8G -c 2 --wrap="${SCRIPT_DIR}/formatting.pl \
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
IFS=':' read -r -a job_ids_array <<< "$job_ids"
len=${#job_ids_array[@]}
for(( ii=0; ii<$len; ii=ii+1000 ))
do
tempID=$init_wait_id
for((jj=ii;jj<$len&jj<ii+1000;jj++))
do
tempID="${tempID}:${job_ids_array[$jj]}"
done
echo $tempID
srun ${EXCLUDE}--mem=1G --dependency=${tempID} echo "Done"
done

echo "Merge files" >>${FORMATTING_LOG}
job_ids_all=$init_wait_id

for PHEN in ${PHENOTYPE_NAMES}
do
for FN in ${COHORTS}
do
for ADJ in ${ADJS}
do

echo "Combine ${FN} ${ADJ} ${PHEN}" | tee -a ${FORMATTING_LOG}
GWAS_FN="${DATA_DIR}/${PHEN}/${ADJ}/${FN}.gwas.comb"


FIRST_FILE=`ls ${DATA_DIR}/${PHEN}/${ADJ}/${FN}-chr*.gwas | head -n 1`
echo "First file (for header) is: $FIRST_FILE"
head -n 1 ${FIRST_FILE} > ${GWAS_FN}
chmod g-s "${GWAS_FN}"

job_ids=$init_wait_id
for CHR in ${CHRS}
do
wait_till_short_squeue
job_id=$(sbatch --dependency=${job_ids} ${EXCLUDE}--output ${DATA_DIR}/${PHEN}/${ADJ}/slurm-formatting-combine-%A.txt --mail-type=FAIL --mem=8G -c 2 --wrap="sed -e '1d' ${DATA_DIR}/${PHEN}/${ADJ}/${FN}-chr${CHR}.gwas >> ${GWAS_FN}")
job_id=$(echo $job_id | sed 's/Submitted batch job //')
job_ids="${job_ids}:${job_id}"
job_ids_all="${job_ids_all}:${job_id}"
done
done
done
done

echo "Waiting for remaining jobs"
waitID=$init_wait_id
# srun --dependency=${job_ids_all} echo "Done"
job_ids_all=$(sed 's/afterok\://g' <<< $job_ids_all)
IFS=':' read -r -a job_ids_array <<< "$job_ids_all"
len=${#job_ids_array[@]}
for(( ii=0; ii<$len; ii=ii+1000 ))
do
tempID=$init_wait_id
for((jj=ii;jj<$len&jj<ii+1000;jj++))
do
tempID="${tempID}:${job_ids_array[$jj]}"
done
echo $tempID
job_id=$(sbatch ${EXCLUDE}--mem=1G --output ${LOG_DIR}/slurm-formatting-wait-%A.txt --dependency=${tempID} --wrap="sleep 0")
job_id=$(echo $job_id | sed 's/Submitted batch job //')
waitID="${waitID}:${job_id}"
done
echo $waitID
srun --dependency=${waitID} echo "Roadblock done"

# for PHEN in ${PHENOTYPE_NAMES}
# do
# for FN in ${COHORTS}
# do
# for ADJ in ${ADJS}
# do
# job_id_2=$(sbatch --output ${DATA_DIR}/${PHEN}/${ADJ}/slurm-delete-interim-gwas-%A.txt --mem=1G --wrap="rm ${DATA_DIR}/${PHEN}/${ADJ}/${FN}-chr*.gwas")
# job_id_3=$(sbatch --output ${DATA_DIR}/${PHEN}/${ADJ}/slurm-delete-interim-out-%A.txt --mem=1G --wrap="rm ${DATA_DIR}/${PHEN}/${ADJ}/${FN}-chr*.out")
# sleep 0
# done
# done
# done



if [ "${SNP_TRANSLATION_TABLE}" != "" ]
then

echo "Add RSID alias column, translate using ${SNP_TRANSLATION_TABLE}" >>${FORMATTING_LOG}
echo "Add RSID alias column, translate using ${SNP_TRANSLATION_TABLE}"

job_ids=$init_wait_id

for PHEN in ${PHENOTYPE_NAMES}
do
for FN in ${COHORTS}
do
for ADJ in ${ADJS}
do

wait_till_short_squeue

# GWAS_FN="${DATA_DIR}/${PHEN}/${ADJ}/${FN}.gwas"
GWAS_FN="${DATA_DIR}/${PHEN}/${ADJ}/${FN}.gwas.comb"
echo "Working with: ${GWAS_FN}"

# chmod g-s "${GWAS_FN}.orig"
job_id=$(sbatch ${EXCLUDE}--output ${DATA_DIR}/${PHEN}/${ADJ}/slurm-formatting-update-map-%A.txt --mail-type=FAIL --mem=8G -c 2 --wrap="/data/programs/scripts/utils/update-gwas-by-map.pl \
	-g '${GWAS_FN}' \
	-m '${SNP_TRANSLATION_TABLE}' \
	-o '${GWAS_FN}.trans' \
	-s ")
job_id=$(echo $job_id | sed 's/Submitted batch job //')
job_ids="${job_ids}:${job_id}"
done
done
done

echo "Waiting for remaining jobs"
waitID=$init_wait_id
# srun --dependency=${job_ids} echo "Done"
job_ids=$(sed 's/afterok\://g' <<< $job_ids)
IFS=':' read -r -a job_ids_array <<< "$job_ids"
len=${#job_ids_array[@]}
for(( ii=0; ii<$len; ii=ii+1000 ))
do
tempID=$init_wait_id
for((jj=ii;jj<$len&jj<ii+1000;jj++))
do
tempID="${tempID}:${job_ids_array[$jj]}"
done
echo $tempID
job_id=$(sbatch ${EXCLUDE}--mem=1G --output ${LOG_DIR}/slurm-formatting-wait-%A.txt --dependency=${tempID} --wrap="sleep 0")
job_id=$(echo $job_id | sed 's/Submitted batch job //')
waitID="${waitID}:${job_id}"
done
echo $waitID
srun --dependency=${waitID} echo "Roadblock done"

else

echo "No RSID translation" >>${FORMATTING_LOG}
echo "No RSID translation"

for PHEN in ${PHENOTYPE_NAMES}
do
for FN in ${COHORTS}
do
for ADJ in ${ADJS}
do
GWAS_FN="${DATA_DIR}/${PHEN}/${ADJ}/${FN}.gwas.comb"
mv "${GWAS_FN}" "${GWAS_FN}.trans"
done
done
done
echo "Move done (.trans)"


fi

if [ "${INFO_TRANSLATION_TABLE}" != "" ]
then

echo "Replace SNPtest info with Rsq for imputation quality, using ${INFO_TRANSLATION_TABLE}" >>${FORMATTING_LOG}
echo "Replace SNPtest info with Rsq for imputation quality, using ${INFO_TRANSLATION_TABLE}"

job_ids=$init_wait_id

# for PHEN in ${PHENOTYPE_NAMES}
# do
# for FN in ${COHORTS}
# do
# for ADJ in ${ADJS}
# do
# GWAS_FN="${DATA_DIR}/${PHEN}/${ADJ}/${FN}.gwas"
# mv "${GWAS_FN}" "${GWAS_FN}.orig1"
# done
# done
# done
# echo "Move done (.orig1)"

for PHEN in ${PHENOTYPE_NAMES}
do
for FN in ${COHORTS}
do
for ADJ in ${ADJS}
do

wait_till_short_squeue

GWAS_FN="${DATA_DIR}/${PHEN}/${ADJ}/${FN}.gwas.comb.trans"
echo "Working with: ${GWAS_FN}"

# chmod g-s "${GWAS_FN}.orig1"
job_id=$(sbatch ${EXCLUDE}--output ${DATA_DIR}/${PHEN}/${ADJ}/slurm-formatting-update-Rsq-%A.txt --mail-type=FAIL --mem=8G -c 2 --wrap="${SCRIPT_DIR}/update-gwas-by-Rsq.pl \
        -g '${GWAS_FN}' \
        -m '${INFO_TRANSLATION_TABLE}' \
        -o '${GWAS_FN}.imp'")
job_id=$(echo $job_id | sed 's/Submitted batch job //')
job_ids="${job_ids}:${job_id}"

#job_id_2=$(sbatch --output ${DATA_DIR}/${PHEN}/${ADJ}/slurm-delete-interim-orig1-%A.txt --dependency=afterok:${job_id} --mem=1G --wrap="rm ${GWAS_FN}.orig1")
#job_id_3=$(sbatch --output ${DATA_DIR}/${PHEN}/${ADJ}/slurm-delete-interim-orig-%A.txt --dependency=afterok:${job_id} --mem=1G --wrap="rm ${GWAS_FN}.orig")
job_id_2=$(sbatch --output ${DATA_DIR}/${PHEN}/${ADJ}/slurm-delete-interim-gwas-%A.txt --mem=1G --wrap="rm ${DATA_DIR}/${PHEN}/${ADJ}/${FN}-chr*.gwas")
job_id_3=$(sbatch --output ${DATA_DIR}/${PHEN}/${ADJ}/slurm-delete-interim-out-%A.txt --mem=1G --wrap="rm ${DATA_DIR}/${PHEN}/${ADJ}/${FN}-chr*.out")
job_id_4=$(sbatch --output ${DATA_DIR}/${PHEN}/${ADJ}/slurm-delete-interim-comb-%A.txt --dependency=afterok:${job_id} --mem=1G --wrap="rm ${DATA_DIR}/${PHEN}/${ADJ}/${FN}.gwas.comb")
job_id_5=$(sbatch --output ${DATA_DIR}/${PHEN}/${ADJ}/slurm-delete-interim-trans-%A.txt --dependency=afterok:${job_id} --mem=1G --wrap="rm ${GWAS_FN}")
done
done
done

echo "Waiting for remaining jobs"
waitID=$init_wait_id
# srun --dependency=${job_ids} echo "Done"
job_ids=$(sed 's/afterok\://g' <<< $job_ids)
IFS=':' read -r -a job_ids_array <<< "$job_ids"
len=${#job_ids_array[@]}
for(( ii=0; ii<$len; ii=ii+1000 ))
do
tempID=$init_wait_id
for((jj=ii;jj<$len&jj<ii+1000;jj++))
do
tempID="${tempID}:${job_ids_array[$jj]}"
done
echo $tempID
job_id=$(sbatch ${EXCLUDE}--mem=1G --output ${LOG_DIR}/slurm-formatting-wait-%A.txt --dependency=${tempID} --wrap="echo 'Done'")
job_id=$(echo $job_id | sed 's/Submitted batch job //')
waitID="${waitID}:${job_id}"
done
echo $waitID
srun --dependency=${waitID} echo "Roadblock done"

else

echo "No Rsq replacement" >>${FORMATTING_LOG}
echo "No Rsq replacement"

for PHEN in ${PHENOTYPE_NAMES}
do
for FN in ${COHORTS}
do
for ADJ in ${ADJS}
do
GWAS_FN="${DATA_DIR}/${PHEN}/${ADJ}/${FN}.gwas.comb.trans"
mv "${GWAS_FN}" "${GWAS_FN}.imp"
done
done
done
echo "Move done (.imp)"

echo "Now deleting"
for PHEN in ${PHENOTYPE_NAMES}
do
for FN in ${COHORTS}
do
for ADJ in ${ADJS}
do
GWAS_FN="${DATA_DIR}/${PHEN}/${ADJ}/${FN}.gwas.comb.trans"
echo "Deleting: ${GWAS_FN}"
job_id_2=$(sbatch --output ${DATA_DIR}/${PHEN}/${ADJ}/slurm-delete-interim-gwas-%A.txt --mem=1G --wrap="rm ${DATA_DIR}/${PHEN}/${ADJ}/${FN}-chr*.gwas")
job_id_3=$(sbatch --output ${DATA_DIR}/${PHEN}/${ADJ}/slurm-delete-interim-out-%A.txt --mem=1G --wrap="rm ${DATA_DIR}/${PHEN}/${ADJ}/${FN}-chr*.out")
job_id_4=$(sbatch --output ${DATA_DIR}/${PHEN}/${ADJ}/slurm-delete-interim-comb-%A.txt --mem=1G --wrap="rm ${DATA_DIR}/${PHEN}/${ADJ}/${FN}.gwas.comb")
job_id_5=$(sbatch --output ${DATA_DIR}/${PHEN}/${ADJ}/slurm-delete-interim-trans-%A.txt --mem=1G --wrap="rm ${GWAS_FN}")
done
done
done

fi



for PHEN in ${PHENOTYPE_NAMES}
do
for FN in ${COHORTS}
do
for ADJ in ${ADJS}
do
GWAS_FN="${DATA_DIR}/${PHEN}/${ADJ}/${FN}.gwas"
mv "${GWAS_FN}.comb.trans.imp" "${GWAS_FN}"
done
done
done
echo "Move done"


echo "Done" | tee -a ${FORMATTING_LOG}
