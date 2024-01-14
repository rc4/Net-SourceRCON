package Net::SourceRCON;

use 5.010;
use strict;
use warnings;
use Carp;
use IO::Socket::INET;

use constant {
    SERVERDATA_RESPONSE_VALUE => 0,
    SERVERDATA_EXEC_COMMAND => 2,
    SERVERDATA_AUTH_RESPONSE => 2,
    SERVERDATA_AUTH => 3
};

sub new {
    my( $class, %args ) = @_;
    my %params = (
        address => undef,    # required
        port => 27015,
        password => undef,    # required
        autoretry => 1,
        timeout => 0,
        # i believe that some third-party games don't strictly conform to the authentication flow in
        # valve's spec (send an empty SERVERDATA_RESPONSE_VALUE before sending the SERVERDATA_AUTH_RESPONSE
        # packet) - turn this off if yours does not.
        # see SERVERDATA_AUTH under https://developer.valvesoftware.com/wiki/Source_RCON_Protocol#Requests_and_Responses
        strictly_compliant => 1
    );

    for my $required ( qw(address password) ) {
        croak "Missing required parameter '$required'" unless exists $args{$required};
        $params{$required} = $args{$required};
    }

    for my $optional ( qw(port autoretry timeout) ) {
        $params{$optional} = $args{$optional} if exists $args{$optional};
    }
    croak "Invalid port number: $params{port}" unless $params{port} >= 1 and $params{port} <= 65535;

    # initialize internal stuff
    $params{_socket} = IO::Socket::INET->new(
        PeerAddr => $params{address},
        PeerPort => $params{port},
        Proto => 'tcp'
    ) or croak "Failed to connect to server: $!";
    $params{_socket}->timeout( $params{timeout} ) if $params{timeout};
    $params{_id} = 0;

    my $self = bless \%params, $class;
    return $self;
}

# see https://developer.valvesoftware.com/wiki/Source_RCON_Protocol#Requests_and_Responses
sub login {
    my $self = shift;

    $self->_send( SERVERDATA_AUTH, $self->{password} );

    # some servers may not do this, but it's in the spec
    if( $self->{strictly_compliant} ) {
        my $resp = $self->_recv;
        carp "Expected SERVERDATA_RESPONSE_VALUE (type 0), got $resp->{type} (consider disabling 'strictly_compliant')"
          unless $resp->{type} == SERVERDATA_RESPONSE_VALUE;
    }

    my $auth_resp = $self->_recv;
    croak "Expected SERVERDATA_AUTH_RESPONSE, got $auth_resp->{type}"
      unless $auth_resp->{type} == SERVERDATA_AUTH_RESPONSE;
    croak "Authentication failed - invalid RCON password" if $auth_resp->{id} == -1;
}

sub query {
    my( $self, $command ) = @_;

    my $cmd_id = $self->_send( SERVERDATA_EXEC_COMMAND, $command );
    # hack to handle multi-packet responses
    # see https://developer.valvesoftware.com/wiki/Source_RCON_Protocol#Multiple-packet_Responses
    my $marker_id = $self->_send( SERVERDATA_RESPONSE_VALUE, "\0" );

    # stitch together the packets
    my $response = '';
    for( ;; ) {
        my $resp = $self->_recv;
        croak "Unexpected packet type: $resp->{type}" unless $resp->{type} == SERVERDATA_RESPONSE_VALUE;

        # this marks the end of multi-packet insanity
        last if $resp->{id} == $marker_id;

        croak "Response ID does not match request ID" unless $resp->{id} == $cmd_id;
        $response .= $resp->{body};
    }
    $self->_recv;    # ignore empty SERVERDATA_RESPONSE_VALUE from server

    return $response;
}

# internal function that serializes your commands into the RCON packet format
sub _send {
    my( $self, $type, $body ) = @_;

    my $id = ++$self->{_id};
    my $packet = pack( 'VVVa*xx', length( $body ) + 10, $id, $type, $body );

    $self->{_socket}->send( $packet ) or croak "Failed to send packet: $!";
    return $id;
}

# same as above except opposite
sub _recv {
    my $self = shift;

    # receive 12 byte header - https://developer.valvesoftware.com/wiki/Source_RCON_Protocol#Basic_Packet_Structure
    my $header = '';
    $self->{_socket}->recv( $header, 12, MSG_WAITALL );
    my( $size, $id, $type ) = unpack( 'lll', $header );

    my $body = '';
    $self->{_socket}->recv( $body, $size - 8, MSG_WAITALL );

    return { size => $size, id => $id, type => $type, body => $body };
}

sub DESTROY {
    my $self = shift;
    $self->{_socket}->close;
}

1;
