#!/usr/bin/env perl

use DBI;
use strict;

my $driver = "SQLite";
my $database = "foo";
my $dsn = "DBI:$driver:dbname=$database";

my $dbh = DBI->connect($dsn, '', '', { RaiseError => 1}) || die $DBI::errstr;

print "Opened database\n";

my $findmember = 'SELECT memberid, vorname FROM member WHERE membercode=?;';
my $sthfindmember = $dbh->prepare($findmember);

my $memberfromid = 'SELECT vorname, nachname FROM member WHERE memberid=?;';
my $sthmemberfromid = $dbh->prepare($memberfromid);

my $finditem = 'SELECT itemid, itemname FROM items WHERE itemcode=?;';
my $sthfinditem = $dbh->prepare($finditem);

my $findausleihe = 'SELECT leihid,memberid FROM leihliste WHERE itemid=? AND rueckgabe IS NULL;';
my $sthfindausleihe = $dbh->prepare($findausleihe);

my $ausleihen = "INSERT into leihliste (itemid, memberid, ausleihe) VALUES (?, ?, DATETIME('now'));";
my $sthausleihen = $dbh->prepare($ausleihen);

my $rueckgabe = "UPDATE leihliste SET rueckgabe=DATETIME('now') WHERE leihid=?;";
my $sthrueckgabe = $dbh->prepare($rueckgabe);

while(1) {
  print "Mitgliedscode:";
  my ($barcode,$memberid, $vorname,$itemid, $itemname);
  $barcode = &read_barcode;
  my $rv = $sthfindmember->execute($barcode) or die $DBI::errstr;

  if($rv < 0) {
    print $DBI::errstr;
  }
  if(my @row = $sthfindmember->fetchrow_array()) {
    print "Mitglied $row[1]\n";
    ($memberid,$vorname) = @row;
  } else {
    print "Mitglied $barcode nicht gefunden\n";
    next;
  }
  while(1) {
    print "Geraetenummer/Mitgliedscode:";
    $barcode = &read_barcode;

    $rv = $sthfindmember->execute($barcode) or die $DBI::errstr;
    if($rv < 0) {
      print $DBI::errstr;
    }
    if(my @row = $sthfindmember->fetchrow_array()) {
      if ($row[0] == $memberid) {
	print "$vorname ausgeloggt.\n";
	last;
      } else {
	print "Finger weg $row[1]!\n";
	next;
      }
    }

    $rv = $sthfinditem->execute($barcode) or die $DBI::errstr;
    if($rv < 0) {
      print $DBI::errstr;
    }
    if (my @row = $sthfinditem->fetchrow_array()) {
      ($itemid, $itemname) = @row;
      print "$itemname\n";
    } else {
      print "Itemcode $barcode unbekannt.\n";
    }

    $rv = $sthfindausleihe->execute($itemid) or die $DBI::errstr;
    if($rv < 0) {
      print $DBI::errstr;
    }
    if (my @row = $sthfindausleihe->fetchrow_array()) {
      print "Rueckgabe $itemname\n";
      if ($row[1] != $memberid) {
	$rv = $sthmemberfromid->execute($row[1]) or die $DBI::errstr;
	if($rv < 0) {
	  print $DBI::errstr;
	}
	my ($ausleihervorname, $ausleihernachname) = $sthmemberfromid->fetchrow_array();
	print "Hey $vorname, $itemname war von $ausleihervorname $ausleihernachname ausgeliehen!\n";
      }
      $rv = $sthrueckgabe->execute($row[0]) or die $DBI::errstr;
      if($rv < 0) {
	print $DBI::errstr;
      }
    } else {
      print "Ausleihe $itemname\n";
      $rv = $sthausleihen->execute($itemid, $memberid) or die $DBI::errstr;
      if($rv < 0) {
	print $DBI::errstr;
      }
    }
  }
}

$dbh->disconnect();


sub read_barcode {
  my $input;

  do {
    $input = <>;
  } while ($input !~ /\S/);

  chomp $input;
  return $input;
}
