#!/bin/bash
#
# This is a cpu saturation test 
#
if [ $# -ne 2 ]
then
    echo "Wrong argument count, Usage:  pfib.sh <fibonacci_series_calculations> <number_of_threads_to_run_on>"
    echo "eg time ./pfib.sh 300000 4"
    exit 1
fi

# Static input for N
N=$1

THREADS=$2

function msg {
    echo "--"
    echo "-- $1"
    echo "--"
}

function fib {

    # First Number of the
    # Fibonacci Series
    a=0

    # Second Number of the
    # Fibonacci Series
    b=1

    for (( i=0; i<N; i++ ))
    do
        fn=$((a + b))
        a=$b
        b=$fn
    done

    echo -n "    ans : $a "
    echo ""

}

msg "Calculating Fibonacci series for $N, same workload on $THREADS threads"

for (( c=1; c<=$THREADS; c++ ))
do
    echo "    submit thread : $c"
    fib $N &
done

wait

msg 'Done'
