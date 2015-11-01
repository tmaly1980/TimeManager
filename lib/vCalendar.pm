package vCalendar;

use Text::vFile::Base;
use base 'Text::vFile::Base';
$Text::vFile::classMap{'VCALENDAR'}=__PACKAGE__;
$Text::vFile::classMap{'STANDARD'}=__PACKAGE__;
$Text::vFile::classMap{'DAYLIGHT'}=__PACKAGE__;
$Text::vFile::classMap{'VEVENT'}=__PACKAGE__;
$Text::vFile::classMap{'VTIMEZONE'}=__PACKAGE__;

1;
