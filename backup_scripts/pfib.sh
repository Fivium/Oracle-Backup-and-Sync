#!/bin/bash

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
