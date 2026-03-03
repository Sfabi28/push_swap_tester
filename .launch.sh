#!/bin/bash

TIMEOUT_TIME=5

PUSH_SWAP="../push_swap"
CHECKER="./.checker"
USER_CHECKER="../checker"
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

echo "" > ".empty_check"

EMPTY="./.empty_check"
chmod 777 $EMPTY

check_dev_mode() {
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

    if [[ "$CURRENT_BRANCH" == "dev" || "$CURRENT_BRANCH" == "Dev" ]]; then
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

rm -f test_results.log valgrind_log.txt

printf "=== TEST SESSION STARTED: %s ===\n" "$(date)" > "$LOG_FILE"
printf "Detailed logs below.\n" >> "$LOG_FILE"
printf "-----------------------------------\n" >> "$LOG_FILE"

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
    printf "[NORM OK]\n" >> "$LOG_FILE"
else
    echo -e "${RED}[NORM KO]${RESET}"
    echo "$NORM_OUT"
    printf "--- NORMINETTE ERRORS ---\n" >> "$LOG_FILE"
    printf "%s\n" "$NORM_OUT" >> "$LOG_FILE"
    printf "-------------------------\n" >> "$LOG_FILE"
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
    python3 -c "import random; print(' '.join(map(str, random.sample(range(-25000, 25000), $count))))"
}

reset_stats() {
    TOTAL_MOVES=0
    MAX_MOVES=0
    MIN_MOVES=100000
}

run_push_swap_with_timeout() {
    local arg="$1"

    if command -v timeout >/dev/null 2>&1; then
        timeout "$TIMEOUT_TIME" "$PUSH_SWAP" $arg
        return $?
    fi

    "$PUSH_SWAP" $arg
    return $?
}

run_valgrind_with_timeout() {
    if command -v timeout >/dev/null 2>&1; then
        timeout "$TIMEOUT_TIME" $VALGRIND "$@"
        return $?
    fi

    $VALGRIND "$@"
    return $?
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
            printf "ERROR TEST FAILED: Input '%s'\n" "$ARG" >> "$LOG_FILE"
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
            printf "FORBIDDEN FUNCTIONS DETECTED\n" >> "$LOG_FILE"
        fi
    fi
}

check_leaks() {
    echo -e "\n${BLUE}=== LEAK CHECK ===${NC}"
    TIMEOUT_DETECTED=0
    for ((i=1; i<=10; i++)); do
        ARG=$(generate_arg 10)
        run_valgrind_with_timeout "$PUSH_SWAP" $ARG > /dev/null 2>> valgrind_log.txt
        STATUS=$?
        if [ $STATUS -eq 124 ]; then
            echo -e "Valgrind run $i: ${RED}[TIMEOUT]${NC}"
            printf "VALGRIND TIMEOUT: %s %s\n" "$PUSH_SWAP" "$ARG" >> "$LOG_FILE"
            TIMEOUT_DETECTED=1
        fi
    done

    ARG=$(generate_arg 100)
    run_valgrind_with_timeout "$PUSH_SWAP" $ARG > /dev/null 2>> valgrind_log.txt
    STATUS=$?
    if [ $STATUS -eq 124 ]; then
        echo -e "Valgrind run 100 nums: ${RED}[TIMEOUT]${NC}"
        printf "VALGRIND TIMEOUT: %s %s\n" "$PUSH_SWAP" "$ARG" >> "$LOG_FILE"
        TIMEOUT_DETECTED=1
    fi


    ARG=$(generate_arg 0)
    run_valgrind_with_timeout "$PUSH_SWAP" $ARG > /dev/null 2>> valgrind_log.txt
    STATUS=$?
    if [ $STATUS -eq 124 ]; then
        echo -e "Valgrind run empty input: ${RED}[TIMEOUT]${NC}"
        printf "VALGRIND TIMEOUT: %s %s\n" "$PUSH_SWAP" "$ARG" >> "$LOG_FILE"
        TIMEOUT_DETECTED=1
    fi


    ARG="a b c d"
    run_valgrind_with_timeout "$PUSH_SWAP" $ARG > /dev/null 2>> valgrind_log.txt
    STATUS=$?
    if [ $STATUS -eq 124 ]; then
        echo -e "Valgrind run invalid input: ${RED}[TIMEOUT]${NC}"
        printf "VALGRIND TIMEOUT: %s %s\n" "$PUSH_SWAP" "$ARG" >> "$LOG_FILE"
        TIMEOUT_DETECTED=1
    fi

    if [ $TIMEOUT_DETECTED -eq 1 ]; then
        echo -e "${YELLOW}Some Valgrind runs timed out.${NC}"
    fi

    if grep -E -q "definitely lost: [1-9][0-9]* bytes" valgrind_log.txt || \
       grep -E -q "ERROR SUMMARY: [1-9][0-9]* errors" valgrind_log.txt; then
        echo -e "${RED}[LEAKS]${NC}"
    else
        echo -e "${GREEN}[CLEAN]${NC}"
        rm -f valgrind_log.txt
    fi
}

run_test_loop() {
    QTY=$1
    LIMIT=$2
    RUNS=$3
    EXECUTED_RUNS=0
    echo -e "\n${BLUE}=== TEST $QTY NUMBERS ($RUNS run) <= $LIMIT ===${NC}"
    reset_stats
    if [ ! -x "$CHECKER" ]; then
        echo -e "${YELLOW}Warning: $CHECKER not found or not executable; falling back to move-count only.${NC}"
        USE_CHECKER=0
    else
        USE_CHECKER=1
    fi

    for ((i=1; i<=RUNS; i++)); do
        ARG=$(generate_arg $QTY)
        OUT=$(run_push_swap_with_timeout "$ARG" 2>/dev/null)
        STATUS=$?

        if [ $STATUS -eq 124 ]; then
            echo -e "Run $i: ${RED}[TIMEOUT]${NC}"
            printf "TIMEOUT: %s\n" "$ARG" >> "$LOG_FILE"
            continue
        fi

        MOVES=$(echo "$OUT" | wc -l)
        if [ $USE_CHECKER -eq 1 ]; then

            if [ -z "$OUT" ]; then
                if $EMPTY | $CHECKER $ARG 2>/dev/null | grep -q "OK"; then
                    echo -e "Run $i: ${GREEN}0${NC}"
                else
                    echo -e "Run $i: ${RED}0 (NOT SORTED)${NC}"
                    printf "NOT SORTED: %s, MOVES: .%s.\n" "$ARG" "$OUT" >> "$LOG_FILE"
                fi
            elif echo "$OUT" | $CHECKER $ARG 2>/dev/null | grep -q "OK"; then
                if [ $MOVES -le $LIMIT ]; then
                    echo -e "Run $i: ${GREEN}$MOVES${NC}"
                else
                    echo -e "Run $i: ${YELLOW}$MOVES${NC}"
                    printf "OVER MAX MOVES: %s\n" "$ARG" >> "$LOG_FILE"
                fi
            else
                echo -e "Run $i: ${RED}$MOVES (NOT SORTED)${NC}"
                printf "NOT SORTED: %s, MOVES: .%s.\n" "$ARG" "$OUT" >> "$LOG_FILE"
            fi
        else
            if [ $MOVES -le $LIMIT ]; then
                echo -e "Run $i: ${GREEN}$MOVES${NC}"
            else
                echo -e "Run $i: ${YELLOW}$MOVES${NC}"
                printf "OVER MAX MOVES: %s\n" "$ARG" >> "$LOG_FILE"
            fi
        fi
        TOTAL_MOVES=$((TOTAL_MOVES + MOVES))
        EXECUTED_RUNS=$((EXECUTED_RUNS + 1))
        if [ $MOVES -gt $MAX_MOVES ]; then MAX_MOVES=$MOVES; fi
        if [ $MOVES -lt $MIN_MOVES ]; then MIN_MOVES=$MOVES; fi
    done

    if [ $EXECUTED_RUNS -eq 0 ]; then
        echo -e "${YELLOW}No completed runs (all timed out).${NC}"
        return
    fi

    AVG=$((TOTAL_MOVES / EXECUTED_RUNS))
    echo -e "Min: $MIN_MOVES | Max: $MAX_MOVES | ${YELLOW}Avg: $AVG${NC}"
}

check_checker_error_management() {
    echo -e "\n${BLUE}=== CHECKER ERROR MANAGEMENT ===${NC}"
    
    ERR_ARGS=( "pa\npb\na" "b c" "psa" "p a" "ss\nsa\nsb\nsa sb" "sa " " sa" "SA" "\n" "pa\n\npb" "rrra" "r" "sa\t")
    for MOVES in "${ERR_ARGS[@]}"; do
        OUT=$(printf "%b\n" "$MOVES" | $USER_CHECKER 1 2 3 2>&1)
        
        SAFE_MOVES="${MOVES//\\/\\\\}"
        
        if echo "$OUT" | grep -q "Error"; then
            echo -e "Read '${SAFE_MOVES}': ${GREEN}[OK]${NC}"
        else
            echo -e "Read '${SAFE_MOVES}': ${RED}[KO]${NC}"
            printf "INSTRUCTION TEST FAILED: Moves '%s' - Output: '%s'\n" "$MOVES" "$OUT" >> "$LOG_FILE"
        fi
    done
}

check_checker_leaks() {
    echo -e "\n${BLUE}=== CHECKER LEAK CHECK ===${NC}"
    rm -f valgrind_log.txt
    TIMEOUT_DETECTED=0

    ARG="1 2 3 1"
    run_valgrind_with_timeout "$USER_CHECKER" $ARG < /dev/null > /dev/null 2>> valgrind_log.txt
    STATUS=$?
    if [ $STATUS -eq 124 ]; then
        echo -e "Checker valgrind duplicate test: ${RED}[TIMEOUT]${NC}"
        printf "VALGRIND TIMEOUT: %s %s\n" "$USER_CHECKER" "$ARG" >> "$LOG_FILE"
        TIMEOUT_DETECTED=1
    fi
    
    ARG="a b c"
    run_valgrind_with_timeout "$USER_CHECKER" $ARG < /dev/null > /dev/null 2>> valgrind_log.txt
    STATUS=$?
    if [ $STATUS -eq 124 ]; then
        echo -e "Checker valgrind invalid args: ${RED}[TIMEOUT]${NC}"
        printf "VALGRIND TIMEOUT: %s %s\n" "$USER_CHECKER" "$ARG" >> "$LOG_FILE"
        TIMEOUT_DETECTED=1
    fi

    ARG="1 5 2 4"
    printf "sa\npb\nfake_move\n" | run_valgrind_with_timeout "$USER_CHECKER" $ARG > /dev/null 2>> valgrind_log.txt
    STATUS=$?
    if [ $STATUS -eq 124 ]; then
        echo -e "Checker valgrind bad moves: ${RED}[TIMEOUT]${NC}"
        printf "VALGRIND TIMEOUT: %s %s (with moves)\n" "$USER_CHECKER" "$ARG" >> "$LOG_FILE"
        TIMEOUT_DETECTED=1
    fi

    ARG=$(generate_arg 100)
    MOVES=$(run_push_swap_with_timeout "$ARG")
    STATUS=$?
    if [ $STATUS -eq 124 ]; then
        echo -e "Checker valgrind generator: ${RED}[TIMEOUT]${NC}"
        printf "TIMEOUT: %s %s (checker leak setup)\n" "$PUSH_SWAP" "$ARG" >> "$LOG_FILE"
        TIMEOUT_DETECTED=1
    else
        printf "%s" "$MOVES" | run_valgrind_with_timeout "$USER_CHECKER" $ARG > /dev/null 2>> valgrind_log.txt
        STATUS=$?
        if [ $STATUS -eq 124 ]; then
            echo -e "Checker valgrind replay: ${RED}[TIMEOUT]${NC}"
            printf "VALGRIND TIMEOUT: %s %s (replay moves)\n" "$USER_CHECKER" "$ARG" >> "$LOG_FILE"
            TIMEOUT_DETECTED=1
        fi
    fi

    if [ $TIMEOUT_DETECTED -eq 1 ]; then
        echo -e "${YELLOW}Some checker Valgrind runs timed out.${NC}"
    fi

    if grep -E -q "definitely lost: [1-9][0-9]* bytes|ERROR SUMMARY: [1-9][0-9]* errors" valgrind_log.txt; then
        echo -e "${RED}[LEAKS DETECTED]${NC}"
        echo "Check valgrind_log.txt for details."
    else
        echo -e "${GREEN}[CLEAN]${NC}"
        rm -f valgrind_log.txt
    fi
}

run_checker_loop() {
    QTY=$1
    RUNS=$2
    echo -e "\n${BLUE}=== CHECKER TEST $QTY NUMBERS ($RUNS run) ===${NC}"
    
    for ((i=1; i<=RUNS; i++)); do
        ARG=$(generate_arg $QTY)
        OUT=$(run_push_swap_with_timeout "$ARG" < /dev/null 2>&1)
        STATUS=$?

        if [ $STATUS -eq 124 ]; then
            echo -e "Run $i: ${RED}[TIMEOUT]${NC}"
            printf "TIMEOUT (CHECKER LOOP): %s\n" "$ARG" >> "$LOG_FILE"
            continue
        fi
        
        ORACLE_OUT=$(echo "$OUT" | $CHECKER $ARG 2>/dev/null)
        USER_OUT=$(echo "$OUT" | $USER_CHECKER $ARG 2>/dev/null)
        
        if [ "$ORACLE_OUT" == "$USER_OUT" ]; then
            echo -e "Run $i [OK TEST]: ${GREEN}PASSED${NC}"
        else
            echo -e "Run $i [OK TEST]: ${RED}NOT PASSED${NC}"
            printf "Run %s [OK TEST]: NUMBERS: %s\n USER_CHECKER: %s  REAL_CHECKER: %s\n" "$i" "$ARG" "$USER_OUT" "$ORACLE_OUT" >> "$LOG_FILE"
        fi
        
        if [ -z "$OUT" ]; then
            echo -e "Run $i [KO TEST]: ${YELLOW}SKIPPED (Already sorted)${NC}"
        else
            SABOTAGED_OUT=$(echo "$OUT" | sed '$d')
            ORACLE_OUT=$(echo "$SABOTAGED_OUT" | $CHECKER $ARG 2>/dev/null)
            USER_OUT=$(echo "$SABOTAGED_OUT" | $USER_CHECKER $ARG 2>/dev/null)
            
            if [ "$ORACLE_OUT" == "$USER_OUT" ]; then
                echo -e "Run $i [KO TEST]: ${GREEN}PASSED${NC}"
            else
                echo -e "Run $i [KO TEST]: ${RED}NOT PASSED${NC}"
                printf "Run %s [KO TEST]: NUMBERS: %s\n USER_CHECKER: %s  REAL_CHECKER: %s\n" "$i" "$ARG" "$USER_OUT" "$ORACLE_OUT" >> "$LOG_FILE"
            fi
        fi
    done
}

run_checker() {

    echo -e "${BLUE}Compiling User Checker...${NC}"
    make bonus -C "$SOURCE_PATH" > /dev/null

    if [ ! -f "$USER_CHECKER" ]; then
        echo -e "${RED}Error: Compilation failed or binary not found.${NC}"
        exit 1
    fi

    check_allowed_function
    check_checker_error_management
    run_checker_loop 3 5
    run_checker_loop 5 5
    run_checker_loop 100 5
    run_checker_loop 500 5
    check_checker_leaks
}

run_tester() {
    MODE=$1
    COUNT=${2:-20}

    if [ "$MODE" == "COMPLETE" ]; then
        check_allowed_function
        check_error_management
        run_test_loop 3 2 5
        run_test_loop 5 12 10
        run_test_loop 100 700 20
        run_test_loop 500 5500 50
        check_leaks
    elif [ "$MODE" == "100" ]; then
        check_allowed_function
        run_test_loop 100 700 $COUNT
    elif [ "$MODE" == "500" ]; then
        check_allowed_function
        run_test_loop 500 5500 $COUNT
    else
        check_allowed_function
        run_test_loop "$MODE" 100000000 $COUNT
    fi

    make fclean -C "$SOURCE_PATH" > /dev/null
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
elif [[ "$1" =~ ^[0-9]+$ && -z "$2" ]]; then
    run_tester "$1"
elif [[ "$1" =~ ^[0-9]+$ && -n "$2" ]]; then
    run_tester "$1" "$2"
elif [[ "$1" == "b" ]]; then
    run_checker
else
    echo -e "${YELLOW}Invalid arguments. Usage: ./launch.sh [num] [count]${RESET}"
fi

rm -f .empty_check

echo -e "\n${CYAN}=== DONE ===${RESET}"
