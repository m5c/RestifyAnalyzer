#! /bin/bash
## RESTify upload analyzer
## Produces unit test reports for all participants, ready for export
## Maximilian Schiedermeier, 2023

## Location of the folder with all studiy submissions. The content of this folder should be an extra
## folder per study participant, each containing the two submissions.
UPLOADDIR=/Users/schieder/Desktop/03-uploads-sanitized-sources-models

## Grace period in seconds the programm will stall after every backend power up. Backend needs some
# seconds before it can be tested. The number must be high enough to ensure the backend is fully
# running. Higher number slows down the total time to run the test suite. Value can be set lower
# on systems with a faster CPU.
STARTUPGRACE=6

## Variable used to ensure the command line returns where it was called from after script exectuion
BASEDIR=$(pwd)

## Target name for the markdown report to create. The report contains success statistics and links
## to extracted code fragments for every analyzed submission.
REPORT=report.md

## Target name for the machine readable test report. This file is intended for interpretation by the
## RestifyJupyter visualization project: https://github.com/m5c/RestifyJupyter
CSVREPORT=tests.csv

## Reference to the cloned sources of the Xox REST unit tests.
## Origin: https://github.com/m5c/XoxStudyRestTest
XOXTESTDIR=/Users/schieder/Code/XoxStudyRestTest

## Reference to the cloned sources of the BookStore REST unit tests.
## Origin: https://github.com/m5c/BookStoreRestTest
BSTESTDIR=/Users/schieder/Code/BookStoreRestTest

## Indicate how many lines of code to contain in the produced textual report after every detected spring annotation
ANNOTATION_LINE_BUFFER=4

function getCodeName {
  GROUP=$(echo "$1" | cut -d '-' -f1)
  ANIMAL=$(echo "$1" | cut -d '-' -f2)
  CODENAME=$GROUP-$ANIMAL
}

## Generates a markdown anchor in the markdown report that links from the document top participant
# name to the section with test result details for the given participant.
function generateHotlink {
  getCodeName "$1"
  LC_CODENAME=$(echo "$CODENAME" | tr '[:upper:]' '[:lower:]')
  echo " * [$CODENAME](#$LC_CODENAME)" >>"$BASEDIR/$REPORT"
}

## Analyzes the last three characters of a provided string and inferes the corresponding CRUD http method.
function extractMethod {
  METHOD=$(echo "$1" | rev | cut -c -3 | rev)
  if [ "$METHOD" = "ost" ]; then
    METHOD="Post"
  fi
  if [ "$METHOD" = "ete" ]; then
    METHOD="Del"
  fi
  METHOD='['$METHOD']'
  METHOD=$(printf '%-6s' "$METHOD")
}

## Helper function to reduce a provided endpoint string to the effective REST resource location.
# Result is stored in a new RESROUCE variable.
function extractResource {
  RESOURCE=$(echo "$1" | sed s/Get// | sed s/Put// | sed s/Post// | sed s/Delete//)
  RESOURCE=$(echo "$RESOURCE" | cut -d "#" -f 2)
  RESOURCE=$(echo "$RESOURCE" | sed s/test// | sed -r -e "s/([^A-Z])([A-Z])/\1\/\2/g")
  RESOURCE=$(echo "$RESOURCE" | tr '[:upper:]' '[:lower:]')
  RESOURCE="/$2/$RESOURCE"
  RESOURCE=$(printf '%-48s' "$RESOURCE")
}

## Tests one specific endpoint by calling the corresponding unit tests. The unit test may or may
# not verify write operations by subsequent read operations, depending on how the application
# tester is configured / launch parameter provided.
# The test result is afterwards appended to the markdown and CSV report.
function testEndpoint {
  # TODO: investigate if there is prettier way to eliminate the $VERIF variable if it is empty.
  if [ -z "$VERIF" ]; then
    RESULT=$(mvn -Dtest="$1" test | grep ', Time' | cut -d ":" -f 6)
  else
    RESULT=$(mvn -Dtest="$1" test "$VERIF" | grep ', Time' | cut -d ":" -f 6)
  fi

  extractMethod "$1"
  extractResource "$1" "$2"

  # append line for markdown report into temporary file
  echo "$METHOD $RESOURCE $RESULT" >>"$BASEDIR/$REPORT-tmp"

  # append string for CSV report into temporary file
  if [[ "$RESULT" == *"FAILURE"* ]]; then
    echo -n ",FAIL" >>"$BASEDIR/$CSVREPORT-indiv"
  else
    echo -n ",PASS" >>"$BASEDIR/$CSVREPORT-indiv"
  fi
}

## Kills the process running on port 8080, if there is one.
function killApp8080 {

  # Get ID of process running on 8080, if there is one
  PID=$(lsof -ti:8080)

  # If there is a service running, kill it
  if [[ -n "$PID" ]]; then
    kill "$PID"
  fi
}

function restartBackend {

  # Make sure no other programs are blocking the port / kill any instance of running java backends.
  killApp8080
  # Power up the backend
  java -jar "$JARFILE" &
  # Wait a grace period for the backend to be ready for testing
  sleep $STARTUPGRACE

}

## Staged sequential test for all REST endpoints of the Xox applicaion.
# Calling this method is different from a direct run of the test repository, because standard java
# unit tests do not enforce a test order.
function testXox {

  # test all xox endpoints
  cd $XOXTESTDIR || exit
  echo "\`\`\`" >"$BASEDIR/$REPORT-tmp"
  testEndpoint XoxTest#testXoxGet xox
  restartBackend
  testEndpoint XoxTest#testXoxPost xox
  restartBackend
  testEndpoint XoxTest#testXoxIdGet xox
  restartBackend
  testEndpoint XoxTest#testXoxIdDelete xox
  restartBackend
  testEndpoint XoxTest#testXoxIdBoardGet xox
  restartBackend
  testEndpoint XoxTest#testXoxIdPlayersGet xox
  restartBackend
  testEndpoint XoxTest#testXoxIdPlayersIdActionsGet xox
  restartBackend
  testEndpoint XoxTest#testXoxIdPlayersIdActionsActionPost xox
  echo "\`\`\`" >>"$BASEDIR/$REPORT-tmp"
  cd - || exit
}

## Staged sequential test for all REST endpoints of the BookStore applicaion.
# Calling this method is different from a direct run of the test repository, because standard java
# unit tests do not enforce a test order.
function testBookStore {
  # reset test reports
  rm "$BASEDIR/$REPORT-indiv"
  rm "$BASEDIR/$REPORT-tmp"

  # test all bookstore endpoints
  cd $BSTESTDIR || exit
  echo "\`\`\`" >"$BASEDIR/$REPORT-tmp"
  testEndpoint AssortmentTest#testIsbnsGet bookstore
  restartBackend
  testEndpoint AssortmentTest#testIsbnsIsbnGet bookstore
  restartBackend
  testEndpoint AssortmentTest#testIsbnsIsbnPut bookstore
  restartBackend
  testEndpoint StockLocationsTest#testStocklocationsGet bookstore
  restartBackend
  testEndpoint StockLocationsTest#testStocklocationsStocklocationGet bookstore
  restartBackend
  testEndpoint StockLocationsTest#testStocklocationsStocklocationIsbnsGet bookstore
  restartBackend
  testEndpoint StockLocationsTest#testStocklocationsStocklocationIsbnsPost bookstore
  restartBackend
  testEndpoint CommentsTest#testIsbnsIsbnCommentsGet bookstore
  restartBackend
  testEndpoint CommentsTest#testIsbnsIsbnCommentsPost bookstore
  restartBackend
  testEndpoint CommentsTest#testIsbnsIsbnCommentsDelete bookstore
  restartBackend
  testEndpoint CommentsTest#testIsbnsIsbnCommentsCommentPost bookstore
  restartBackend
  testEndpoint CommentsTest#testIsbnsIsbnCommentsCommentDelete bookstore
  echo "\`\`\`" >>"$BASEDIR/$REPORT-tmp"
  cd - || exit
}

## Inspects the most recent report swap file and computes the success ratio as a number. Result is
# stored in a new variable "RATIO"
function computeSuccessRatio {
  TOTAL=$(grep -v \` "$BASEDIR/$REPORT-tmp" -c)
  SUCCESS=$(grep -v \` "$BASEDIR/$REPORT-tmp" | grep -v FAILURE -c)
  RATIO="$SUCCESS/$TOTAL"
}

## Inspects a single application submission. The procedure is: 1) Reset result vector 2) Power up
# backend application to test 3) Run all unit tests, with intermediate backend restarts
# 4) Append test results to report.
function analyzeCode {
  # Determine which app was actually tested
  # Set default outcome for test report to nothing passed:
  if [[ "$1" == *"Xox"* ]]; then
    APP="xox"
    echo -n ",FAIL,FAIL,FAIL,FAIL,FAIL,FAIL,FAIL,FAIL" >"$BASEDIR/X-$CSVREPORT"
    echo "Stored default fail vector in $BASEDIR/$APP-$CSVREPORT"
  elif [[ "$1" == *"BookStore"* ]]; then
    APP="bookstore"
    echo -n ",FAIL,FAIL,FAIL,FAIL,FAIL,FAIL,FAIL,FAIL,FAIL,FAIL,FAIL,FAIL" >"$BASEDIR/B-$CSVREPORT"
    echo "Stored default fail vector in $BASEDIR/$APP-$CSVREPORT"
  else
    echo "Unknown app: $1"
    exit 255
  fi

  # Verify upload exists
  if [ ! -d "$CODENAME-File-Upload/$1" ]; then
    echo "Upload not found, skipping"
    echo " * Manual: MISSING" >>"$BASEDIR/$REPORT"

  else

    # Access the upload location
    cd "$CODENAME-File-Upload/$1" || exit

    # Store all detected spring mappings in a dedicated file
    grep -nre @ src -A $ANNOTATION_LINE_BUFFER | grep Mapping -A $ANNOTATION_LINE_BUFFER >"$BASEDIR/$CODENAME-$2.txt"

    ## Try to compile, skip all tests (some users did not delete them)
    mvn -q clean package -Dmaven.test.skip=true >/tmp/output 2>&1
    COMPILABLE=$?

    ## if it did not compile, mark as uncompilable and proceed to next
    if [ ! "$COMPILABLE" == 0 ]; then
      # Not compilable. Flag and proceed
      echo " * [$2: NOT COMPILABLE]($CODENAME-$2.txt)" >>"$BASEDIR/$REPORT"
      echo -n "NC,0" >>"$BASEDIR/$CSVREPORT"
    else
      # Compilable, lets try to actually run and test it
      JARFILE=$(find . | grep jar | grep -v javadoc | grep -v sources | grep -v original | grep -v xml)
      # Convert idnetified jarfile to absolute path, so the backend cna be restarted even if we
      # change location.
      JARFILE=$(realpath "$JARFILE")
      echo "$JARFILE"

      # First time power up of backend
      restartBackend

      # check if the program is still running (still a running java process). If not that means it crashed...
      ALIVE=$(pgrep java)

      # if alive not empty, it is still running
      if [ -z "$ALIVE" ]; then
        echo " * [$2: NOT RUNNABLE]($CODENAME-$2.txt)" >>"$BASEDIR/$REPORT"
        echo -n "NR,0" >>"$BASEDIR/$CSVREPORT"
      else

        ## Program is running, let's test the individual endpoints (depending on what it is)
        APP=$(echo "$1" | cut -c -1)
        if [ "$APP" = "X" ]; then
          testXox
        else
          testBookStore
        fi
        computeSuccessRatio
        echo " * [$2: RUNNABLE, Tests passed: $RATIO]($CODENAME-$2.txt)" >>"$BASEDIR/$REPORT"
        echo -n "OK,${RATIO// /}" >>"$BASEDIR/$CSVREPORT"
        cat "$BASEDIR/$REPORT-tmp" >>"$BASEDIR/$REPORT"

        # rename CSV file with individual tests according to tested app
        mv "$BASEDIR/$CSVREPORT-indiv" "$BASEDIR/$APP-$CSVREPORT"
      fi

      # kill running program, pass on
      pkill -9 java

    fi

    cd - || exit
  fi
}

function prepareCsv {
  echo "codename,assistedstatus,assistedsuccessrate,manualstatus,manualsuccessrate,GET/xox,POST/xox,GET/xox/id,DEL/xox/id,GET/xox/id/board,GET/xox/id/players,GET/xox/id/players/id/actions,POST/xox/id/players/id/actions/actionid,GET/bookstore/isbns,GET/bookstore/isbns/isbn,PUT/bookstore/isbns/isbn,GET/bookstore/stocklocations,GET/bookstore/stocklocations/stocklocation,GET/bookstore/stocklocations/stocklocation/isbns,POST/bookstore/stocklocations/stocklocation/isbns,GET/bookstore/isbns/isbn/comments,POST/bookstore/isbns/isbn/comments,DEL/bookstore/isbns/isbn/comments,POST/bookstore/isbns/isbn/comments/comment,DEL/bookstore/isbns/isbn/comments/comment" >$CSVREPORT
}

function analyzeBothCodes {

  # Red Manual: Xox
  # Green Manual: BookStore
  # Blue Manual: BookStore
  # Yellow Manual: Xox
  case $GROUP in

  Red)
    MANUAL=XoxInternals
    ASSISTED=BookStoreModel/generated-maven-project
    ;;

  Green)
    MANUAL=BookStoreInternals
    ASSISTED=XoxModel/generated-maven-project
    ;;

  Blue)
    MANUAL=BookStoreInternals
    ASSISTED=XoxModel/generated-maven-project
    ;;

  Yellow)
    MANUAL=XoxInternals
    ASSISTED=BookStoreModel/generated-maven-project
    ;;

  esac

  # Test the assisted restified app
  cd $UPLOADDIR || exit
  echo "   * Testing $ASSISTED "
  analyzeCode $ASSISTED Assisted
  echo -n ',' >>"$BASEDIR/$CSVREPORT"

  # Test the manually restified app
  cd $UPLOADDIR || exit
  echo "   * Testing $MANUAL "
  analyzeCode $MANUAL Manual

  # Add individual test reports to CSV
  {
    cat "$BASEDIR/X-$CSVREPORT"
    cat "$BASEDIR/B-$CSVREPORT"
  } >>"$BASEDIR/$CSVREPORT"

  # Append newline, prepare for next submission test
  echo '' >>"$BASEDIR/$CSVREPORT"
}

function analyzeUpload {
  getCodeName "$1"
  echo " > Analyzing $CODENAME"
  cd "$BASEDIR" || exit
  echo "" >>$REPORT
  echo "## $CODENAME" >>"$REPORT"
  echo "" >>"$REPORT"

  ## write codename into CSV target file
  echo -n "$CODENAME" >>"$BASEDIR/$CSVREPORT"
  echo -n ',' >>"$BASEDIR/$CSVREPORT"

  ## Analyze the manual submission
  analyzeBothCodes
}

function createResultDir {
  ## Create target folder for this test run, to preven overwriting by subsequent run
  DATESTRING=$(gdate "+%Y-%m-%d--%Hh%Mm%Ss")
  if [ -z "$VERIF" ]; then
    VERIFSTRING="no-state-checks"
  else
    VERIFSTRING="with-state-checks"
  fi
  if [ -z "$SINGLEMODE" ]; then
    SINGLEMODE="all-submissions"
  fi
  RESULT_DIR=testreport--$DATESTRING--$VERIFSTRING--$SINGLEMODE
  mkdir "$RESULT_DIR"
}

function clearTempFiles {
  rm -f ./*txt
  rm -f ./*csv
  rm -f report*
  rm -f report.md-tmp
  rm -f X-*
  rm -f B-*
  rm -f tests.csv-indiv
  rm -f Red-*
  rm -f Green-*
  rm -f Blue-*
  rm -f Yellow-*
}

# Function to print help message
function usage {
  echo "RESTify Analyzer Script"
  echo "This software performs an automatic run of unit tests for RESTified versions of the BookStore and Xox software samples."
  echo "Usage: ./analyze [-hdvu::][Colour-Animal]"
  echo "-h => print this help message"
  echo "-d => enable debug mode where all intermediate results are printed"
  echo "-u Colour-Animal => Reduce test scope to one participant. Code name must be provided in colour-animal format, e.g. Pink-Snail"
  echo "-v => enable verfication of write operations with subsequent read probes. A test is only considered as successful, if the state change if the initial write operation is reflected in the read result. By default this option is disabled."
  echo "https://github.com/m5c/RestifyAnalyzer"
  echo "(c) M.Schiedermeier, Université du Québec à Montréal 2025"
}

## Main logic
## Reject any input that uses an argument 1 not starting with "-"
if [ -n "$1" ]; then
  FIRSTCHAR=$(echo $1 | cut -c 1-1)
  if [ "$FIRSTCHAR" = "-" ]; then
    # Cannot figure out a reliable way to negate char comparison. TODO: reduce to else
    echo -n ""
  else
    echo "Error: First argument must be a switch starting with \"-\""
    exit 255
  fi
fi
## Parse command line options
VERIF=""
while getopts "dhvu::" ARG; do
  case $ARG in
  d) # Enable debug mode
    echo "Debug mode enabled"
    set -x
    ;;
  v) # Specify v value.
    echo "Read Verfication Enabled!"
    VERIF="-Dreadverif=true"
    ;;
  u) # Specify strength, either 45 or 90.
    ## If argument is provided, this is interpreted as request to run in single user mode.
    # That is to say instead of iterating over all users, the progrem analyses the matchign submission.
    # Participant name must be spelled exactly as correpsonding participant name, e.g. "Blue-Fox"
    SINGLEMODE="${OPTARG}"
    echo "Single user mode enabled."
    ;;
  h | *) # Display help.
    usage
    exit 0
    ;;
  esac
done

## Clear files of previous iterations
clearTempFiles

## Make sure target report file exists and is empty
ORIGIN=$(pwd)
echo "# RESTify Study - Unit Test Report" >$REPORT
prepareCsv

## Remove the readme file, if it is still trailing
cd $UPLOADDIR || exit
rm -f README.md

## If running in single-run / debug mode: Only test target user. Otherwise test all submissions.
if [[ -n "$SINGLEMODE" ]]; then
  # Verify the provided username exists
  if [[ ! -d "$SINGLEMODE-File-Upload" ]]; then
    echo "Cannot run single mode. No such submission: $SINGLEMODE-File-Upload"
    exit 255
  fi

  echo "Single Mode detected. Only testing submission for $SINGLEMODE"
  ## Generate report for target user
  generateHotlink "$SINGLEMODE"
  ## Test target user only
  analyzeUpload "$SINGLEMODE"
else
  echo "Analyzing all submissions: "
  ## Generate report template for all users
  for i in [A-Z]*; do generateHotlink "$i"; done
  ## Run the actual analysis
  for i in [A-Z]*; do analyzeUpload "$i"; done
fi

## Create result dir and remember name in RESULTDIR variable
cd "$ORIGIN" || exit
createResultDir
# Save actual report files in target directory
mv report.md "$RESULT_DIR"
mv tests.csv "$RESULT_DIR"
mv Red-* "$RESULT_DIR"
mv Green-* "$RESULT_DIR"
mv Blue-* "$RESULT_DIR"
mv Yellow-* "$RESULT_DIR"

# Clear temp files
clearTempFiles
echo "Done! All results stored in $RESULT_DIR"

# Reset debug option, just in case
set +x
