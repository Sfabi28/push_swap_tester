# push_swap Tester

A comprehensive and strict tester for the 42 **push_swap** project. It supports both Mandatory and Bonus parts, includes memory leak detection via Valgrind, and generates detailed logs for debugging.

## 📁 1. Installation

Ensure that the folder of this tester (`push_swap_tester`) is located **INSIDE** the root of your `push_swap` project.

**Correct Directory Structure:**
```text
/push_swap_root
    ├── Makefile
    ├── push_swap.h
    ├── *.c (your source files)
    └── push_swap_tester/       <--- YOU ARE HERE
          ├── launch.sh
          └── checker

```

**Important:** To avoid accidentally committing the tester to your repository, add `push_swap_tester/` to your `.gitignore` file:

```bash
echo "push_swap_tester/" >> .gitignore
```

Ensure that the path is right and set a proper timeout time **INSIDE** the `launch.sh` file

## 🚀 2. First Run


Before running the tester for the first time, you must grant execution permissions to the main script:

```bash
chmod +x launch.sh
```

## ⚙️ 3. Usage Commands
-----------------
The tester supports different modes.

```text
Command,Description
./launch.sh ,Runs ALL tests (Mandatory + Valgrind).
./launch.sh [100|500] ,Runs 100 tests on 100 or 500 numbers.
./launch.sh [100|500] + n, Runs n tests on 100 or 500 numbers. 
```

## 📊 4. Results Legend
-----------------
```text
[OK]   : The output list is in order.
[KO]   : The output list is not in order.

Min: 3800 | Max: 4431 | Avg: 3956

```

Happy debugging!🖥️