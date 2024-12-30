#!/usr/bin/bash

function print_help() {
    echo
    echo "That script runs my_ping.pl script with options provided by that program and prints short summary."
    echo "Usage:"
    echo " script.sh [options] <input filename>"
    printf " -c <count>\tpass that parameter to my_ping.pl. Set to 4 by default\n"
    printf " -H\t\tdisplay my_ping.pl help\n"
    printf " -h\t\tdisplay this help\n"
    printf " -I <interval>\tpass that parameter to my_ping.pl\n"
    printf " -i <filename>\tinput filename. If this option provided <input filename> mustn't be provided\n"
    printf " -o <filename>\touput filename. If not set, my_ping.pl will print to stdout\n"
    printf " -O\t\tshould be used together with -o. If set outputs of each my_ping.pl will be saved to separate files\n"
    printf " -p\t\tshould be used together with -o. Prints output to file and to stdout\n"
    printf " -q\t\tpass that parameter to my_ping.pl\n"
    printf " -s\t\tif set SIGINT will interrupt that script. If not set SIGINT will interupt currently running my_ping\n"
    exit 1
}

function summary() {
    file=$1
    while IFS= read -r line; do
        if [[ ${line:0:3} = "---" ]];then
            regex="[a-zA-Z0-9]+\.[a-zA-Z]{2,}"
            if [[ $line =~ ($regex) ]]; then
                curr_host="${BASH_REMATCH[1]}"
            fi
        fi
        if [[ "$line" = *"packets transmitted"* ]]; then
            IFS=' ' read -r -a array <<< "$line"
            transmitted=${array[0]}
            received=${array[3]}
            total_transmitted=$((total_transmitted+transmitted))
            total_received=$((total_received+received))
        fi
        if [[ ${line:0:3} = "rtt" ]]; then
            regex="([0-9]*[.])?[0-9]+/([0-9]*[.])?[0-9]+/([0-9]*[.])?[0-9]+"
            if [[ $line =~ ($regex) ]]; then
                times="${BASH_REMATCH[1]}"
                IFS='/' read -r -a array <<< "$times"
                min=${array[0]}
                avg=${array[1]}
                max=${array[2]}
                if [[ $(echo "$min < $global_min" |bc -l) -eq 1 ]];then
                    global_min=$min
                    min_host="$curr_host"
                fi
                if [[ $(echo "$max > $global_max" |bc -l) -eq 1 ]]; then
                    global_max=$max
                    max_host="$curr_host"
                fi
            fi
        fi
    done < "$file"
}

TEMP=`getopt -o :h::H::s::i:I:c:q::o:O::p:: --long help:: -- "$@"`
eval set -- "$TEMP"

count_flag="-c"
count=4
interval_flag=""
interval=
quiet_flag=""
separate_files=false
file_and_std=false

while true; do
    case $1 in
        -[c])
            count="$2"
            shift 2
            ;;
        -[I])
            interval_flag="-i"
            interval="$2"
            shift 2
            ;;
        -[q])
            quiet_flag="-q"
            shift
            ;;
        -[s])
            trap 'exit' 2
            shift 2 ;;
        -[h]|--help)
            print_help
            ;;
        -[H])
            echo "perl my_ping.pl -h"
            perl my_ping.pl -h
            exit 1
            ;;
        -[i])
            hosts_file="$2"
            shift 2 ;;
        -[o])
            output_file="$2"
            shift 2 ;;
        -[O])
            separate_files=true
            shift 2 ;;
        -[p])
            file_and_std=true
            shift 2 ;;
        --)
            shift 
            break ;;
    esac
done

if [ "$hosts_file" = "" ]; then
    hosts_file="$1"
fi

hosts=()
while IFS= read -r line; do
    hosts+=("$line")
done < "$hosts_file"

for line in "${hosts[@]}"; do
    echo "sudo perl my_ping.pl $count_flag $count $interval_flag $interval $quiet_flag $line"
    if [[ $output_file != "" ]]; then
        out=$output_file
        out=$(echo -n "$output_file"-"$line")
        if [ "$file_and_std" = true ]; then
            sudo perl my_ping.pl $count_flag $count $interval_flag $interval $quiet_flag $line | tee $out
        else
            sudo perl my_ping.pl $count_flag $count $interval_flag $interval $quiet_flag $line >> $out
        fi
    else 
        sudo perl my_ping.pl $count_flag $count $interval_flag $interval $quiet_flag $line | tee $(echo -n tmp-"$line")
    fi
    echo
done


# summary
global_min=10000
global_max=0
min_host=""
max_host=""
total_transmitted=0
total_received=0

if [[ $output_file != "" ]]; then
    for f in $output_file*; do
        summary $f
    done
    
    if [ "$separate_files" = false ]; then
        cat $output_file-* > "$output_file"
        rm $output_file-*
    fi
else
    for f in tmp*; do
        summary $f
    done
    rm tmp*
fi

echo Summary
echo Total packets transmitted: $total_transmitted
echo Total packets received: $total_received
echo Max time $global_max to host $max_host
echo Min time $global_min to host $min_host