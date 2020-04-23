CREATE DATABASE UCalender;
/*
    Enumeration indicating the type of event as a field in event entries
    DEFAULT = 0
    COURSE = 1
    DISCUSSION = 2
    OH = 3
    EXAM = 4
    DEADLINE = 5
    MEETING = 6
    MEETING_TENTATIVE = 7
    Enumeration indicating the frequency of event as a field in event entries 
    DEFAULT = 0
    DAILY = 1
    WEEKLY = 2
    MONTHLY = 3
*/

/*
The user table contains the following columns:
id | username | email | password_hash | is_instructor
*/

CREATE TABLE Users (
    id INTEGER PRIMARY KEY, 
    username TEXT NOT NULL, 
    email TEXT NOT NULL UNIQUE, 
    password_hash TEXT, 
    is_instructor INTEGER
);

/*
The event table contains the following columns:
id | event_name | startdate | starttime | event_location | eventType |
endtime | enddate | frequencyType | description | course
A course type event should has the course field as the name of itself
*/

CREATE TABLE Events (
    event_id INTEGER PRIMARY KEY, 
    event_name TEXT NOT NULL, 
    startdate TEXT NOT NULL,
    starttime TEXT NOT NULL,
    event_location TEXT,
    eventType INTEGER,
    enddate TEXT NOT NULL,
    endtime TEXT NOT NULL,
    frequencyType INTEGER,
    event_description TEXT,
    course TEXT
);

/*
The participation table indicates the relationship between
an event and a user, and contains the following columns:
event_id | user_id
*/

CREATE TABLE Participation (
    event_id INTEGER, 
    user_id INTEGER, 
    PRIMARY KEY (event_id, user_id),
    FOREIGN KEY (event_id) 
    REFERENCES Event (event_id) 
    ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (user_id) 
    REFERENCES Users (user_id) 
    ON DELETE CASCADE ON UPDATE CASCADE
);

/*
def add_user(self, user_json):
    Takes in a json-converted dict including 4 fields about a user:
    username: string, email: string,
    password: string, is_instructor: string
    Returns True when the user with the same username or email does not
    exist in database and a new user is created.
    Returns False otherwise.
*/

DECLARE @JSON VARCHAR(MAX);

SELECT @JSON = BulkColumn
FROM OPENROWSET (BULK '/data/users.json', SINGLE_CLOB) as j;

SELECT username, email, password_user, is_instructor, FLOOR(RAND()*(5000+1)) AS user_id
INTO Users
  FROM OPENJSON (@JSON)
  WITH (username INTEGER, 
    email TEXT(100), 
    password_user TEXT,
    is_instructor INTEGER)
WHERE ISJSON(@JSON) = 1
AND username IS NOT NULL;

/*
@login_required
def edit_user(self, user_json):
    Takes in a json-converted dict including 4 fields about a user:
    username: string, email: string,
    password: string, is_instructor: string
    Updates existing user info in the database.
*/

SELECT @JSON = BulkColumn
FROM OPENROWSET (BULK '/data/edit_users.json', SINGLE_CLOB) AS j;

UPDATE Users
SET username = JSON_VALUE(@JSON,'$.username'), 
password_hash = JSON_VALUE(@JSON,'$.password_user'),
email = JSON_VALUE(@JSON,'$.email'),
is_instructor = JSON_VALUE(@JSON,'$.is_instructor')
WHERE ISJSON(@JSON) = 1
AND user_id = JSON_VALUE(@JSON,'$.user_id');

/* 
def read_event(self, event_json):
    '''
    Takes in a json-converted dict including 8 fields about an event:
    name: string, startdate: string, starttime: string, location: string,
    type: string, enddate: string, endtime: string, description: string
    Returns an Event object initiated with the above information
    '''
*/

SELECT @JSON = BulkColumn
FROM OPENROWSET (BULK '/data/read_event.json', SINGLE_CLOB) AS j;

SELECT FLOOR(RAND()*(5000+1)) AS event_id, event_name, startdate, starttime, event_location, eventType, enddate, endtime, frequencyType, course
INTO Events
  FROM OPENJSON (@JSON)
  WITH (event_id INTEGER, 
    event_name TEXT, 
    startdate TEXT,
    starttime TEXT,
    event_location TEXT,
    eventType INTEGER,
    enddate TEXT,
    endtime TEXT,
    frequencyType INTEGER,
    course TEXT AS JSON)
WHERE ISJSON(@JSON) = 1;

/* def getUsersWithEmail(self, guests) */

SELECT @JSON = BulkColumn
FROM OPENROWSET (BULK '/data/get_users_email.json', SINGLE_CLOB) AS j;

SELECT user_id 
FROM Users
WHERE ISJSON(@JSON) = 1
AND email = JSON_VALUE(@JSON,'$.email');

/* def getUsersWithCourse(self, course) */

SELECT @JSON = BulkColumn
FROM OPENROWSET (BULK '/data/get_users_course.json', SINGLE_CLOB) AS j;

DECLARE @course TEXT(MAX);

SELECT @course = event_id 
FROM Events
WHERE ISJSON(@JSON) = 1
AND event_name = JSON_VALUE(@JSON,'$.course_name');

SELECT user_id
FROM Participation
WHERE ISJSON(@JSON) = 1
AND event_id = @course;

/*
def delete_event_from_database(self, eventID):
    '''
    Takes in the event id of the event and deletes the event.
    No return value.
    '''
*/

SELECT @JSON = BulkColumn
FROM OPENROWSET (BULK '/data/delete_event.json', SINGLE_CLOB) AS j;

DECLARE @related_users INTEGER(MAX);

SELECT @related_users = COUNT(*)
FROM Participation
WHERE ISJSON(@JSON) = 1
AND event_id = JSON_VALUE(@JSON,'$.id');

DELETE FROM Events 
WHERE ISJSON(@JSON) = 1
AND event_id = JSON_VALUE(@JSON,'$.id');

/*
def edit_event_in_database(self, eventID, changes_json):
    '''
    Takes in the event id of the event and a json-converted dict same as
    the argument of add_event_to_database containing the updated info
    No return value.
    '''
*/

SELECT @JSON = BulkColumn
FROM OPENROWSET (BULK '/data/edit_event.json', SINGLE_CLOB) AS j;

UPDATE Events
SET 
event_name = JSON_VALUE(@JSON,'$.event_name'), 
eventType = JSON_VALUE(@JSON,'$.eventType'),
frequencyType = JSON_VALUE(@JSON,'$.frequencyType'),
event_description = JSON_VALUE(@JSON,'$.event_description')
WHERE ISJSON(@JSON) = 1
AND event_id = JSON_VALUE(@JSON,'$.event_id');

/*
def get_event_by_id(self, eventID):
    target = Event.query.get(eventID)
    return target
*/

SELECT @JSON = BulkColumn
FROM OPENROWSET (BULK '/data/get_event_by_id.json', SINGLE_CLOB) AS j;

SELECT * FROM Events
WHERE ISJSON(@JSON) = 1
AND event_id = JSON_VALUE(@JSON,'$.id')
FOR JSON PATH;

/*
def get_events_by_user_and_date(self, req_json):
    '''
    Takes in a json-converted dict containing the userid and date
    requested. Return the list of events satisfying the condition.
    '''
*/

SELECT @JSON = BulkColumn
FROM OPENROWSET (BULK '/data/get_events_by_user_and_date.json', SINGLE_CLOB) AS j;

SELECT Events.event_id
    FROM Events INNER JOIN Participation 
    ON Participation.event_id=Events.event_id
WHERE Participation.user_id=JSON_VALUE(@json,'$.user_id')
AND Events.startdate=JSON_VALUE(@json,'$.date');

/*
def get_events_by_type(self, event_type):
    '''
    Takes in a event_type(int).
    Return a list of events of this type
    '''
*/

SELECT @JSON = BulkColumn
FROM OPENROWSET (BULK '/data/get_events_by_type.json', SINGLE_CLOB) AS j;

SELECT event_id
FROM Events
WHERE ISJSON(@JSON) = 1
AND event_type = JSON_VALUE(@JSON, '$.type');

/*
def get_students(self, course_name):
    '''
    Takes in the course name string.
    Return a list of student ids enrolled in the course.
    '''
*/

SELECT @JSON = BulkColumn
FROM OPENROWSET (BULK '/data/get_students.json', SINGLE_CLOB) AS j;

SELECT Participation.user_id
    FROM Events
    JOIN Participation ON Participation.event_id=Events.event_id
WHERE Events.event_name=JSON_VALUE(@json,'$.user_name');