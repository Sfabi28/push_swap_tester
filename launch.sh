#!/bin/bash

PUSH_SWAP="../push_swap"
CHECKER="./checker"
SOURCE_PATH=".."

TESTER_NAME="push_swap_tester"
LOG_FILE="test_results.log"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
RESET='\033[0m'

rm -f errors.log valgrind_out.txt

echo "=== TEST SESSION STARTED: $(date) ===" > "$LOG_FILE"
echo "Detailed logs below." >> "$LOG_FILE"
echo "-----------------------------------" >> "$LOG_FILE"

echo ""

echo -e "${CYAN} Checking Norminette...${RESET}"

TESTER_DIR=$(basename "$PWD")

FILES_TO_CHECK=$(find "$SOURCE_PATH" -maxdepth 1 -type f \( -name "*.c" -o -name "*.h" \) | grep -v "/$TESTER_DIR/" | tr '\n' ' ')

if [ -z "$FILES_TO_CHECK" ]; then
    NORM_OUT=""
else
    NORM_OUT=$(norminette $FILES_TO_CHECK | grep -v "OK!" | grep -v "Error: ")
fi

if [ -z "$NORM_OUT" ]; then
    echo -e "${GREEN}[NORM OK]${RESET}"
    echo "[NORM OK]" >> "$LOG_FILE"
else
    echo -e "${RED}[NORM KO]${RESET}"
    echo "$NORM_OUT"
    echo "--- NORMINETTE ERRORS ---" >> "$LOG_FILE"
    echo "$NORM_OUT" >> "$LOG_FILE"
    echo "-------------------------" >> "$LOG_FILE"
fi
echo ""

if [ ! -f "$PUSH_SWAP" ]; then
    echo -e "${BLUE}Compiling Project...${NC}"
    make -C .. > /dev/null
    if [ ! -f "$PUSH_SWAP" ]; then
        echo -e "${RED}Error: Compilation failed.${NC}"
        exit 1
    fi
fi

TOTAL_MOVES=0
MAX_MOVES=0
MIN_MOVES=100000
VALGRIND="valgrind --leak-check=full --show-leak-kinds=all --errors-for-leak-kinds=all"

generate_arg() {
    count=$1
    python3 -c "import random; print(' '.join(map(str, random.sample(range(-10000, 10000), $count))))"
}

reset_stats() {
    TOTAL_MOVES=0
    MAX_MOVES=0
    MIN_MOVES=100000
}

check_error_management() {
    echo -e "\n${BLUE}=== ERROR MANAGEMENT ===${NC}"
    declare -a ERR_ARGS=("a b c" "1 2 3 2" "2147483648" "-2147483649" "")
    for ARG in "${ERR_ARGS[@]}"; do
        OUT=$($PUSH_SWAP $ARG 2>&1)
        if [ -z "$ARG" ]; then
             if [ -z "$OUT" ]; then echo -e "Empty Input: ${GREEN}[OK]${NC}"; else echo -e "Empty Input: ${RED}[KO]${NC}"; fi
        elif [ "$OUT" == "Error" ]; then
            echo -e "Input '$ARG': ${GREEN}[OK]${NC}"
        else
            echo -e "Input '$ARG': ${RED}[KO]${NC}"
        fi
    done
}

check_leaks() {
    echo -e "\n${BLUE}=== LEAK CHECK ===${NC}"
    ARG=$(generate_arg 10)
    $VALGRIND $PUSH_SWAP $ARG > /dev/null 2> valgrind_out.txt
    if grep -q "All heap blocks were freed" valgrind_out.txt; then
        echo -e "${GREEN}[CLEAN]${NC}"
    else
        echo -e "${RED}[LEAKS]${NC}"
        cat valgrind_out.txt
    fi
    rm -f valgrind_out.txt
}

run_test_loop() {
    QTY=$1
    LIMIT=$2
    RUNS=$3
    echo -e "\n${BLUE}=== TEST $QTY NUMBERS ($RUNS run) < $LIMIT ===${NC}"
    reset_stats
    for ((i=1; i<=RUNS; i++)); do
        ARG=$(generate_arg $QTY)
        MOVES=$($PUSH_SWAP $ARG | wc -l)
        CHECK_OUT=$($PUSH_SWAP $ARG | $CHECKER $ARG 2>&1)
        TOTAL_MOVES=$((TOTAL_MOVES + MOVES))
        if [ $MOVES -gt $MAX_MOVES ]; then MAX_MOVES=$MOVES; fi
        if [ $MOVES -lt $MIN_MOVES ]; then MIN_MOVES=$MOVES; fi
        if [[ "$CHECK_OUT" == *"OK"* ]] && [ $MOVES -le $LIMIT ]; then
            echo -e "Run $i: ${GREEN}[OK]${NC} $MOVES"
        elif [[ "$CHECK_OUT" == *"OK"* ]] && [ $MOVES -gt $LIMIT ]; then
            echo -e "Run $i: ${YELLOW}[WARNING]${NC} $MOVES"
        else
            echo -e "Run $i: ${RED}[KO]${NC} $CHECK_OUT | $MOVES"
            echo "FAILED: $ARG" >> "$LOG_FILE"
        fi
    done
    AVG=$((TOTAL_MOVES / RUNS))
    echo -e "Min: $MIN_MOVES | Max: $MAX_MOVES | ${YELLOW}Avg: $AVG${NC}"
    if [ $AVG -le $LIMIT ]; then echo -e "${GREEN}PASSED${NC}"; else echo -e "${RED}FAILED${NC}"; fi
}

run_tester() {
    MODE=$1
    COUNT=${2:-20}

    if [ "$MODE" == "COMPLETE" ]; then
        check_error_management
        run_test_loop 3 3 5
        run_test_loop 5 12 10
        run_test_loop 100 700 20
        run_test_loop 500 5500 20
        check_leaks
    elif [ "$MODE" == "100" ]; then
        run_test_loop 100 700 $COUNT
    elif [ "$MODE" == "500" ]; then
        run_test_loop 500 5500 $COUNT
    fi
}

echo -e "\n${CYAN}=== PUSH_SWAP TESTER ===${RESET}"

if [ -z "$1" ]; then
    run_tester "COMPLETE"
elif [[ "$1" == "100" && -z "$2" ]]; then
    run_tester "100"
elif [[ "$1" == "500" && -z "$2" ]]; then
    run_tester "500"
elif [[ "$1" == "100" && -n "$2" ]]; then
    run_tester "100" "$2"
elif [[ "$1" == "500" && -n "$2" ]]; then
    run_tester "500" "$2"
else
    echo -e "${YELLOW}Invalid arguments. Usage: ./launch.sh [100|500] [count]${RESET}"
fi

echo -e "\n${CYAN}=== DONE ===${RESET}"
