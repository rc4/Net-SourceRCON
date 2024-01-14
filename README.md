# Net::SourceRCON

Simple Perl module for interacting with any server implementing Valve's Source RCON protocol. This module fully supports multiple-packet responses using a dummy `SERVERDATA_RESPONSE_VALUE` packet; this will be toggleable in a future release (e.g. for Minecraft compatibility). 

See the [Valve Developer Wiki](https://developer.valvesoftware.com/wiki/Source_RCON_Protocol) for full protocol specifications.

## Constructor


```
my $rcon = Net::SourceRCON->new( address => 'IP or hostname', password => 'verysecret' ); # open connection
```

Additional constructor options:

* `port` - defaults to 27015.
* `autoretry` - currently unimplemented.
* `timeout` - socket timeout in seconds. Default is no timeout.
* `strictly_compliant` - Per [Valve](https://developer.valvesoftware.com/wiki/Source_RCON_Protocol#Requests_and_Responses), an RCON server will respond to a `SERVERDATA_AUTH` request with two packets, an empty `SERVERDATA_RESPONSE_VALUE`, followed by the `SERVERDATA_AUTH_RESPONSE` packet. Some games may not implement the (useless) `RESPONSE_VALUE` packet and just send the auth response instead. By default, `Net::SourceRCON` will carp at you if it doesn't get the `SERVERDATA_RESPONSE_VALUE` packet first; set this to 0 to disable this behavior if you're working with non-Valve games that exhibit this behavior.

## Authentication

Once you've instantiated the object, call `$rcon->login;` to log in using the password you supplied. The module will croak if authentication fails for any reason.

## Querying

```
my $resp = $rcon->query( 'status' );
```

`$resp` will contain the full response from the server; multiple-packet responses are automatically stitched together for you. 
