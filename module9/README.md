# Module 9 Project: Advanced Libraries
---
**Author**: Chris Walsh

**Course**: EN.605.617

**Date**: November 01, 2026

---

### Project Description

This project uses cuRAND and Thrust to calculate statistics about the performance of a theoretical portfolio of assets. A portfolio has a total initial value, the weight of each asset in the portfolio, the median return of each asset each day, and the variance of returns each day. Using those statistics as a base, cuRAND is used to generate random scenarios with each scenario running on one thread. The result of each thread is a calculated portfolio value given gains or losses from each asset over a number of days. To summarize the random results, Thrust is then used to calculate statistics like mean, median, standard deviation, value at risk, and probability of loss. Each of these statistics requires some different use of various thrust functions.

### Building and running

The assignment is configured to work with both `make` and with `build.sh` and `run.sh` run via `run_assignments.sh` from this project's root.

* Option 1: make script:
    * run the command `make` from the `module9` folder
    * run the command ./assignment.exe to run the app
    * optional command line arguments are `numScenarios`, `blockSize` (e.g. `./assignment.exe 1024 256`)
* Option 2: `run_assignments.sh`
    * run `./run_assignments.sh` from the root of the project
