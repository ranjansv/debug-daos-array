#!/bin/bash

POOL_UUID=`dmg -i -o $daos_config pool list --verbose | tail -2|head -1|awk '{print $2}'`
echo "POOL_UUID: $POOL_UUID"
echo "SLURM_JOB_NUM_NODES: $SLURM_JOB_NUM_NODES"

CONFIG_FILE=$1

#Load config file
source ${CONFIG_FILE}

#Create timestamped output directory
TIMESTAMP=`echo $(date +%Y-%m-%d-%H:%M:%S)`
RESULT_DIR="results/$TIMESTAMP"
mkdir -p $RESULT_DIR

echo "Result dir: $RESULT_DIR"

rm results/latest
ln -s $TIMESTAMP results/latest

#mount > $RESULT_DIR/fs-mounts.log
git branch --show-current > $RESULT_DIR/git.log 
git log --format="%H" -n 1 >> $RESULT_DIR/git.log

#Build source
cd build
make clean && make
cd ..

#Copy configs and xml to outputdir
cp ${CONFIG_FILE} $RESULT_DIR/config.sh

SCRIPT_NAME=`basename "$0"`
cp ./$SCRIPT_NAME  $RESULT_DIR/



is_daos_agent_running=`pgrep daos_agent`
echo $is_daos_agent_running
if [[ $is_daos_agent_running -eq "" ]]
then
export TACC_TASKS_PER_NODE=1
ibrun -np $SLURM_JOB_NUM_NODES  ./daos_startup.sh &
unset TACC_TASKS_PER_NODE
else
   echo "daos_agent is already running"
fi

echo "Waiting for agent to initialize..."
sleep 6

RANKS_PER_NODE=28
echo "Staring tests"


  for NR in $PROCS
  do
      writer_nodes=$((($NR + $RANKS_PER_NODE - 1)/$RANKS_PER_NODE))
      for IO_NAME in $ENGINE
      do
  	#Parse IO_NAME for engine and storage type in case of DAOS
  	if grep -q "daos-posix" <<< "$IO_NAME"; then
  		ENG_TYPE="daos-posix"
  		FILENAME="/tmp/dfuse/output.bp"
  		MOUNTPOINT="/tmp/dfuse"
  		PRELOAD_LIBPATH="/work2/08126/dbohninx/frontera/4NODE/BUILDS/latest/daos/install/lib64/libioil.so"
  	#Following engine types are for DAOS which don't use ADIOS2
  	elif grep -q "daos-array" <<< "$IO_NAME"; then
  		ENG_TYPE="daos-array"
  		FILENAME="N/A"
  	fi
  
          for DATASIZE in $DATA_PER_RANK
          do
	    TOTAL_DATA_SIZE=`echo "scale=0; $DATASIZE * ($NR) * $STEPS" | bc`
  	    echo ""
  	    echo ""
            echo "Processing ${NR} writers , ${ENG_TYPE}:${FILENAME}, ${DATASIZE}mb"
  	    GLOBAL_ARRAY_SIZE=`echo "scale=0; $DATASIZE * ($NR)" | bc`
  	    echo "global array size: $GLOBAL_ARRAY_SIZE"
  
  	    export I_MPI_PIN=0
  
  
  	    if [ $BENCH_TYPE == "writer" ]
  	    then
  	       if [ $ENG_TYPE == "daos-array" ]
  	       then
  		    echo "Destroying previous containers, if any "
  		    daos pool list-cont --pool=$POOL_UUID |sed -e '1,2d'|awk '{print $1}'|xargs -L 1 -I '{}' sh -c "daos cont destroy --cont={} --pool=$POOL_UUID --force"

  		   CONT_UUID=`daos cont create --pool=$POOL_UUID|grep -i 'created container'|awk '{print $4}'`
                   echo "New container UUID: $CONT_UUID"
	           OUTPUT_DIR="$RESULT_DIR/${NR}ranks/${DATASIZE}mb/${IO_NAME}/"
		   mkdir -p $OUTPUT_DIR
		   export I_MPI_ROOT=/opt/intel/compilers_and_libraries_2020.4.304/linux/mpi
		   export TACC_MPI_GETMODE=impi_hydra
  	           START_TIME=$SECONDS
                     ibrun -o 0 -n $NR numactl --cpunodebind=0 --preferred=0 build/daos_array-writer-obj-per-rank $POOL_UUID $CONT_UUID $GLOBAL_ARRAY_SIZE $STEPS &>> $OUTPUT_DIR/stdout-mpirun-writers.log
  	           ELAPSED_TIME=$(($SECONDS - $START_TIME))
		   unset I_MPI_ROOT
		   unset TACC_MPI_GETMODE
  
  	           echo "$ELAPSED_TIME" > $OUTPUT_DIR/workflow-time.log
  	       fi
  	    fi
          done
      done
done

echo "Cleanup: Destroying containers"
daos pool list-cont --pool=$POOL_UUID |sed -e '1,2d'|awk '{print $1}'|xargs -L 1 -I '{}' sh -c "daos cont destroy --cont={} --pool=$POOL_UUID --force"


echo "List of stdout files with error"
find $RESULT_DIR/ -iname 'stdout*.log'|xargs grep -ilE 'error|bad|terminat'

