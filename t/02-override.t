BEGIN {
    $ENV{MYAPP_DB_1_USER} = 'admin';
    $ENV{MYAPP_DB_1_PASS} = 's3cret';
}

use utf8;
use strict;
use warnings;
use Test::More;
use Config::Environment;

my $conf = Config::Environment->new(domain => 'myapp', override => 0);
my $conn = $conf->param('db.1.conn' => 'dbi:mysql:dbname=foobar');
my $user = $conf->param('db.1.user' => 'user');
my $pass = $conf->param('db.1.pass' => 'xpl0!+');

is $user, 'admin',  '$user is ok - no overriding';
is $pass, 's3cret', '$pass is ok - no overriding';
is $conn, 'dbi:mysql:dbname=foobar', '$conn is ok';

$conf = Config::Environment->new(domain => 'myapp');
$user = $conf->param('db.1.user' => 'user');
$pass = $conf->param('db.1.pass' => 'xpl0!+');

is $user, 'user',   '$user is ok - overridden';
is $pass, 'xpl0!+', '$pass is ok - overridden';

done_testing;
