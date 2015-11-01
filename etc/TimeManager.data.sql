INSERT INTO users SET uid=1, username='tomas', password='tomas', email='tomas@financialcircuit.com', fullname='Tomas Maly', title='Software Developer',siteadmin=1;
INSERT INTO users SET uid=2, username='eric', password='eric1', email='tomas_maly@financialcircuit.com', fullname='Eric Horton', title='Creative Designer',siteadmin=0;
INSERT INTO users SET uid=3, username='jmcminn', password='jmcminn1', email='tomas_maly@financialcircuit.com', fullname='Josh McMinn', title='System Administrator',siteadmin=0;
INSERT INTO users SET uid=4, username='nathans', password='nathans1', email='tomas_maly@financialcircuit.com', fullname='Nathan Sullivan', title='Software Developer',siteadmin=0;
INSERT INTO users SET uid=5, username='sakthi', password='sakthi1', email='tomas_maly@financialcircuit.com', fullname='Sakthi Sundaram', title='Senior Software Developer',siteadmin=0;
INSERT INTO users SET uid=6, username='tomas6', password='tomas', email='tomas_maly@financialcircuit.com', fullname='Tomas Maly 6', title='Software Developer',siteadmin=0;
INSERT INTO users SET uid=7, username='tomas7', password='tomas', email='tomas_maly@financialcircuit.com', fullname='Tomas Maly 7', title='Software Developer',siteadmin=0;
INSERT INTO users SET uid=8, username='tomas8', password='tomas', email='tomas_maly@financialcircuit.com', fullname='Tomas Maly 8', title='Software Developer',siteadmin=0;
INSERT INTO users SET uid=9, username='tomas9', password='tomas', email='tomas_maly@financialcircuit.com', fullname='Tomas Maly 9', title='Software Developer',siteadmin=0;
INSERT INTO users SET uid=10, username='tomas10', password='tomas', email='tomas_maly@financialcircuit.com', fullname='Tomas Maly 10', title='Software Developer',siteadmin=0;
INSERT INTO users SET uid=11, username='tomas11', password='tomas', email='tomas_maly@financialcircuit.com', fullname='Tomas Maly 11', title='Software Developer',siteadmin=0;
INSERT INTO users SET uid=12, username='tomas12', password='tomas', email='tomas_maly@financialcircuit.com', fullname='Tomas Maly 12', title='Software Developer',siteadmin=0;


INSERT INTO shortcuts SET shid=0,name='My Tasks',uid=1,shurl='/cgi-bin/Tasks.pl/tomas/Search?gid=';
INSERT INTO shortcuts SET shid=1,name='Engineering Tasks',uid=1,shurl='/cgi-bin/Tasks.pl/tomas/Search?gid=0';
INSERT INTO shortcuts SET shid=2,name='Technology Group Tasks',uid=1,shurl='/cgi-bin/Tasks.pl/tomas/Search?gid=1';


INSERT INTO groups SET gid=0,name='Information Technology',manager_uid=1;
INSERT INTO groups SET gid=1,name='Engineering',manager_uid=1;
INSERT INTO groups SET gid=2,name='BizDev',manager_uid=0;


INSERT INTO group_members SET gid=0,uid=1;
INSERT INTO group_members SET gid=0,uid=2;
INSERT INTO group_members SET gid=0,uid=3;
INSERT INTO group_members SET gid=0,uid=4;
INSERT INTO group_members SET gid=0,uid=5;
INSERT INTO group_members SET gid=1,uid=1;
INSERT INTO group_members SET gid=1,uid=4;
INSERT INTO group_members SET gid=1,uid=5;


INSERT INTO user_managers SET UID=0,MANAGER_UID=1;
INSERT INTO user_managers SET UID=1,MANAGER_UID=1;
INSERT INTO user_managers SET UID=2,MANAGER_UID=1;
INSERT INTO user_managers SET UID=3,MANAGER_UID=1;
INSERT INTO user_managers SET UID=4,MANAGER_UID=1;
INSERT INTO user_managers SET UID=5,MANAGER_UID=1;


INSERT INTO project_participants SET pid=0,uid=1;
INSERT INTO project_participants SET pid=0,uid=2;
INSERT INTO project_participants SET pid=0,uid=3;
INSERT INTO project_participants SET pid=0,uid=4;
INSERT INTO project_participants SET pid=0,uid=5;


INSERT INTO task_categories SET tcid=0,gid=0,name="New Computer";
INSERT INTO task_categories SET tcid=1,gid=0,name="Server Upgrade";
INSERT INTO task_categories SET tcid=2,gid=0,name="Workstation Support";
INSERT INTO task_categories SET tcid=3,gid=0,name="Network Upgrade";
INSERT INTO task_categories SET tcid=4,gid=0,name="Web Page Typo";


INSERT INTO projects SET pid=0,title="Test Project #1",pmuid=1,startdate='2003-12-31',enddate='2004-12-31',objective='To conquer the world.', contingency='Run away';
INSERT INTO projects SET pid=1,title="Test Project #2",pmuid=2,startdate='2003-12-31',enddate='2004-12-31',objective='To conquer the world.', contingency='Run away';
INSERT INTO projects SET pid=2,title="Test Project #3",pmuid=3,startdate='2003-12-31',enddate='2004-12-31',objective='To conquer the world.', contingency='Run away';


INSERT INTO milestones SET pid=0, mid=0,pmid=1, summary="Install the servers", startdate='2004-02-01',enddate='2004-02-31';
INSERT INTO milestones SET pid=0, mid=1,pmid=2, summary="Install the operating system", startdate='2004-03-01',enddate='2004-03-31';
INSERT INTO milestones SET pid=0, mid=2,pmid=3, summary="Install the web software", startdate='2004-04-01',enddate='2004-04-31';
INSERT INTO milestones SET pid=0, mid=3,pmid=4, summary="Flip the switch", startdate='2004-05-01',enddate='2004-05-31';


INSERT INTO dependencies SET tid=17,dependent_tid=16;
INSERT INTO dependencies SET tid=17,dependent_tid=15;
INSERT INTO dependencies SET tid=17,dependent_tid=14;
INSERT INTO dependencies SET tid=17,dependent_tid=13;


INSERT INTO tasks SET tid=0,title='Test 1',requestor_uid=1,uid=1,status=1,priority=0,startdate='2002-12-31',duedate='2003-04-26 13:00',percent=50;
INSERT INTO tasks SET tid=1,uid=2,title='Test 2',requestor_uid=1,status=2,priority=1,startdate='2003-01-16',duedate='2003-11-23',description='DESCRIPTION GOES HERE',percent=10;
INSERT INTO tasks SET tid=2,uid=0,title='Test 3',requestor_uid=1,status=10,priority=2,startdate='2003-01-23',duedate='2003-04-27',percent=30;
INSERT INTO tasks SET tid=3,uid=1,title='Test 4',requestor_uid=1,status=11,priority=3,startdate='2003-01-22',duedate='2003-02-22',percent=100;
INSERT INTO tasks SET tid=4,uid=1,title='Test 5',requestor_uid=1,status=0,priority=4,startdate='2003-01-22',duedate='2003-02-29',percent=0;
INSERT INTO tasks SET tid=5,uid=1,title='Test 6',requestor_uid=1,status=1,priority=3,startdate='2003-01-22',duedate='2003-02-29',percent=0;
INSERT INTO tasks SET tid=6,uid=1,title='Test 7',requestor_uid=1,status=2,priority=4,startdate='2003-01-22',duedate='2003-02-29',percent=0;
INSERT INTO tasks SET tid=7,uid=1,title='Test 8',requestor_uid=1,status=0,priority=4,startdate='2003-01-22',duedate='2003-02-29',percent=0;
INSERT INTO tasks SET tid=8,uid=1,title='Test 9',requestor_uid=1,status=2,priority=1,startdate='2003-01-22',duedate='2003-02-29',percent=0;
INSERT INTO tasks SET tid=9,uid=1,title='Test 10',requestor_uid=1,status=3,priority=2,startdate='2003-01-22',duedate='2004-01-17',percent=0;
INSERT INTO tasks SET tid=10,uid=1,title='Test 11',requestor_uid=1,status=0,priority=2,startdate='2003-01-22',duedate='2003-11-29',percent=0;
INSERT INTO tasks SET tid=11,uid=1,title='Test 12',requestor_uid=1,status=2,priority=4,startdate='2003-01-22',duedate='2003-12-29',percent=0;

INSERT INTO tasks SET tid=12,pid=0,uid=1,title='Test 13',requestor_uid=1,status=0,priority=4,startdate='2003-01-22',duedate='2004-02-29',percent=0;
INSERT INTO tasks SET tid=13,pid=0,mid=0,mtid='1',title='Set up power strips',requestor_uid=1,uid=2,status=1,percent=10,priority=3,startdate='2004-02-01',duedate='2004-02-15';
INSERT INTO tasks SET tid=14,pid=0,mid=0,mtid='2',title='Set up server racks',requestor_uid=1,uid=3,status=0,percent=0,priority=3,startdate='2004-02-01',duedate='2004-02-15';
INSERT INTO tasks SET tid=15,pid=0,mid=0,mtid='3',title='Turn servers on',requestor_uid=1,uid=2,status=0,percent=0,priority=3,startdate='2004-02-01',duedate='2004-02-15';

INSERT INTO tasks SET tid=16,pid=0,mid=1,mtid='1',title='Put in CD',requestor_uid=1,uid=4,status=1,percent=20,priority=1,startdate='2004-02-01',duedate='2004-02-15';
INSERT INTO tasks SET tid=17,pid=0,mid=1,mtid='2',title='Run Setup',requestor_uid=1,uid=1,status=2,percent=0,priority=1,startdate='2004-02-01',duedate='2004-02-15';

INSERT INTO tasks SET tid=18,pid=0,mid=2,mtid='1',title='Download Apache',requestor_uid=1,uid=2,status=2,percent=0,priority=1,startdate='2004-02-01',duedate='2004-02-15';
INSERT INTO tasks SET tid=20,pid=0,mid=2,mtid='2',title='Run configure script',requestor_uid=1,uid=4,status=1,percent=0,priority=2,startdate='2004-02-01',duedate='2004-02-15';

INSERT INTO tasks SET tid=21,pid=0,mid=3,mtid='1',title='Shut old server off',requestor_uid=1,uid=4,status=2,percent=90,priority=0,startdate='2004-02-01',duedate='2004-02-15';
INSERT INTO tasks SET tid=22,pid=0,mid=3,mtid='2',title='Turn new server on',requestor_uid=1,uid=3,status=2,percent=50,priority=2,startdate='2004-02-01',duedate='2004-02-15';


INSERT INTO task_notes SET nid=0,tid=0,uid=1,text="This looks like a mess.",timestamp=null;
INSERT INTO task_notes SET nid=1,tid=0,uid=1,text="Status changed to BACK BURNER",timestamp=null;
INSERT INTO task_notes SET nid=2,tid=0,uid=1,text="Percent changed to 10",timestamp=null;


INSERT INTO task_reminders SET tid=17,uid=1,relative_start_number = -7, relative_start_unit = 1, interval_number = 1, interval_unit = 1;
INSERT INTO task_reminders SET tid=13,uid=1,relative_start_number = -7, relative_start_unit = 1, interval_number = 1, interval_unit = 1;
INSERT INTO task_reminders SET tid=13,uid=2,relative_start_number = -7, relative_start_unit = 1, interval_number = 1, interval_unit = 1;


INSERT INTO skills SET sid=0,name='Teamwork';
INSERT INTO skills SET sid=1,name='Documentation';
INSERT INTO skills SET sid=2,gid=1,name='Perl Programming';
INSERT INTO skills SET sid=3,gid=1,name='Web Development';
INSERT INTO skills SET sid=4,gid=0,name='Web Server Administration';


INSERT INTO events VALUES(0,1,"Conquer the world", "Home sweet hoam", "2003-12-12", "2003-12-21", NULL, 1, "T", "tomas_maly@financialcircuit.com", "Birthday PartiesCandle Light dinners", NULL, NULL, "Make world peace a nightmare"); 
INSERT INTO events VALUES(1,1,"Clean up New York City", "Timez SKWARE", "2003-09-12", "2003-11-21", NULL, 1, "C", "tomas_maly@financialcircuit.com", "World Pace", NULL, NULL, "Clean up all the trash."); 


INSERT INTO attendees VALUES(0,'E', 0, "John Darnett", "jd@aol.com", "I", "A", "R", 1, NULL);
INSERT INTO attendees VALUES(0,'E', 1, "Kevin OMalley", "ko@aol.com", "I", "A", "R", 1, NULL);
INSERT INTO attendees VALUES(0,'E', 2, "Tomas Maly Twin", "tomas@financialcircuit.com", "I", "A", "R", 1, NULL);
INSERT INTO attendees VALUES(0,'E', 3, "Freida Felcher", "ff@aol.com", "I", "A", "R", NULL, NULL);
INSERT INTO attendees VALUES(0,'E', 4, "Gimmick Finnick", "gf@aol.com", "I", "D", "R", 1, "I HATE MEETINGS");
INSERT INTO attendees VALUES(0,'E', 5, "Larry Fleisher", "lf@aol.com", "I", "A", "R", 1, NULL);
INSERT INTO attendees VALUES(0,'E', 6, "Red Commy", "rc@aol.com", "I", "T", NULL, 1, "I DUNNO, DUDE");
INSERT INTO attendees VALUES(0,'E', 7, "Michael Bolton", "mb@aol.com", "I", "A", "R", NULL, NULL);
INSERT INTO attendees VALUES(0,'E', 8, "Stacy Wacy", "sw@aol.com", "I", "A", "R", 1, "Sorry dude. Gotta take care of the kids.");


