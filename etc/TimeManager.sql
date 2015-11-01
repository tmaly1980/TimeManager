DROP TABLE IF EXISTS users;
CREATE TABLE IF NOT EXISTS users
(
  uid INTEGER UNSIGNED NOT NULL PRIMARY KEY,
  username VARCHAR(10) NOT NULL,
  password VARCHAR(16),
  email VARCHAR(50),
  fullname VARCHAR(30),
  siteadmin BOOL,
  title VARCHAR(50),
  power_user BOOL DEFAULT 0,
  hoursperweek FLOAT UNSIGNED
);

INSERT INTO users SET uid=0, username='admin', password='admin', email='admin@malysoft.com', fullname='Administrator', title='Site Administrator',siteadmin=1;

DROP TABLE IF EXISTS usersession;
CREATE TABLE IF NOT EXISTS usersession
(
  usersession_id INTEGER UNSIGNED NOT NULL PRIMARY KEY,
  uid INTEGER UNSIGNED NOT NULL,
  session_id VARCHAR(64) NOT NULL,
  date datetime,
  unique (uid, session_id)
);

DROP TABLE IF EXISTS shortcuts;
CREATE TABLE IF NOT EXISTS shortcuts
(
  shid INTEGER UNSIGNED NOT NULL PRIMARY KEY,
  uid INTEGER UNSIGNED NOT NULL,
  name VARCHAR(30) NOT NULL,
  shurl VARCHAR(200) NOT NULL,
  UNIQUE (name, uid)
);

DROP TABLE IF EXISTS groups;
CREATE TABLE IF NOT EXISTS groups
(
  gid INTEGER UNSIGNED NOT NULL PRIMARY KEY,
  name VARCHAR(40) NOT NULL,
  manager_uid INTEGER UNSIGNED
);

DROP TABLE IF EXISTS group_members;
CREATE TABLE IF NOT EXISTS group_members
(
  membership_id INTEGER UNSIGNED NOT NULL PRIMARY KEY,
  gid INTEGER UNSIGNED NOT NULL,
  uid INTEGER UNSIGNED NOT NULL,
  UNIQUE (gid, uid)
);

DROP TABLE IF EXISTS user_managers;
CREATE TABLE IF NOT EXISTS user_managers
(
  UID INTEGER UNSIGNED NOT NULL,
  MANAGER_UID INTEGER UNSIGNED NOT NULL,
  UNIQUE (UID, MANAGER_UID)
);

DROP TABLE IF EXISTS participants;
CREATE TABLE IF NOT EXISTS participants
(
  PARTY_ID INTEGER UNSIGNED NOT NULL PRIMARY KEY,
  PID INTEGER UNSIGNED,
  TID INTEGER UNSIGNED,
  UID INTEGER UNSIGNED NOT NULL,
  UNIQUE (PID, TID, UID)
);

DROP TABLE IF EXISTS task_categories;
CREATE TABLE IF NOT EXISTS task_categories
(
  tcid INTEGER UNSIGNED NOT NULL PRIMARY KEY,
  gid INTEGER UNSIGNED NOT NULL,
  name VARCHAR(30) NOT NULL
);

DROP TABLE IF EXISTS task_categories_removed;
CREATE TABLE IF NOT EXISTS task_categories_removed
(
  tcid INTEGER UNSIGNED NOT NULL,
  uid INTEGER UNSIGNED NOT NULL,
  UNIQUE (tcid, uid)
);

DROP TABLE IF EXISTS task_category_stage;
CREATE TABLE IF NOT EXISTS task_category_stage
(
  stage_id INTEGER UNSIGNED NOT NULL PRIMARY KEY,
  tcid INTEGER UNSIGNED NOT NULL,
  ix INTEGER UNSIGNED NOT NULL,
  name VARCHAR(30) NOT NULL,
  UNIQUE (tcid, ix)
);

DROP TABLE IF EXISTS web_references;
CREATE TABLE IF NOT EXISTS web_references
(
  webref_id INTEGER UNSIGNED NOT NULL PRIMARY KEY,
  url VARCHAR(255),
  description VARCHAR(255),
  tid INTEGER UNSIGNED NOT NULL
);

DROP TABLE IF EXISTS projects;
CREATE TABLE IF NOT EXISTS projects
(
  pid INTEGER UNSIGNED NOT NULL PRIMARY KEY,
  title VARCHAR(70),
  pmuid INTEGER UNSIGNED,
  prod_id VARCHAR(20),
  startdate DATE,
  enddate DATE,
  hours FLOAT UNSIGNED NOT NULL DEFAULT 0,
  esthours FLOAT UNSIGNED NOT NULL DEFAULT 0,
  status INTEGER UNSIGNED NOT NULL DEFAULT 0,
  percent INTEGER UNSIGNED NOT NULL DEFAULT 0,
  priority INTEGER UNSIGNED NOT NULL DEFAULT 3,
  budget INTEGER UNSIGNED,
  cost INTEGER UNSIGNED,
  estcost INTEGER UNSIGNED,
  objective TEXT,
  contingency TEXT,
  challenges TEXT
);

DROP TABLE IF EXISTS resources;
CREATE TABLE IF NOT EXISTS resources
(
  res_id INTEGER UNSIGNED NOT NULL PRIMARY KEY,
  pid INTEGER UNSIGNED,
  tid INTEGER UNSIGNED,
  name VARCHAR(100),
  UNIQUE (res_id, pid, tid)
);

DROP TABLE IF EXISTS milestones;
CREATE TABLE IF NOT EXISTS milestones
(
  mid INTEGER UNSIGNED NOT NULL PRIMARY KEY,
  pid INTEGER UNSIGNED,
  requestor_uid INTEGER UNSIGNED,
  uid INTEGER UNSIGNED,
  summary VARCHAR(100),
  startdate DATE,
  enddate DATE,
  status INTEGER UNSIGNED DEFAULT 0,
  priority INTEGER UNSIGNED DEFAULT 3,
  percent INTEGER UNSIGNED DEFAULT 0,
  hours FLOAT UNSIGNED DEFAULT 0, 
  esthours FLOAT UNSIGNED DEFAULT 0,
  description TEXT
);

DROP TABLE IF EXISTS tasks;
CREATE TABLE IF NOT EXISTS tasks
(
  tid INTEGER UNSIGNED NOT NULL PRIMARY KEY,
  prod_id VARCHAR(20), # Product ID, with version info.
  pid INTEGER UNSIGNED, # Project ID
  mid INTEGER UNSIGNED, # Milestone ID
  mtid VARCHAR(20), # Unique ID within a milestone.
  ptid INTEGER UNSIGNED, # Parent task (i.e., this is a subtask)
  title VARCHAR(50) NOT NULL,
  submitby_uid INTEGER UNSIGNED NOT NULL,
  submitted DATETIME,
  requestor_uid INTEGER UNSIGNED NOT NULL,
  uid INTEGER UNSIGNED,
  tcid INTEGER UNSIGNED,
  hours FLOAT UNSIGNED DEFAULT 0 NOT NULL, 
  esthours FLOAT UNSIGNED DEFAULT 0 NOT NULL,
  status INTEGER UNSIGNED DEFAULT 0,
  stage INTEGER UNSIGNED,
  percent INTEGER UNSIGNED DEFAULT 0,
  priority INTEGER UNSIGNED DEFAULT 0,
  cost FLOAT UNSIGNED,
  cost_hourly BOOL, # 0 = Total, 1 = hourly
  changed DATETIME,
  startdate DATE,
  duedate DATE,
  estcomdate DATE,
  actcomdate DATE,
  description TEXT
);

DROP TABLE IF EXISTS notes;
CREATE TABLE IF NOT EXISTS notes
(
  NID INTEGER UNSIGNED NOT NULL PRIMARY KEY,
  TID INTEGER UNSIGNED,
  MID INTEGER UNSIGNED,
  UID INTEGER UNSIGNED NOT NULL,
  TEXT TEXT NOT NULL,
  TIMESTAMP TIMESTAMP NULL,
  UNIQUE (TID, MID)
);

# starting from a week prior to the due date (on run, check due date, so dont have hardcoded date)
#	OR
# starting from a week AFTER the due date
# 	OR
# starting from a fixed date
#	OR
# starting immediately

# Remind every 1 day.
# Stop once task is completed.
# (dont need to remove, as task may be re-instated, and unique for tid/uid)

DROP TABLE IF EXISTS task_reminders;
CREATE TABLE IF NOT EXISTS task_reminders
(
  tid INTEGER UNSIGNED NOT NULL,
  uid INTEGER UNSIGNED NOT NULL,
  # start relative to due date?
  startdate DATETIME,
  relative_start_number INTEGER, # negative means before due date, positive means after
  relative_start_unit INTEGER UNSIGNED, # described below.
  interval_number INTEGER UNSIGNED, # Run for every X of interval_unit
  interval_unit INTEGER UNSIGNED, # 0 = hour, 1 = day, 2 = weekday, 3 = week, 4 = month

  UNIQUE (tid, uid)
);

DROP TABLE IF EXISTS skills;
CREATE TABLE IF NOT EXISTS skills
(
  sid INTEGER UNSIGNED NOT NULL PRIMARY KEY,
  gid INTEGER UNSIGNED,
  name VARCHAR(20)
);


DROP TABLE IF EXISTS products;
CREATE TABLE IF NOT EXISTS products
(
  PROD_ID INTEGER UNSIGNED NOT NULL PRIMARY KEY,
  NAME VARCHAR(50) NOT NULL,
  ABBREV VARCHAR(30) NOT NULL,
  MANAGER_UID INTEGER UNSIGNED,
  PRIORITY INTEGER UNSIGNED NOT NULL DEFAULT 3,
  OBJECTIVE TEXT,
  MISSION TEXT
);

DROP TABLE IF EXISTS product_versions;
CREATE TABLE IF NOT EXISTS product_versions
(
  VER_ID INTEGER UNSIGNED NOT NULL PRIMARY KEY,
  PROD_ID INTEGER UNSIGNED NOT NULL,
  VER_NAME VARCHAR(10) NOT NULL,
  VER_ALIAS VARCHAR(30),
  RELEASE_DATE VARCHAR(50),
  MARKETING_INTRODUCTION TEXT,
  CUSTOMIZATION_INTRO TEXT,
  INSTALL_INTRO TEXT,
  INSTALL_POST TEXT,
  MAIN_IMAGE VARCHAR(255),
  UNIQUE (PROD_ID, VER_NAME)
);

DROP TABLE IF EXISTS product_sysreq_modules;
CREATE TABLE IF NOT EXISTS product_sysreq_modules
(
  MODULE_ID INTEGER UNSIGNED NOT NULL PRIMARY KEY,
  PROD_ID INTEGER UNSIGNED NOT NULL,
  VER_ID INTEGER UNSIGNED NOT NULL,
  DESCRIPTION VARCHAR(255)
);

DROP TABLE IF EXISTS goals;
CREATE TABLE IF NOT EXISTS goals
(
  GOAL_ID INTEGER UNSIGNED NOT NULL PRIMARY KEY,
  PROD_ID INTEGER UNSIGNED NOT NULL, # Just for hell of it.
  VER_ID INTEGER UNSIGNED NOT NULL,
  COMPONENT_ID INTEGER UNSIGNED,
  GOAL_NUM INTEGER UNSIGNED,
  PRIORITY INTEGER UNSIGNED NOT NULL DEFAULT 3,
  MARKETING BOOL NOT NULL DEFAULT 0,
  STATUS INTEGER UNSIGNED NOT NULL DEFAULT 0,
  PERCENT INTEGER UNSIGNED NOT NULL DEFAULT 0,
  SUMMARY VARCHAR(255),
  DESCRIPTION TEXT
);

DROP TABLE IF EXISTS components;
CREATE TABLE IF NOT EXISTS components
(
  COMPONENT_ID INTEGER UNSIGNED NOT NULL PRIMARY KEY,
  PROD_ID INTEGER UNSIGNED NOT NULL,
  VER_ID INTEGER UNSIGNED NOT NULL,
  COMPONENT_NUM INTEGER UNSIGNED,
  HIDE BOOL DEFAULT 0,
  NAME VARCHAR(30),
  ABBREV VARCHAR(30),
  SUMMARY VARCHAR(255)
);

DROP TABLE IF EXISTS component_features;
CREATE TABLE IF NOT EXISTS component_features
(
  CFEATURE_ID INTEGER UNSIGNED NOT NULL PRIMARY KEY,
  COMPONENT_ID INTEGER UNSIGNED NOT NULL,
  FEATURE_NUM INTEGER UNSIGNED,
  NAME VARCHAR(255),
  ABBREV VARCHAR(30),
  SUMMARY VARCHAR(255),
  DESCRIPTIVE_NAME VARCHAR(255),
  DESCRIPTION TEXT
);

DROP TABLE IF EXISTS feature_items;
CREATE TABLE IF NOT EXISTS feature_items
(
  FITEM_ID INTEGER UNSIGNED NOT NULL PRIMARY KEY,
  CFEATURE_ID INTEGER UNSIGNED NOT NULL,
  ITEM_NUM INTEGER UNSIGNED,
  NAME VARCHAR(30),
  DESCRIPTION TEXT
);


DROP TABLE IF EXISTS goal_feature_link;
CREATE TABLE IF NOT EXISTS goal_feature_link
(
  LINK_ID INTEGER UNSIGNED NOT NULL PRIMARY KEY,
  GOAL_ID INTEGER UNSIGNED NOT NULL,
  CFEATURE_ID INTEGER UNSIGNED NOT NULL,
  UNIQUE (GOAL_ID, CFEATURE_ID)
);

DROP TABLE IF EXISTS feature_request;
CREATE TABLE IF NOT EXISTS feature_request
(
  REQ_ID INTEGER UNSIGNED NOT NULL PRIMARY KEY,
  PROD_ID INTEGER UNSIGNED NOT NULL,
  VER_ID INTEGER UNSIGNED NOT NULL,
  NAME VARCHAR(100) NOT NULL,
  UID INTEGER UNSIGNED, # Responsible person for overseeing

  SCOPE INTEGER UNSIGNED NOT NULL DEFAULT 0,
  PRIORITY INTEGER UNSIGNED NOT NULL DEFAULT 3,
  STATUS INTEGER UNSIGNED NOT NULL DEFAULT 0,

  SUBMIT_DATE DATE,
  REQUEST_DATE DATE,
  ESTIMATED_DATE DATE,
  IMPLEMENTED_DATE DATE,

  DESCRIPTION TEXT
);

DROP TABLE IF EXISTS product_images;
CREATE TABLE IF NOT EXISTS product_images
(
  IMAGE_ID INTEGER UNSIGNED NOT NULL PRIMARY KEY,
  PROD_ID INTEGER UNSIGNED NOT NULL,
  VER_ID INTEGER UNSIGNED,
  SRC VARCHAR(255),
  CAPTION VARCHAR(255)
);

DROP TABLE IF EXISTS image_reference;
CREATE TABLE IF NOT EXISTS image_reference
(
  IREF_ID INTEGER UNSIGNED NOT NULL PRIMARY KEY,
  IMAGE_ID INTEGER UNSIGNED NOT NULL,
  TABLE_NAME VARCHAR(50) NOT NULL,
  KEY_VALUE INTEGER UNSIGNED NOT NULL
);


DROP TABLE IF EXISTS product_audience;
CREATE TABLE IF NOT EXISTS product_audience
(
  AUDIENCE_ID INTEGER UNSIGNED NOT NULL PRIMARY KEY,
  PROD_ID INTEGER UNSIGNED NOT NULL,
  VER_ID INTEGER UNSIGNED NOT NULL,
  ORDER_ID INTEGER UNSIGNED,
  DESCRIPTION TEXT
);

DROP TABLE IF EXISTS product_sysreq;
CREATE TABLE IF NOT EXISTS product_sysreq
(
  SYSREQ_ID INTEGER UNSIGNED NOT NULL PRIMARY KEY,
  NAME VARCHAR(255),
  PREREQ BOOL,
  SUMMARY VARCHAR(255),
  DESCRIPTION TEXT
);

DROP TABLE IF EXISTS product_sysreq_options;
CREATE TABLE IF NOT EXISTS product_sysreq_options
(
  SOPT_ID INTEGER UNSIGNED NOT NULL PRIMARY KEY,
  SYSREQ_ID INTEGER UNSIGNED NOT NULL,
  NAME VARCHAR(255),
  OVERVIEW TEXT
);

DROP TABLE IF EXISTS product_sysreq_options_config_step;
CREATE TABLE IF NOT EXISTS product_sysreq_options_config_step
(
  CONFSTEP_ID INTEGER UNSIGNED NOT NULL PRIMARY KEY,
  SOPT_ID INTEGER UNSIGNED NOT NULL,
  ORDER_NUM INTEGER UNSIGNED NOT NULL,
  SUMMARY VARCHAR(255),
  TEXT TEXT,
  CODE TEXT
);

DROP TABLE IF EXISTS product_feature_howto;
CREATE TABLE IF NOT EXISTS product_feature_howto
(
  FEATURE_HOWTO_ID INTEGER UNSIGNED NOT NULL PRIMARY KEY,
  CFEATURE_ID INTEGER UNSIGNED NOT NULL,
  HOWTO_NUM INTEGER UNSIGNED,
  TITLE VARCHAR(100),
  OVERVIEW TEXT
);

DROP TABLE IF EXISTS product_feature_howto_image;
CREATE TABLE IF NOT EXISTS product_feature_howto_image
(
  IMAGE_ID INTEGER UNSIGNED NOT NULL PRIMARY KEY,
  FEATURE_HOWTO_ID INTEGER UNSIGNED NOT NULL,
  ORDER_NUM INTEGER UNSIGNED,
  SRC VARCHAR(255),
  TITLE VARCHAR(255),
  DESCRIPTION TEXT
);

DROP TABLE IF EXISTS product_feature_howto_step;
CREATE TABLE IF NOT EXISTS product_feature_howto_step
(
  STEP_ID INTEGER UNSIGNED NOT NULL PRIMARY KEY,
  FEATURE_HOWTO_ID INTEGER UNSIGNED NOT NULL,
  ORDER_NUM INTEGER UNSIGNED,
  SUMMARY VARCHAR(100),
  TEXT TEXT,
  CODE TEXT
);

DROP TABLE IF EXISTS product_feature_howto_step_image;
CREATE TABLE IF NOT EXISTS product_feature_howto_step_image
(
  STEP_IMAGE_ID INTEGER UNSIGNED NOT NULL PRIMARY KEY,
  STEP_ID INTEGER UNSIGNED NOT NULL,
  ORDER_NUM INTEGER UNSIGNED,
  SRC VARCHAR(255),
  TITLE VARCHAR(255),
  DESCRIPTION TEXT
);


DROP TABLE IF EXISTS product_feature_overview;
CREATE TABLE IF NOT EXISTS product_feature_overview
(
  FEATURE_OVERVIEW_ID INTEGER UNSIGNED NOT NULL PRIMARY KEY,
  CFEATURE_ID INTEGER UNSIGNED NOT NULL,
  ORDER_NUM INTEGER UNSIGNED,
  SRC VARCHAR(255),
  TITLE VARCHAR(255),
  DESCRIPTION TEXT
);

DROP TABLE IF EXISTS product_tutorial;
CREATE TABLE IF NOT EXISTS product_tutorial
(
  TUTORIAL_ID INTEGER UNSIGNED NOT NULL PRIMARY KEY,
  CFEATURE_ID INTEGER UNSIGNED NOT NULL,
  VER_ID INTEGER UNSIGNED NOT NULL,
  COMPONENT_ID INTEGER UNSIGNED,
  TUTORIAL_NUM INTEGER UNSIGNED,
  TITLE VARCHAR(100),
  ABBREV VARCHAR(20),
  OVERVIEW TEXT
);

DROP TABLE IF EXISTS product_tutorial_image;
CREATE TABLE IF NOT EXISTS product_tutorial_image
(
  IMAGE_ID INTEGER UNSIGNED NOT NULL PRIMARY KEY,
  TUTORIAL_ID INTEGER UNSIGNED NOT NULL,
  ORDER_NUM INTEGER UNSIGNED,
  SRC VARCHAR(255),
  TITLE VARCHAR(255),
  DESCRIPTION TEXT
);


DROP TABLE IF EXISTS product_tutorial_sections;
CREATE TABLE IF NOT EXISTS product_tutorial_sections
(
  SECTION_ID INTEGER UNSIGNED NOT NULL PRIMARY KEY,
  TUTORIAL_ID INTEGER UNSIGNED NOT NULL,
  ORDER_NUM INTEGER UNSIGNED,
  TITLE VARCHAR(100),
  SUMMARY TEXT
);

DROP TABLE IF EXISTS product_tutorial_see_also;
CREATE TABLE IF NOT EXISTS product_tutorial_see_also
(
  SEEALSO_ID INTEGER UNSIGNED NOT NULL PRIMARY KEY,
  SECTION_ID INTEGER UNSIGNED NOT NULL,
  ORDER_NUM INTEGER UNSIGNED,
  ABBREV VARCHAR(20) NOT NULL
);

DROP TABLE IF EXISTS product_tutorial_section_image;
CREATE TABLE IF NOT EXISTS product_tutorial_section_image
(
  IMAGE_ID INTEGER UNSIGNED NOT NULL PRIMARY KEY,
  SECTION_ID INTEGER UNSIGNED NOT NULL,
  ORDER_NUM INTEGER UNSIGNED,
  SRC VARCHAR(255),
  TITLE VARCHAR(255),
  DESCRIPTION TEXT
);

DROP TABLE IF EXISTS product_tutorial_section_step;
CREATE TABLE IF NOT EXISTS product_tutorial_section_step
(
  SECSTEP_ID INTEGER UNSIGNED NOT NULL PRIMARY KEY,
  SECTION_ID INTEGER UNSIGNED NOT NULL,
  SUMMARY VARCHAR(100),
  STEP_NUM INTEGER UNSIGNED,
  TEXT TEXT,
  CODE TEXT
);

DROP TABLE IF EXISTS product_tutorial_section_step_image;
CREATE TABLE IF NOT EXISTS product_tutorial_section_step_image
(
  STEP_IMAGE_ID INTEGER UNSIGNED NOT NULL PRIMARY KEY,
  SECSTEP_ID INTEGER UNSIGNED NOT NULL,
  ORDER_NUM INTEGER UNSIGNED,
  SRC VARCHAR(255),
  TITLE VARCHAR(255),
  DESCRIPTION TEXT
);

DROP TABLE IF EXISTS product_customization_section;
CREATE TABLE IF NOT EXISTS product_customization_section
(
  SECTION_ID INTEGER UNSIGNED NOT NULL PRIMARY KEY,
  VER_ID INTEGER UNSIGNED NOT NULL,
  TITLE VARCHAR(100),
  ORDER_NUM INTEGER UNSIGNED,
  SUMMARY TEXT
);

DROP TABLE IF EXISTS product_customization_step;
CREATE TABLE IF NOT EXISTS product_customization_step
(
  CUSTSTEP_ID INTEGER UNSIGNED NOT NULL PRIMARY KEY,
  SECTION_ID INTEGER UNSIGNED NOT NULL,
  STEP_NUM INTEGER UNSIGNED,
  SUMMARY VARCHAR(100),
  TEXT TEXT,
  CODE TEXT
);

DROP TABLE IF EXISTS product_customization_step_image;
CREATE TABLE IF NOT EXISTS product_customization_step_image
(
  STEP_IMAGE_ID INTEGER UNSIGNED NOT NULL PRIMARY KEY,
  CUSTSTEP_ID INTEGER UNSIGNED NOT NULL,
  ORDER_NUM INTEGER UNSIGNED,
  SRC VARCHAR(255),
  TITLE VARCHAR(255),
  DESCRIPTION TEXT
);

DROP TABLE IF EXISTS product_installation_step;
CREATE TABLE IF NOT EXISTS product_installation_step
(
  CUSTSTEP_ID INTEGER UNSIGNED NOT NULL PRIMARY KEY,
  VER_ID INTEGER UNSIGNED NOT NULL,
  STEP_NUM INTEGER UNSIGNED,
  SUMMARY VARCHAR(100),
  TEXT TEXT,
  CODE TEXT
);

DROP TABLE IF EXISTS product_installation_step_image;
CREATE TABLE IF NOT EXISTS product_installation_step_image
(
  STEP_IMAGE_ID INTEGER UNSIGNED NOT NULL PRIMARY KEY,
  CUSTSTEP_ID INTEGER UNSIGNED NOT NULL,
  ORDER_NUM INTEGER UNSIGNED,
  SRC VARCHAR(255),
  TITLE VARCHAR(255),
  DESCRIPTION TEXT
);

DROP TABLE IF EXISTS product_screenshots;
CREATE TABLE IF NOT EXISTS product_screenshots
(
  IMAGE_ID INTEGER UNSIGNED NOT NULL PRIMARY KEY,
  VER_ID INTEGER UNSIGNED NOT NULL,
  ORDER_NUM INTEGER UNSIGNED,
  MAIN_PAGE BOOL,
  SRC VARCHAR(255),
  TITLE VARCHAR(255),
  DESCRIPTION TEXT
);






DROP TABLE IF EXISTS product_sysreq_link;
CREATE TABLE IF NOT EXISTS product_sysreq_link
(
  SYSREQ_LINK_ID INTEGER UNSIGNED NOT NULL PRIMARY KEY,
  PROD_ID INTEGER UNSIGNED NOT NULL,
  VER_ID INTEGER UNSIGNED NOT NULL,
  ORDER_ID INTEGER UNSIGNED,
  SYSREQ_ID INTEGER UNSIGNED NOT NULL
);

DROP TABLE IF EXISTS product_applications;
CREATE TABLE IF NOT EXISTS product_applications
(
  APPLICATION_ID INTEGER UNSIGNED NOT NULL PRIMARY KEY,
  PROD_ID INTEGER UNSIGNED NOT NULL,
  VER_ID INTEGER UNSIGNED NOT NULL,
  APP_NUM INTEGER UNSIGNED,
  NAME VARCHAR(255),
  DESCRIPTION TEXT

);

DROP TABLE IF EXISTS product_terminology;
CREATE TABLE IF NOT EXISTS product_terminology
(
  TERM_ID INTEGER UNSIGNED NOT NULL PRIMARY KEY,
  PROD_ID INTEGER UNSIGNED NOT NULL,
  VER_ID INTEGER UNSIGNED NOT NULL,
  NAME VARCHAR(255),
  DESCRIPTION TEXT
);

DROP TABLE IF EXISTS reference_images;
CREATE TABLE IF NOT EXISTS reference_images
(
  IMAGE_ID INTEGER UNSIGNED NOT NULL PRIMARY KEY,
  ARCH_ID INTEGER UNSIGNED,
  OVERVIEW_COMPONENT_ID INTEGER UNSIGNED,
  ACCESS_COMPONENT_ID INTEGER UNSIGNED,
  ORDER_ID INTEGER UNSIGNED,
  SRC VARCHAR(255),
  UNIQUE (ARCH_ID, OVERVIEW_COMPONENT_ID, ACCESS_COMPONENT_ID)
);

DROP TABLE IF EXISTS image_meta;
CREATE TABLE IF NOT EXISTS image_meta
(
  IMAGE_META_ID INTEGER UNSIGNED NOT NULL PRIMARY KEY,
  VER_ID INTEGER UNSIGNED NOT NULL,
  SRC VARCHAR(255),
  CAPTION VARCHAR(50),
  DESCRIPTION TEXT
);

DROP TABLE IF EXISTS product_architecture;
CREATE TABLE IF NOT EXISTS product_architecture
(
  ARCH_ID INTEGER UNSIGNED NOT NULL PRIMARY KEY,
  VER_ID INTEGER UNSIGNED NOT NULL,
  TITLE VARCHAR(255),
  PARAGRAPH_ORDER INTEGER UNSIGNED,
  TEXT TEXT
);

DROP TABLE IF EXISTS component_access;
CREATE TABLE IF NOT EXISTS component_access
(
  ACCESS_ID INTEGER UNSIGNED NOT NULL PRIMARY KEY,
  COMPONENT_ID INTEGER UNSIGNED NOT NULL,
  ORDER_ID INTEGER UNSIGNED,
  SRC VARCHAR(255),
  TITLE VARCHAR(50),
  DESCRIPTION TEXT
);

DROP TABLE IF EXISTS component_access_images;
CREATE TABLE IF NOT EXISTS component_access_images
(
  IMAGE_ID INTEGER UNSIGNED NOT NULL PRIMARY KEY,
  ACCESS_ID INTEGER UNSIGNED NOT NULL,
  ORDER_ID INTEGER UNSIGNED,
  SRC VARCHAR(255)
);


DROP TABLE IF EXISTS component_overview;
CREATE TABLE IF NOT EXISTS component_overview
(
  OVERVIEW_ID INTEGER UNSIGNED NOT NULL PRIMARY KEY,
  COMPONENT_ID INTEGER UNSIGNED NOT NULL,
  ORDER_ID INTEGER UNSIGNED,
  SRC VARCHAR(255),
  TITLE VARCHAR(50),
  DESCRIPTION TEXT
);









DROP TABLE IF EXISTS competitors;
CREATE TABLE IF NOT EXISTS competitors
(
  COMP_ID INTEGER UNSIGNED NOT NULL PRIMARY KEY,
  PROD_ID INTEGER UNSIGNED NOT NULL,
  VER_ID INTEGER UNSIGNED,
  UID INTEGER UNSIGNED NOT NULL,
  NAME VARCHAR(50) NOT NULL,
  URL VARCHAR(255),
  PRIORITY INTEGER UNSIGNED NOT NULL DEFAULT 3,
  LEVEL INTEGER UNSIGNED NOT NULL DEFAULT 5,

  SCORE INTEGER NOT NULL DEFAULT 0,

  # SCORING !!!!!!!!!!!!!1 BASED UPON BELOW RANKINGS ..... ???
  # should be below and ranking from features

  # May want to some day keep former values. i.e., one record per change.

  COMPANY VARCHAR(50),
  EMPLOYEES INTEGER UNSIGNED,
  LOCATION VARCHAR(50),

  # ranking of certain aspects of product.
  LOOKNFEEL INTEGER NOT NULL DEFAULT 0,
  USABILITY INTEGER NOT NULL DEFAULT 0,
  INTEGRATION INTEGER NOT NULL DEFAULT 0,
  DOCUMENTATION INTEGER NOT NULL DEFAULT 0,
  CUSTOMERSERVICE INTEGER NOT NULL DEFAULT 0,
  COMPATIBILITY INTEGER NOT NULL DEFAULT 0,
  ROADMAP INTEGER NOT NULL DEFAULT 0,
  FEATURES INTEGER NOT NULL DEFAULT 0,
  ARCHITECTURE INTEGER NOT NULL DEFAULT 0,
  TARGETMARKET INTEGER NOT NULL DEFAULT 0,
  PRICING INTEGER NOT NULL DEFAULT 0,

  DESCRIPTION TEXT,
  PRICING_DESCRIPTION TEXT

);


DROP TABLE IF EXISTS competitor_versions;
CREATE TABLE IF NOT EXISTS competitor_versions
(
  CVER_ID INTEGER UNSIGNED NOT NULL PRIMARY KEY,
  COMP_ID INTEGER UNSIGNED NOT NULL,
  VER_ID VARCHAR(20) NOT NULL,
  RELEASE_DATE DATE

);

DROP TABLE IF EXISTS competitor_features;
CREATE TABLE IF NOT EXISTS competitor_features
(
  COMPFEAT_ID INTEGER UNSIGNED NOT NULL PRIMARY KEY,
  COMP_ID INTEGER UNSIGNED NOT NULL,
  CVER_ID INTEGER UNSIGNED,

  PRIORITY INTEGER NOT NULL DEFAULT 0,

  SCORE INTEGER NOT NULL DEFAULT 0,

  SCOPE INTEGER UNSIGNED NOT NULL DEFAULT 0,

  SUBMIT_DATE DATE, # When entered in system. (or possibly when implemnted by competitor)
  IMPLEMENTED_DATE DATE,


  # Information regarding how well we are catching up to the specific thing.

  OUR_IMPLEMENTED_DATE DATE,

  OUR_STATUS INTEGER UNSIGNED NOT NULL DEFAULT 0,
  OUR_PERCENT INTEGER UNSIGNED NOT NULL DEFAULT 0 # Determines how much of score to count (100 - percent)


);





DROP TABLE IF EXISTS task_link;
CREATE TABLE IF NOT EXISTS task_link # Linking tasks to parent task, project, or milestone (or mile of proj)
(
  LINK_ID INTEGER UNSIGNED NOT NULL PRIMARY KEY,
  TID INTEGER UNSIGNED NOT NULL,
  MID INTEGER UNSIGNED,
  PTID INTEGER UNSIGNED,
  NTID INTEGER UNSIGNED,
  STRICT BOOL DEFAULT 0, # Whether strict dependence (must complete before starting parent)
  INDEX TID (TID),
  UNIQUE LINK (TID, MID, PTID)
);
