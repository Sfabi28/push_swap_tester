#!/bin/bash

PUSH_SWAP="../push_swap"
CHECKER="./checker_linux"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

rm -f errors.log valgrind_out.txt

if [ ! -f "$PUSH_SWAP" ]; then
    echo -e "${BLUE}Compiling Project...${NC}"
    
    make -C .. > /dev/null
    
    if [ ! -f "$PUSH_SWAP" ]; then
        echo -e "${RED}Error: Compilation failed! Check your Makefile.${NC}"
        exit 1
    else
        echo -e "${GREEN}Project Compiled!${NC}"
    fi
fi

TOTAL_MOVES=0
MAX_MOVES=0
MIN_MOVES=100000

generate_arg() {
    count=$1
    python3 -c "import random; print(' '.join(map(str, random.sample(range(-10000, 10000), $count))))"
}

reset_stats() {
    TOTAL_MOVES=0
    MAX_MOVES=0
    MIN_MOVES=100000
}

run_test_loop() {
    QTY=$1
    LIMIT=$2
    RUNS=$3

    echo -e "\n${BLUE}=== TEST $QTY NUMBERS ($RUNS runs) - Target: < $LIMIT ===${NC}"
    reset_stats

    for ((i=1; i<=RUNS; i++)); do
        
        ARG=$(generate_arg $QTY)
        
        MOVES=$($PUSH_SWAP $ARG | wc -l)
        
        CHECK_OUT=$($PUSH_SWAP $ARG | $CHECKER $ARG 2>&1)

        TOTAL_MOVES=$((TOTAL_MOVES + MOVES))
        if [ $MOVES -gt $MAX_MOVES ]; then MAX_MOVES=$MOVES; fi
        if [ $MOVES -lt $MIN_MOVES ]; then MIN_MOVES=$MOVES; fi

        if [[ "$CHECK_OUT" == *"OK"* ]] && [ $MOVES -le $LIMIT ]; then
            echo -e "Run $i: ${GREEN}[OK]${NC} Moves: $MOVES"
        elif [[ "$CHECK_OUT" == *"OK"* ]] && [ $MOVES -gt $LIMIT ]; then
            echo -e "Run $i: ${YELLOW}[WARNING]${NC} Moves: $MOVES (Limit exceeded!)"
        else
            echo -e "Run $i: ${RED}[KO]${NC} Checker: $CHECK_OUT | Moves: $MOVES"
            echo "FAILED ARGS: $ARG" >> errors.log
        fi
    done

    AVG=$((TOTAL_MOVES / RUNS))
    echo -e "---------------------------------"
    echo -e "Min: $MIN_MOVES | Max: $MAX_MOVES | ${YELLOW}Average: $AVG${NC}"
    
    if [ $AVG -le $LIMIT ]; then
        echo -e "GLOBAL RESULT: ${GREEN}PASSED${NC}"
    else
        echo -e "GLOBAL RESULT: ${RED}FAILED (Average too high)${NC}"
    fi
}

VALGRIND="valgrind --leak-check=full --show-leak-kinds=all --errors-for-leak-kinds=all --quiet"

check_error_management() {
    echo -e "\n${BLUE}=== ERROR MANAGEMENT (Invalid Input) ===${NC}"
    
    declare -a ERR_ARGS=(
        "a b c"
        "1 2 3 2"
        "2147483648"
        "-2147483649"
        ""
    )
    
    for ARG in "${ERR_ARGS[@]}"; do
        OUT=$($PUSH_SWAP $ARG 2>&1)
        
        if [ -z "$ARG" ]; then
             if [ -z "$OUT" ]; then echo -e "Empty Input: ${GREEN}[OK]${NC}"; else echo -e "Empty Input: ${RED}[KO]${NC} (Got output: '$OUT')"; fi
        elif [ "$OUT" == "Error" ]; then
            echo -e "Input '$ARG': ${GREEN}[OK]${NC}"
        else
            echo -e "Input '$ARG': ${RED}[KO]${NC} (Expected 'Error', Got '$OUT')"
        fi
    done
}

check_leaks() {
    echo -e "\n${BLUE}=== LEAK CHECK (Valgrind on 10 numbers) ===${NC}"
    ARG=$(generate_arg 10)
    
    $VALGRIND $PUSH_SWAP $ARG > /dev/null 2> valgrind_out.txt
    
    if grep -q "All heap blocks were freed" valgrind_out.txt; then
        echo -e "${GREEN}[CLEAN]${NC} No leaks detected."
    else
        echo -e "${RED}[LEAKS]${NC} Memory issues found! Check valgrind_out.txt"
        cat valgrind_out.txt
    fi
    rm -f valgrind_out.txt
}

check_error_management

echo -e "\n${BLUE}=== IDENTITY TEST (Already sorted) ===${NC}"
ARG="1 2 3 4 5"
MOVES=$($PUSH_SWAP $ARG | wc -l)
if [ $MOVES -eq 0 ]; then echo -e "Sorted list: ${GREEN}[OK]${NC}"; else echo -e "Sorted list: ${RED}[KO]${NC} ($MOVES moves instead of 0)"; fi

run_test_loop 3 3 5
run_test_loop 5 12 10

run_test_loop 100 700 20

run_test_loop 500 5500 20

check_leaks

echo -e "\n${GREEN}Tests completed.${NC}"