# Provisioner’s Toolbelt

Provisioner’s Toolbelt is a suite of data tools to support members of the Solution Architecture, Client Services, and Customer Success teams at Schoology as they manipulate and analyze client data.

## Architecture
Provisioner’s Toolbelt is built on the Django framework using the Python language.  It runs on a MySQL database.  The front end is built on Django templates and uses jQuery where necessary.  Data manipulation in the app makes use of the Pandas library.

## Apps

### Not documented here
* API Client
* Auth
* Client
* Doctor Prepper
* Validator

### API Job Runner
The Job Runner holds Python scripts that can be run at the click of a button with minimal configuration.  This app is meant to provide access, ease, and functionality not normally offered by the connected systems.

#### Usage
* After configuring a client and API credentials, a user can click into the API Job Runner app.  They will be presented with a list of jobs and a description of each job's purpose.  Clicking into a job will present the user with a configuration form with any required fields.  Clicking to execute the job will redirect the user to a log page that reads out logs from the executed job as it is run.

#### Components

* The job
   * The only real requirement for something to be a job is that it has an appropriately configured metadata object containing all required fields.  Most jobs interact with the Schoology API, but some connect to other systems.  Some connect to Schoology's Redshift analytics database to run SQL queries and extract client activity data.  Some connect to SFTP sites, or client-specific systems.  The sky is the limit!
* Job Library
   * A directory of Python scripts within the Provisioner's Toolbelt project that each contain metadata about themselves.  When the Jobs page loads Django scans the directory for jobs, and uses the metadata to populate names and descriptions for each job the user has access to. There are ~25 jobs in total.
* Job Configuration Page
   * When a user clicks into a job, they are directed to a page with a form generated based on the metadata in the selected job.  They will fill in the form and hit `Execute`.
* The `api_job_start` view
   * When a user clicks `Execute`, the `api_job_start` Django view creates a record in the database with the configured options.  The view then opens a subprocess for The Executioner, passing in the job ID.  Django does not follow what The Executioner does, and redirects the user to a logs page.
* The Executioner
   * This process opens the database and retrieves its record for the job it was told to execute.  It will log that it has started and begin executing its own subprocess to run the selected job.  Unlike Django, Executioner will pay attention to STDOUT and STDERR, piping this data into the database for the user to read on their log page.

#### A sample job, and the Schoology API Library

Let's talk about the job `Update parent buildings to child buildings`.  The purpose of the job is to stream through all users in a client instance and update parent buildings according to whatever buildings their children have.

Here's the meat and potatoes of the job's execution:

```
api.etl(
    streamIn=api.asyncGetPaged,
    streamOut=api.bulkProcessFromList,

    filters=[keepParents],
    transforms=[updateByChildBuildings],

    streamInParams={'location': 'users'},
    streamOutParams={'location': 'users', 'method': api.genericPut},

    filterParams=None,
    transParams=[{
        'api': api,
        'behavior': behavior,
        'allowed_buildings': allowed_buildings
    }]
)
```

The `api` object is an instance of the `SchoologyAPI` class that already holds the client credentials.  The `etl` method takes a number of parameters.
* `streamIn` designates a streaming data source, and receives a method.
* `streamInParams` represents the parameters to be passed to the `api.asyncGetPaged` method when it is called inside the `etl` method.
* `streamOut` designates a data stream destination.
* Similarly to the input stream, `streamOutParams` represents parameters to be passed to the `api.buildProcessFromList` method when it is called in the `etl` method
* Between the stream in and stream out, `filters` and `transforms` are arrays of methods to filter and transform the data stream.
* Just as above, `filterParams` and `transParams` pass parameters to the methods passed into `filters` and `transformations`

On the whole, it is a single ETL node with very robust data manipulation functionality, and it is capable of handling large amounts of data since it doesn't hold much in memory.

## What worked well
The Executioner and the SchoologyAPI library were fantastic!  The Executioner allowed script execution to be decoupled from Django, while still allowing interaction through the web app.  The SchoologyAPI library was created at first with very simple API methods, but eventually evolved to be an ETL library based around the Schoology API.  Very cool!

## What didn't work
There were other apps not detailed here that didn't end up working.  The biggest issue I see looking through this codebase is a lack of organization and readability in some of the larger class files.

## Future applications
Reusability is key!  Being able to create abstracted `etl` methods allowed a good many jobs to be written simply and effectively.