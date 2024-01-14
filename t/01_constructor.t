use Test::More tests => 7;
use Test::Exception;

use lib '.';
require_ok('SourceRCON'); # Test if the module can be loaded.

# Test for successful object creation
subtest 'Successful object creation' => sub {
    plan tests => 2;

    my $rcon = SourceRCON->new(address => '127.0.0.1', password => 'secret');
    isa_ok($rcon, 'SourceRCON');
    is($rcon->{port}, 27015, 'Default port should be 27015');
};

# Test for missing required parameters
foreach my $param (qw(address password)) {
    subtest "Missing required parameter: $param" => sub {
        plan tests => 1;
        throws_ok { SourceRCON->new($param eq 'address' ? (password => 'secret') : (address => '127.0.0.1')) } qr/Missing required parameter '$param'/, "Should croak without $param";
    };
}

# Test default values for optional parameters
subtest 'Default values for optional parameters' => sub {
    plan tests => 3;

    my $rcon = SourceRCON->new(address => '127.0.0.1', password => 'secret');
    is($rcon->{autoretry}, 1, 'Default autoretry should be 1');
    is($rcon->{timeout}, 0, 'Default timeout should be 0');
    is($rcon->{port}, 27015, 'Default port should be 27015');
};

# Test invalid port number
subtest 'Invalid port number' => sub {
    plan tests => 1;
    throws_ok { SourceRCON->new(address => '127.0.0.1', password => 'secret', port => 70000) } qr/Invalid port number/, 'Should croak with invalid port number';
};

# Test overriding default values
subtest 'Overriding default values' => sub {
    plan tests => 3;

    my $rcon = SourceRCON->new(address => '127.0.0.1', password => 'secret', port => 25565, autoretry => 0, timeout => 10);
    is($rcon->{port}, 25565, 'Port should be overridden to 25565');
    is($rcon->{autoretry}, 0, 'Autoretry should be overridden to 0');
    is($rcon->{timeout}, 10, 'Timeout should be overridden to 10');
};