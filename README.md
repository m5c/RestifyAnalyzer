# RESTify Analyzer

Automated reliable testing of RESTify experiment submissions.

## About

This software is a tool written specifically for analysis of the data acquired throughout the RESTify experiment.

 * The RESTify experiment produced 28 participant submissions with two restful services each.  
 * A manual inspection is overly time intense and error prone.
 * This repository [hosts a bash script](analyze.sh) that automatically test all submissions and generates test reports in a reliable manner.

## Procedure

### Two Test Loops

 * In default configuration, the script preforms a single loop over all participant folders. Every iteration runs all unit tests for each of the two submitted applications.
 * If no additional parameters are provided, the script does not verify the effectiveness of write operations by means of a subsequent read operation. This is to reduce test cross dependencies between the individual REST API endpoints.
 * Using the ```-v``` flag, the tests can be hardened to only evaluate to positive, if state changes of write requests can be confirmed by subsequent read requests. See [Usage Section](#usage) 

 > Note: The scenario of a successful *Write*, and unsuccessful *Read* validation is very rare. It is recommended to investigate these cases manually, to exclude possibility of a false-positive *Write*.

### Full Backend State Reset

Every test is executed in perfect isolation, that is to say every individual unit test run is preceded by a complete restart of the application tested. This eliminates any effects that stem from blemished test results due to corrupted initial service state (e.g. caused by failed earlier test).

## Usage

### Script Dependencies

 * Install the ```realpath``` command: ```brew install coreutils```
 * Create a ```Code``` directory in your homedir, clone these four repositories:
     * ```git clone https://github.com/m5c/XoxStudyRestTest```
     * ```git clone https://github.com/m5c/BookStoreRestTest```
     * ```git clone https://github.com/m5c/BookStoreInternals --branch RestifyStudy --single-branch```
     * ```git clone https://github.com/m5c/XoxInternals --branch RestifyStudy --single-branch```
 * Locally install the Internals packages:
    * ```cd XoxInternals; mvn clean install; cd ..```
    * ```cd BookStoreInternals; mvn clean install; cd ..```


### Running the script

 * Download the participant code submissions.    
Note, there are several versions of the bundle: ```submission.zip```
     * ```00-uploads-untampered-sources-models-videos.zip```: Not published, contains code and screencasts that allow identification of participants.
     * ```01-uploads-untampered-sources-models.zip```: Not published, contains code and metadata that allow identification of participants.
     * [```02-uploads-anonymized-sources-models.zip```](02-uploads-anonymized-sources-models.zip): Published, contains anonymous code.  
MD5 Checksum: ```3d24150623c5c31e089618be3fecd608```
     * [```03-uploads-sanitized-sources-models.zip```](03-uploads-sanitized-sources-models.zip): Published, contains anonymous code where trivial mistakes have been fixed.  
MD5 Checksum: ```4e83acc9536fdc8d3e3b7afe21313fa5```
 * Unzip the downloaded zip file and extract it.  
Make sure the ```UPLOADDIR``` variable correctly references the submissions source codes.
 * Update the ```XOXTESTDIR``` and ```BSTESTDIR``` variables to match the location of your cloned [BookStore and Xox Rest Test applications](#script-dependencies).
 * Call: ```./analyze.sh```, wait for script to finish. (Takes about half an hour)  
Command line options:
   * ```-h```: Print help message with further usage information
   * ```-d```: Run in debug mode (print all intermediate results)
   * ```v```: Enable read verification for write operations.  only considered as successful, if the state change if the initial write operation is reflected in the read result. By default this option is disabled.
 This option is disabled by default.
   *  ```-u Colour-Animal```:  Reduce test scope to a single study submission. Name of the target participant code name must be provided, e.g. Pink-Snail
 * Inspect the test reports
   * CSV file for further scripted visualizations: *report-folder*/tests.csv  
This file is consumed as input data by the [RestifyJupyter](https://github.com/m5c/RestifyJupyter) project.
   * Human-readable markdown report: *report-folder*/report.md
 This file also contains hotlinks to relevant code snippets, in case a subsequent manual inspection is required.


## Development

Use IntelliJ IDEA, make sure to enable the [Shell Script](https://plugins.jetbrains.com/plugin/13122-shell-script) plugin.  
This provides automatic execution of the [Shell Check](https://www.shellcheck.net/) static code linter and enforces a minimum of code style and readability.

## Troubleshooting

 * Make sure the `UPLOADDIR` variable points to the participant submissions.
 * Make sure the JVM is set to a pre-16 version, for compatibility with the Spring-Framework version participants were using.
    * E.g. if using [SdkMan](https://sdkman.io/), use Coretto-11: `sdk install java 11.0.29-amzn`
 * Make sure BookStoreInternals and XoxInternals are installed with `mvn clean install`
    * git clone https://github.com/m5c/XoxInternals.git; cd XoxInternals; git checkout RestifyStudy; mvn clean install
    * git clone https://github.com/m5c/BookStoreInternals.git; cd BookStoreInternals; git checkout RestifyStudy; mvn clean install
 * Make sure the Unit test projects for Xox and BookStore are cloned and located at the expected location (`XOXTESTDIR` / `BSTESTDIR` variables):
   * `git clone https://github.com/m5c/XoxStudyRestTest`
   * `git clone https://github.com/m5c/BookStoreRestTest`
 * If your machine is slow, or has insufficient RAM, increase the REST-restart timer: `STARTUPGRACE` variable

## License

This software is under open source [MIT License](LICENSE.txt).

## Authors

* Principal Investigator: [Maximilian Schiedermeier](https://www.cs.mcgill.ca/~mschie3/)
* Academic Supervisors: [Bettina Kemme](https://www.cs.mcgill.ca/~kemme/), [Jörg Kienzle](https://www.cs.mcgill.ca/~joerg/Home/Jorgs_Home.html)
* Implementation: [Maximilian Schiedermeier](https://github.com/m5c)
   * Study Instructions, by control group:
      * [Red](https://www.cs.mcgill.ca/~mschie3/red/restify-study/)
      * [Green](https://www.cs.mcgill.ca/~mschie3/green/restify-study/)
      * [Blue](https://www.cs.mcgill.ca/~mschie3/blue/restify-study/)
      * [Yellow](https://www.cs.mcgill.ca/~mschie3/yellow/restify-study/)
   * Legacy Application Source Code:
      * [BookStore](https://github.com/m5c/BookStoreInternals/tree/RESTifyStudy)
      * [Zoo](https://github.com/m5c/Zoo/tree/RESTifyStudy)
      * [Xox](https://github.com/m5c/XoxInternals/tree/RESTifyStudy)
   * Submission REST unit test scenarios:
     * [BookStore REST Tests](https://github.com/m5c/BookStoreRestTest)
     * [Xox REST Tests](https://github.com/m5c/XoxStudyRestTest)
   * Jupyter Notebook for full study analysis and description: [RestifyJupyter](https://github.com/m5c/RestifyJupyter)
* Research Ethics Board Advisor: Lynda McNeil
