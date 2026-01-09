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

clear

echo -e "\n${CYAN}=== PUSH_SWAP TESTER ===${RESET}\n"

check_dev_mode() {
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

    if [ "$CURRENT_BRANCH" == "dev" ]; then
        echo -e "\n${MAGENTA}⚠️  WARNING: YOU ARE IN DEVELOPER MODE (dev branch) ⚠️${NC}"
        echo -e "${MAGENTA}This version might be unstable.${NC}"
        echo -e "If you are a student, please switch to stable: ${CYAN}git checkout main${NC}\n"
        sleep 5
    fi
}

check_updates() {
    if [ -d ".git" ]; then
        echo -n -e "${CYAN}Checking for updates... ${NC}"
        
        git fetch origin > /dev/null 2>&1
        
        LOCAL=$(git rev-parse HEAD)
        REMOTE=$(git rev-parse @{u} 2>/dev/null)

        if [ -z "$REMOTE" ]; then
            return
        fi

        if [ "$LOCAL" != "$REMOTE" ]; then
            echo -e "${RED}[UPDATE FOUND]${NC}"
            echo -e "\n${YELLOW}🚨  A NEW VERSION IS AVAILABLE!  🚨${NC}"
            echo -e "You are using an old version of the tester."
            echo -e "Do you want to update it now? (Recommended) [y/N]"
            read -r -p "Select: " RESPONSE
            
            if [[ "$RESPONSE" =~ ^[yY]$ ]]; then
                echo -e "${GREEN}Downloading updates...${NC}"
                git pull
                echo -e "\n${GREEN}✅ Update successful!${NC}"
                echo -e "${CYAN}Please restart the tester to apply changes.${NC}"
                exit 0
            else
                echo -e "${YELLOW}Update skipped. Continuing with current version...${NC}\n"
            fi
        else
            echo -e "${GREEN}[UP TO DATE]${NC}"
        fi
    fi
}

check_dev_mode
check_updates

rm -f errors.log valgrind_out.txt

echo "=== TEST SESSION STARTED: $(date) ===" > "$LOG_FILE"
echo "Detailed logs below." >> "$LOG_FILE"
echo "-----------------------------------" >> "$LOG_FILE"

echo ""

echo -e "${CYAN}Checking Norminette...${RESET}"

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

echo -e "${BLUE}Compiling Project...${NC}"
make -C "$SOURCE_PATH" > /dev/null

if [ ! -f "$PUSH_SWAP" ]; then
    echo -e "${RED}Error: Compilation failed or binary not found.${NC}"
    exit 1
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
            echo "ERROR TEST FAILED: Input '$ARG'" >> "$LOG_FILE"
        fi
    done
}

check_allowed_function() {
    echo -e "\n${BLUE}=== ALLOWED FUNCTIONS CHECK ===${NC}"
    
    WHITELIST_FILE=".whitelist.txt"
    BINARY="$PUSH_SWAP"
    
    if [ ! -f "$BINARY" ]; then
        echo -e "${RED}Error: Binary $BINARY not found!${NC}"
        return
    fi

    USED_FUNCS=$(nm -u "$BINARY" | awk '{print $2}' | sort | uniq)
    VIOLATION=0
    
    if [ ! -f "$WHITELIST_FILE" ]; then
        echo -e "${YELLOW}Warning: $WHITELIST_FILE not found.${NC}"
        return
    fi
    ALLOWED_FUNCS=$(cat "$WHITELIST_FILE")

    for func in $USED_FUNCS; do
        clean_func=${func%%@*}
        clean_func=${clean_func#_}

        if [[ "$clean_func" == _* || "$clean_func" == .* ]]; then
            continue
        fi
        
        if [[ "$clean_func" == "dyld_stub_binder" || "$clean_func" == "gmon_start" || \
              "$clean_func" == "data_start" || "$clean_func" == "edata" || \
              "$clean_func" == "end" || "$clean_func" == "bss_start" || \
              "$clean_func" == "ITM_deregisterTMCloneTable" || \
              "$clean_func" == "ITM_registerTMCloneTable" || \
              "$clean_func" == "stack_chk_fail" || "$clean_func" == "_stack_chk_fail" ]]; then
            continue
        fi

        if ! echo "$ALLOWED_FUNCS" | grep -w -q "^$clean_func$"; then
            echo -e "Forbidden function used: ${RED}$clean_func${NC}"
            VIOLATION=1
        fi
    done

    if [ $VIOLATION -eq 0 ]; then
        echo -e "No Forbidden Functions. ${GREEN}[OK]${NC}"
    else
        echo -e "${RED}Forbidden functions detected!${NC}"
        if [ -n "$LOG_FILE" ]; then
            echo "FORBIDDEN FUNCTIONS DETECTED" >> "$LOG_FILE"
        fi
    fi
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
        TOTAL_MOVES=$((TOTAL_MOVES + MOVES))
        if [ $MOVES -gt $MAX_MOVES ]; then MAX_MOVES=$MOVES; fi
        if [ $MOVES -lt $MIN_MOVES ]; then MIN_MOVES=$MOVES; fi
        if [ $MOVES -le $LIMIT ]; then
            echo -e "Run $i: ${GREEN}$MOVES${NC}"
        else
            echo -e "Run $i: ${YELLOW}$MOVES${NC}"
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
        check_allowed_function
        run_test_loop 3 4 5
        run_test_loop 5 12 10
        run_test_loop 100 700 20
        run_test_loop 500 5500 20
        check_leaks
    elif [ "$MODE" == "100" ]; then
        check_allowed_function
        run_test_loop 100 700 $COUNT
    elif [ "$MODE" == "500" ]; then
        check_allowed_function
        run_test_loop 500 5500 $COUNT
    fi

    make fclean -C "$SOURCE_PATH" > /dev/null
    rm -f "$CHECKER"
}

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